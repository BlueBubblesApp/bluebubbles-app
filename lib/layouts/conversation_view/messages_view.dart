import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/layouts/widgets/send_widget.dart';

class MessagesView extends StatefulWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  final Chat chat;

  MessagesView({
    Key key,
    this.messageBloc,
    this.showHandle,
    this.chat,
  }) : super(key: key);

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends State<MessagesView>
    with TickerProviderStateMixin {
  Completer<LoadMessageResult> loader;
  bool noMoreMessages = false;
  bool noMoreLocalMessages = false;
  List<Message> _messages = <Message>[];

  GlobalKey<SliverAnimatedListState> _listKey;
  final Duration animationDuration = Duration(milliseconds: 400);
  bool initializedList = false;
  ScrollController scrollController = new ScrollController();
  List<int> loadedPages = [];
  CurrentChat currentChat;

  bool currentShowScrollDown = false;
  StreamController<bool> showScrollDownStream =
      StreamController<bool>.broadcast();
  bool get showScrollDown => currentShowScrollDown;
  set showScrollDown(bool value) {
    if (currentShowScrollDown == value) return;
    currentShowScrollDown = value;
    if (!showScrollDownStream.isClosed)
      showScrollDownStream.sink.add(currentShowScrollDown);
  }

  @override
  void initState() {
    super.initState();
    widget.messageBloc.stream.listen(handleNewMessage);

    scrollController.addListener(() {
      if (scrollController == null || !scrollController.hasClients) return;
      if (showScrollDown && scrollController.offset >= 500) return;
      if (!showScrollDown && scrollController.offset < 500) return;

      if (scrollController.offset >= 500) {
        showScrollDown = true;
      } else {
        showScrollDown = false;
      }
    });

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!["refresh-messagebloc"].contains(event["type"])) return;
      if (!event["data"].containsKey("chatGuid")) return;

      // Handle event's that require a matching guid
      String chatGuid = event["data"]["chatGuid"];
      if (widget.chat.guid == chatGuid) {
        if (event["type"] == "refresh-messagebloc") {
          // Clear state items
          noMoreLocalMessages = false;
          noMoreMessages = false;
          _messages = [];
          loadedPages = [];

          // Reload the state after refreshing
          widget.messageBloc.refresh().then((_) {
            if (this.mounted) {
              setState(() {});
            }
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    currentChat = CurrentChat.of(context);

    if (_messages.isEmpty) {
      widget.messageBloc.getMessages();
    }
  }

  @override
  void dispose() {
    showScrollDownStream.close();
    super.dispose();
  }

  Future<void> loadNextChunk() {
    if (noMoreMessages || loadedPages.contains(_messages.length)) return null;
    int messageCount = _messages.length;

    // If we already are loading a chunk, don't load again
    if (loader != null && !loader.isCompleted) {
      return loader.future;
    }

    // Create a new completer
    loader = new Completer();
    loadedPages.add(messageCount);

    // Start loading the next chunk of messages
    widget.messageBloc
        .loadMessageChunk(_messages.length, checkLocal: !noMoreLocalMessages)
        .then((LoadMessageResult val) {
      if (val != LoadMessageResult.FAILED_TO_RETREIVE) {
        if (val == LoadMessageResult.RETREIVED_NO_MESSAGES) {
          noMoreMessages = true;
          debugPrint("(CHUNK) No more messages to load");
        } else if (val == LoadMessageResult.RETREIVED_LAST_PAGE) {
          // Mark this chat saying we have no more messages to load
          noMoreLocalMessages = true;
        }
      }

      // Complete the future
      loader.complete(val);

      // Only update the state if there are messages that were added
      if (val != LoadMessageResult.RETREIVED_NO_MESSAGES &&
          val != LoadMessageResult.FAILED_TO_RETREIVE) {
        if (this.mounted) setState(() {});
      }
    }).catchError((ex) {
      loader.complete(LoadMessageResult.FAILED_TO_RETREIVE);
    });

    return loader.future;
  }

  void handleNewMessage(MessageBlocEvent event) async {
    // Get outta here if we don't have a chat "open"
    if (currentChat == null) return;

    // Skip deleted messages
    if (event.message != null && event.message.dateDeleted != null) return;
    if (!isNullOrEmpty(event.messages)) {
      event.messages = event.messages
          .where((element) => element.dateDeleted == null)
          .toList();
    }

    if (event.type == MessageBlocEventType.insert) {
      if (this.mounted && LifeCycleManager().isAlive && context != null) {
        NotificationManager().switchChat(CurrentChat.of(context)?.chat);
      }
      currentChat.getAttachmentsForMessage(event.message);
      if (event.outGoing) {
        currentChat.sentMessages.add(event.message);
        Future.delayed(SendWidget.SEND_DURATION * 2, () {
          currentChat.sentMessages
              .removeWhere((element) => element.guid == event.message.guid);
        });

        if (context != null)
          Navigator.of(context).push(
            SendPageBuilder(
              builder: (context) {
                return SendWidget(
                  text: event.message.text,
                  tag: "first",
                  currentChat: currentChat,
                );
              },
            ),
          );
      }

      bool isNewMessage = true;
      for (Message message in _messages) {
        if (message.guid == event.message.guid) {
          isNewMessage = false;
          break;
        }
      }

      _messages = event.messages;
      if (_listKey != null && _listKey.currentState != null) {
        _listKey.currentState.insertItem(
          event.index != null ? event.index : 0,
          duration: isNewMessage
              ? event.outGoing ? Duration(milliseconds: 500) : animationDuration
              : Duration(milliseconds: 0),
        );
      }
      if (event.message.hasAttachments) {
        await currentChat.updateChatAttachments();
        if (this.mounted) setState(() {});
      }
    } else if (event.type == MessageBlocEventType.remove) {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.remove &&
            _listKey.currentState != null) {
          _messages.removeAt(i);
          _listKey.currentState
              .removeItem(i, (context, animation) => Container());
        }
      }
    } else {
      int originalMessageLength = _messages.length;
      _messages = event.messages;
      _messages
          .forEach((message) => currentChat.getAttachmentsForMessage(message));
      if (_listKey == null) _listKey = GlobalKey<SliverAnimatedListState>();

      if (originalMessageLength < _messages.length) {
        for (int i = originalMessageLength; i < _messages.length; i++) {
          if (_listKey != null && _listKey.currentState != null)
            _listKey.currentState
                .insertItem(i, duration: Duration(milliseconds: 0));
        }
      } else if (originalMessageLength > _messages.length) {
        for (int i = originalMessageLength; i >= _messages.length; i--) {
          if (_listKey != null && _listKey.currentState != null) {
            try {
              _listKey.currentState.removeItem(
                  i, (context, animation) => Container(),
                  duration: Duration(milliseconds: 0));
            } catch (ex) {
              debugPrint("Error removing item animation");
              debugPrint(ex.toString());
            }
          }
        }
      }
    }
  }

  /// All message update events are handled within the message widgets, to prevent top level setstates
  Message onUpdateMessage(NewMessageEvent event) {
    if (event.type != NewMessageType.UPDATE) return null;
    currentChat.updateExistingAttachments(event);

    String oldGuid = event.event["oldGuid"];
    Message message = event.event["message"];

    bool updatedAMessage = false;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].guid == oldGuid) {
        debugPrint(
            "(Message status) Update message: [${message.text}] - [${message.guid}] - [$oldGuid]");
        _messages[i] = message;
        updatedAMessage = true;
        break;
      }
    }
    if (!updatedAMessage) {
      debugPrint(
          "(Message status) FAILED TO UPDATE A MESSAGE: [${message.text}] - [${message.guid}] - [$oldGuid]");
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (details) {},
      onHorizontalDragUpdate: (details) {
        CurrentChat.of(context).timeStampOffset += details.delta.dx * 0.3;
      },
      onHorizontalDragEnd: (details) {
        CurrentChat.of(context).timeStampOffset = 0;
      },
      onHorizontalDragCancel: () {
        CurrentChat.of(context).timeStampOffset = 0;
      },
      child: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          CustomScrollView(
            controller: scrollController,
            reverse: true,
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: TypingIndicator(
                  visible: currentChat.showTypingIndicator,
                ),
              ),
              _listKey != null
                  ? SliverAnimatedList(
                      initialItemCount: _messages.length + 1,
                      key: _listKey,
                      itemBuilder: (BuildContext context, int index,
                          Animation<double> animation) {
                        // Load more messages if we are at the top and we aren't alrady loading
                        // and we have more messages to load
                        if (index >= _messages.length) {
                          if (!noMoreMessages &&
                              (loader == null ||
                                  !loader.isCompleted ||
                                  !loadedPages.contains(_messages.length))) {
                            loadNextChunk();
                            return NewMessageLoader();
                          }

                          return Container();
                        }

                        Message olderMessage;
                        Message newerMessage;
                        if (index + 1 >= 0 && index + 1 < _messages.length) {
                          olderMessage = _messages[index + 1];
                        }
                        if (index - 1 >= 0 && index - 1 < _messages.length) {
                          newerMessage = _messages[index - 1];
                        }

                        return SizeTransition(
                          axis: Axis.vertical,
                          sizeFactor: animation.drive(
                              Tween(begin: 0.0, end: 1.0)
                                  .chain(CurveTween(curve: Curves.easeInOut))),
                          child: SlideTransition(
                            position: animation.drive(
                              Tween(
                                begin: Offset(0.0, 1),
                                end: Offset(0.0, 0.0),
                              ).chain(
                                CurveTween(
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: Padding(
                                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                child: MessageWidget(
                                  key: Key(_messages[index].guid),
                                  message: _messages[index],
                                  olderMessage: olderMessage,
                                  newerMessage: newerMessage,
                                  showHandle: widget.showHandle,
                                  isFirstSentMessage:
                                      widget.messageBloc.firstSentMessage ==
                                          _messages[index].guid,
                                  showHero: index == 0 &&
                                      _messages[index].originalROWID == null,
                                  onUpdate: (event) => onUpdateMessage(event),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : SliverToBoxAdapter(child: Container()),
              SliverPadding(
                padding: EdgeInsets.all(70),
              ),
            ],
          ),
          StreamBuilder<bool>(
            stream: showScrollDownStream.stream,
            builder: (context, snapshot) {
              return AnimatedOpacity(
                opacity: showScrollDown ? 1 : 0,
                duration: new Duration(milliseconds: 300),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: 35,
                      width: 150,
                      decoration: BoxDecoration(
                          color: Theme.of(context).accentColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10.0)),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            scrollController.animateTo(
                              0.0,
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 300),
                            );
                          },
                          child: Text(
                            "\u{2193} Scroll to bottom \u{2193}",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
