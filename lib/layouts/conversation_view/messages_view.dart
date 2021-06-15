import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/send_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_reply/flutter_smart_reply.dart';

class MessagesView extends StatefulWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  final Chat chat;
  final Function initComplete;

  MessagesView({
    Key key,
    this.messageBloc,
    this.showHandle,
    this.chat,
    this.initComplete,
  }) : super(key: key);

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends State<MessagesView> with TickerProviderStateMixin {
  Completer<LoadMessageResult> loader;
  bool noMoreMessages = false;
  bool noMoreLocalMessages = false;
  List<Message> _messages = <Message>[];

  GlobalKey<SliverAnimatedListState> _listKey;
  final Duration animationDuration = Duration(milliseconds: 400);
  bool initializedList = false;
  List<int> loadedPages = [];
  CurrentChat currentChat;
  bool keyboardOpen = false;

  List<TextMessage> currentMessages = [];
  List<String> replies = [];

  StreamController<List<String>> smartReplyController;

  bool get showScrollDown => currentChat?.showScrollDown;

  ScrollController get scrollController {
    if (currentChat == null) return null;
    if (currentChat.scrollController == null) {
      currentChat.scrollController = ScrollController();
    }

    return currentChat.scrollController;
  }

  bool get showSmartReplies =>
      SettingsManager().settings.smartReply &&
      (!SettingsManager().settings.redactedMode || !SettingsManager().settings.hideMessageContent);

  @override
  void initState() {
    super.initState();

    currentChat = CurrentChat.of(context);
    widget.messageBloc?.stream?.listen(handleNewMessage);

    // See if we need to load anything from the message bloc
    if (_messages.isEmpty && widget.messageBloc.messages.isEmpty) {
      widget.messageBloc.getMessages();
    } else if (_messages.isEmpty && widget.messageBloc.messages.isNotEmpty) {
      widget.messageBloc.emitLoaded();
    }

    smartReplyController = StreamController<List<String>>.broadcast();

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!this.mounted) return;
      if (!event.containsKey("type")) return;

      if (event["type"] == "refresh-messagebloc" && event["data"].containsKey("chatGuid")) {
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
      }
    });

    if (widget.initComplete != null) widget.initComplete();
  }

  void resetReplies() {
    if (replies.length == 0) return;
    replies = [];
    return smartReplyController.sink.add(replies);
  }

  void updateReplies() async {
    // If there are no messages or the latest message is from me, reset the replies
    if (isNullOrEmpty(_messages)) return resetReplies();
    if (_messages.first.isFromMe) return resetReplies();

    Iterable<Message> filtered = _messages
        .where((item) => !isNullOrEmpty(item.fullText, trimString: true) && item.associatedMessageGuid == null);

    if (isNullOrEmpty(filtered)) return resetReplies();

    // Calculate the max amount of items
    int max = SettingsManager().settings.smartReplySampleSize;
    if (max > filtered.length) {
      max = filtered.length;
    }

    // Get the first 'x' messages
    List<Message> msgs = filtered.toList().sublist(0, max);
    List<TextMessage> texts = [];
    for (var msg in msgs) {
      // Skip empty messages
      if (isEmptyString(msg.fullText, stripWhitespace: true)) continue;

      // Add to list based on who sent the message
      if (msg.isFromMe) {
        texts.add(TextMessage.createForLocalUser(msg.fullText, msg.dateCreated.millisecondsSinceEpoch));
      } else {
        texts.add(TextMessage.createForRemoteUser(msg.fullText, msg.dateCreated.millisecondsSinceEpoch));
      }
    }

    debugPrint("Getting smart replies for ${texts.length} texts");
    replies = await FlutterSmartReply.getSmartReplies(texts.reversed.toList());
    if (replies == null) return;

    // De-duplicate the list
    replies = replies.toSet().toList();
    debugPrint("Smart Replies found: $replies");

    // If there is nothing in the list, get out
    if (isNullOrEmpty(replies)) {
      resetReplies();
      return;
    }

    // If everything passes, add replies to the stream
    if (!smartReplyController.isClosed) smartReplyController.sink.add(replies);
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
      if (val != LoadMessageResult.FAILED_TO_RETREIVE) {
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
      event.messages = event.messages.where((element) => element.dateDeleted == null).toList();
    }

    if (event.type == MessageBlocEventType.insert) {
      if (this.mounted && LifeCycleManager().isAlive && context != null) {
        NotificationManager().switchChat(CurrentChat.of(context)?.chat);
      }
      currentChat.getAttachmentsForMessage(event.message);
      if (event.outGoing) {
        currentChat.sentMessages.add(event.message);
        Future.delayed(SendWidget.SEND_DURATION * 2, () {
          currentChat.sentMessages.removeWhere((element) => element.guid == event.message.guid);
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
              ? event.outGoing
                  ? Duration(milliseconds: 500)
                  : animationDuration
              : Duration(milliseconds: 0),
        );
      }

      if (event.message.hasAttachments) {
        await currentChat.updateChatAttachments();
        if (this.mounted) setState(() {});
      }

      if (isNewMessage && this.showSmartReplies) {
        updateReplies();
      }
    } else if (event.type == MessageBlocEventType.remove) {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.remove && _listKey.currentState != null) {
          _messages.removeAt(i);
          _listKey.currentState.removeItem(i, (context, animation) => Container());
        }
      }
    } else {
      int originalMessageLength = _messages.length;
      _messages = event.messages;
      _messages.forEach((message) => currentChat.getAttachmentsForMessage(message));

      // We only want to update smart replies on the intial message fetch
      if (originalMessageLength == 0) {
        if (this.showSmartReplies) {
          if (_messages.length > 0) updateReplies();
        }
      }
      if (_listKey == null) _listKey = GlobalKey<SliverAnimatedListState>();

      if (originalMessageLength < _messages.length) {
        for (int i = originalMessageLength; i < _messages.length; i++) {
          if (_listKey != null && _listKey.currentState != null)
            _listKey.currentState.insertItem(i, duration: Duration(milliseconds: 0));
        }
      } else if (originalMessageLength > _messages.length) {
        for (int i = originalMessageLength; i >= _messages.length; i--) {
          if (_listKey != null && _listKey.currentState != null) {
            try {
              _listKey.currentState
                  .removeItem(i, (context, animation) => Container(), duration: Duration(milliseconds: 0));
            } catch (ex) {
              debugPrint("Error removing item animation");
              debugPrint(ex.toString());
            }
          }
        }
      }
    }

    if (this.mounted) setState(() {});
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
        debugPrint("(Message status) Update message: [${message.text}] - [${message.guid}] - [$oldGuid]");
        _messages[i] = message;
        updatedAMessage = true;
        break;
      }
    }
    if (!updatedAMessage) {
      debugPrint(
          "(Message status) Message not updated (not found): [${message.text}] - [${message.guid}] - [$oldGuid]");
    }

    return message;
  }

  Widget _buildReply(String text) => Container(
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(
            width: 2,
            style: BorderStyle.solid,
            color: Theme.of(context).accentColor,
          ),
          borderRadius: BorderRadius.circular(19),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          onTap: () {
            ActionHandler.sendMessage(currentChat.chat, text);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 13.0),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (details) {},
      onHorizontalDragUpdate: (details) {
        if (SettingsManager().settings.skin != Skins.Samsung)
          CurrentChat.of(context).timeStampOffset += details.delta.dx * 0.3;
      },
      onHorizontalDragEnd: (details) {
        if (SettingsManager().settings.skin != Skins.Samsung) CurrentChat.of(context).timeStampOffset = 0;
      },
      onHorizontalDragCancel: () {
        if (SettingsManager().settings.skin != Skins.Samsung) CurrentChat.of(context).timeStampOffset = 0;
      },
      child: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          CustomScrollView(
            controller: scrollController ?? ScrollController(),
            reverse: true,
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              if (this.showSmartReplies)
                StreamBuilder<List<String>>(
                  stream: smartReplyController.stream,
                  builder: (context, snapshot) {
                    return SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: Duration(milliseconds: 500),
                        vsync: this,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: replies
                                .map(
                                  (e) => _buildReply(e),
                                )
                                .toList()),
                      ),
                    );
                  },
                ),
              if (SettingsManager().settings.enablePrivateAPI)
                SliverToBoxAdapter(
                    child: Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: TypingIndicator(
                    visible: currentChat.showTypingIndicator,
                  ),
                )),
              _listKey != null
                  ? SliverAnimatedList(
                      initialItemCount: _messages.length + 1,
                      key: _listKey,
                      itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                        // Load more messages if we are at the top and we aren't alrady loading
                        // and we have more messages to load
                        if (index == _messages.length) {
                          if (!noMoreMessages &&
                              (loader == null || !loader.isCompleted || !loadedPages.contains(_messages.length))) {
                            loadNextChunk();
                            return NewMessageLoader();
                          }

                          return Container();
                        } else if (index > _messages.length) {
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

                        bool fullAnimation = index == 0 && _messages[index].originalROWID == null;

                        Widget messageWidget = Padding(
                            padding: EdgeInsets.only(left: 5.0, right: 5.0),
                            child: MessageWidget(
                              key: Key(_messages[index].guid),
                              message: _messages[index],
                              olderMessage: olderMessage,
                              newerMessage: newerMessage,
                              showHandle: widget.showHandle,
                              isFirstSentMessage: widget.messageBloc.firstSentMessage == _messages[index].guid,
                              showHero: fullAnimation,
                              onUpdate: (event) => onUpdateMessage(event),
                            ));

                        if (fullAnimation) {
                          return SizeTransition(
                            axis: Axis.vertical,
                            sizeFactor:
                                animation.drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut))),
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
                                child: messageWidget,
                              ),
                            ),
                          );
                        }

                        return messageWidget;
                      })
                  : SliverToBoxAdapter(child: Container()),
              SliverPadding(
                padding: EdgeInsets.all(70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (!smartReplyController.isClosed) smartReplyController.close();
    super.dispose();
  }
}
