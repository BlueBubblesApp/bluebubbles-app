import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/app/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:scroll_to_index/scroll_to_index.dart';

class MessagesView extends StatefulWidget {
  final MessagesService? customService;
  final Chat chat;

  MessagesView({
    Key? key,
    this.customService,
    required this.chat,
  }) : super(key: key);

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends State<MessagesView> with WidgetsBindingObserver {
  bool fetching = false;
  late bool noMoreMessages = widget.customService != null;
  List<Message> _messages = <Message>[];

  RxList<Widget> smartReplies = <Widget>[].obs;
  RxList<Widget> internalSmartReplies = <Widget>[].obs;

  late final messageService = widget.customService ?? ms(widget.chat.guid)
    ..init(widget.chat, handleNewMessage, handleUpdatedMessage);
  late final ChatController currentChat = ChatManager().activeChat!;
  final Duration animationDuration = Duration(milliseconds: 400);
  final smartReply = GoogleMlKit.nlp.smartReply();
  final focusNode = FocusScopeNode();
  final listKey = GlobalKey<SliverAnimatedListState>();
  final RxBool dragging = false.obs;

  AutoScrollController get scrollController => currentChat.scrollController;
  bool get showSmartReplies => ss.settings.smartReply.value && !kIsWeb && !kIsDesktop;
  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();

    eventDispatcher.stream.listen((e) async {
      if (!mounted) return;

      if (e.item1 == "refresh-messagebloc" && e.item2 != null) {
        // Handle event's that require a matching guid
        String? chatGuid = e.item2;
        if (widget.chat.guid == chatGuid) {
          // Clear state items
          noMoreMessages = false;
          _messages = [];
          // Reload the state after refreshing
          messageService.reload();
          messageService.init(chat, handleNewMessage, handleUpdatedMessage);
          await rebuild(this);
        }
      } else if (e.item1 == "add-custom-smartreply") {
        if (e.item2["path"] != null) {
          internalSmartReplies.add(
            _buildReply("Attach recent photo", onTap: () async {
              eventDispatcher.emit('add-attachment', e.item2);
              internalSmartReplies.clear();
            })
          );
        }
      } else if (e.item1 == "scroll-to-message") {
        final message = e.item2;
        final index = _messages.indexWhere((element) => element.guid == message.guid);
        await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
        scrollController.highlight(index, highlightDuration: Duration(milliseconds: 500));
      }
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      eventDispatcher.emit("update-highlight", widget.chat.guid);
      // See if we need to load anything from the message bloc
      await Future.delayed(Duration(milliseconds: 100));
      if (messageService.tag.contains("search")) {
        await messageService.loadSearchChunk(
          messageService.struct.messages.first,
          messageService.tag.contains("local") ? SearchMethod.local : SearchMethod.network
        );
      } else if (messageService.struct.isEmpty) {
        await messageService.loadChunk(0);
      }
      _messages = messageService.struct.messages;
      _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
      _messages.forEachIndexed((i, _) {
        listKey.currentState!.insertItem(i, duration: Duration(milliseconds: 0));
      });
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && !kIsDesktop) smartReply.close();
    messageService.close();
    super.dispose();
  }

  void updateReplies({bool updateConversation = true}) async {
    if (isNullOrEmpty(_messages)! || kIsWeb || kIsDesktop) return;

    if (updateConversation) {
      _messages.where((e) => !isNullOrEmpty(e.fullText)! && e.dateCreated != null).take(min(_messages.length, 5)).forEach((message) {
        _addMessageToSmartReply(message);
      });
    }
    Logger.info("Getting smart replies...");
    SmartReplySuggestionResult results = await smartReply.suggestReplies();

    if (results.status == SmartReplySuggestionResultStatus.success) {
      Logger.info("Smart Replies found: ${results.suggestions.length}");
      smartReplies.value = results.suggestions.map((e) => _buildReply(e)).toList();
      Logger.debug(smartReplies.toString());
    } else {
      smartReplies.clear();
    }
  }

  void _addMessageToSmartReply(Message message) {
    if (message.isFromMe ?? false) {
      smartReply.addMessageToConversationFromLocalUser(
          message.fullText,
          message.dateCreated!.millisecondsSinceEpoch
      );
    } else {
      smartReply.addMessageToConversationFromRemoteUser(
          message.fullText,
          message.dateCreated!.millisecondsSinceEpoch,
          message.handle?.address ?? "participant"
      );
    }
  }

  Future<void> loadNextChunk() async {
    if (noMoreMessages) return;

    // If we already are loading a chunk, don't load again
    if (fetching) {
      return;
    }
    fetching = true;

    // Start loading the next chunk of messages
    noMoreMessages = !(await messageService.loadChunk(_messages.length).catchError((e) {
      Logger.error("Failed to fetch message chunk! $e");
    }));

    final oldLength = _messages.length;
    _messages = messageService.struct.messages;
    _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    fetching = false;
    _messages.sublist(oldLength - 1).forEachIndexed((i, _) {
      listKey.currentState!.insertItem(i, duration: Duration(milliseconds: 0));
    });
  }

  void handleNewMessage(Message message) {
    _messages.add(message);
    _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    final insertIndex = _messages.indexOf(message);
    listKey.currentState!.insertItem(
      insertIndex,
      duration: Duration(milliseconds: 300),
    );

    if (insertIndex == 0 && showSmartReplies) {
      _addMessageToSmartReply(message);
      updateReplies(updateConversation: false);
    }
  }

  void handleUpdatedMessage(Message message) {
    final index = _messages.indexWhere((e) => e.guid == message.guid);
    _messages[index] = message;
  }

  Widget _buildReply(String text, {Function()? onTap}) => Container(
    margin: EdgeInsets.all(5),
    decoration: BoxDecoration(
      border: Border.all(
        width: 2,
        style: BorderStyle.solid,
        color: context.theme.colorScheme.properSurface,
      ),
      borderRadius: BorderRadius.circular(19),
    ),
    child: InkWell(
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
      ),
      onTap: onTap ??
              () {
            outq.queue(OutgoingItem(
                type: QueueType.newMessage,
                chat: currentChat.chat,
                message: Message(text: text)
            ));
          },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1.5, left: 13.0, right: 13.0),
          child: RichText(
            text: TextSpan(
              children: MessageHelper.buildEmojiText(
                text,
                context.theme.extension<BubbleText>()!.bubbleText,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Widget child = FocusScope(
      node: focusNode,
      onFocusChange:
          kIsDesktop || kIsWeb ? (focus) => focus ? eventDispatcher.emit('focus-keyboard', null) : null : null,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            // I have no idea why this works
            onPanDown: kIsDesktop || kIsWeb ? (details) => focusNode.requestFocus() : null,
            onHorizontalDragStart: (details) {},
            onHorizontalDragUpdate: (details) {
              if (ss.settings.skin.value != Skins.Samsung && !kIsWeb && !kIsDesktop) {
                ChatManager().activeChat!.timeStampOffset += details.delta.dx * 0.3;
              }
            },
            onHorizontalDragEnd: (details) {
              if (ss.settings.skin.value != Skins.Samsung) {
                ChatManager().activeChat!.timeStampOffset = 0;
              }
            },
            onHorizontalDragCancel: () {
              if (ss.settings.skin.value != Skins.Samsung) {
                ChatManager().activeChat!.timeStampOffset = 0;
              }
            },
            child: AnimatedOpacity(
              opacity: _messages.isEmpty && widget.customService == null ? 0 : 1,
              duration: Duration(milliseconds: 150),
              curve: Curves.easeIn,
              child: ScrollbarWrapper(
                reverse: true,
                controller: scrollController,
                showScrollbar: true,
                child: Obx(
                  () => CustomScrollView(
                    controller: scrollController,
                    reverse: true,
                    physics: (ss.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                        ? NeverScrollableScrollPhysics()
                        : ThemeSwitcher.getScrollPhysics(),
                    slivers: <Widget>[
                      if (showSmartReplies)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: ss.settings.skin.value != Skins.iOS ? 8.0 : 0.0, right: 5),
                            child: Obx(() => AnimatedSize(
                              duration: Duration(milliseconds: 400),
                              child: smartReplies.isNotEmpty || internalSmartReplies.isNotEmpty ? Container(
                                height: context.theme.extension<BubbleText>()!.bubbleText.fontSize! + 35,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: smartReplies..addAll(internalSmartReplies),
                                )
                              ) : const SizedBox.shrink())
                            ),
                          ),
                        ),
                      if (ss.settings.enablePrivateAPI.value || widget.chat.guid == "theme-selector")
                        SliverToBoxAdapter(
                          child: Row(
                            children: <Widget>[
                              if (widget.chat.guid == "theme-selector" ||
                                  (currentChat.showTypingIndicator &&
                                      (ss.settings.skin.value == Skins.Samsung ||
                                          ss.settings.alwaysShowAvatars.value)))
                                Padding(
                                  padding: EdgeInsets.only(left: 10.0),
                                  child: ContactAvatarWidget(
                                    key: Key("${widget.chat.participants[0].address}-messages-view"),
                                    handle: widget.chat.participants[0],
                                    size: 30,
                                    fontSize: 14,
                                    borderThickness: 0.1,
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: TypingIndicator(
                                  visible:
                                      widget.chat.guid == "theme-selector" ? true : currentChat.showTypingIndicator,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_messages.isEmpty && widget.customService != null)
                        SliverToBoxAdapter(
                          child: NewMessageLoader(
                            text: "Loading surrounding message context..."
                          ),
                        ),
                      SliverAnimatedList(
                              initialItemCount: _messages.length + 1,
                              key: listKey,
                              itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                                // Load more messages if we are at the top and we aren't alrady loading
                                // and we have more messages to load
                                if (index == _messages.length) {
                                  if (!noMoreMessages) {
                                    if (!fetching) {
                                      loadNextChunk();
                                    }
                                    return NewMessageLoader();
                                  }

                                  return Container();
                                } else if (index > _messages.length) {
                                  return Container();
                                }

                                Message? olderMessage;
                                Message? newerMessage;
                                if (index + 1 >= 0 && index + 1 < _messages.length) {
                                  olderMessage = _messages[index + 1];
                                }
                                if (index - 1 >= 0 && index - 1 < _messages.length) {
                                  newerMessage = _messages[index - 1];
                                }

                                bool fullAnimation = index == 0 &&
                                    (!_messages[index].isFromMe! || _messages[index].originalROWID == null);

                                Widget messageWidget = Padding(
                                    padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        scrollController.scrollToIndex(2, preferPosition: AutoScrollPosition.begin);
                                      },
                                      child: AutoScrollTag(
                                        key: ValueKey("${_messages[index].guid!}-scrolling"),
                                        index: index,
                                        controller: scrollController,
                                        highlightColor: context.theme.colorScheme.surface.withOpacity(0.7),
                                        child: MessageWidget(
                                          key: Key(_messages[index].guid!),
                                          message: _messages[index],
                                          olderMessage: olderMessage,
                                          newerMessage: newerMessage,
                                          showHandle: chat.participants.length > 1,
                                          isFirstSentMessage: messageService.mostRecentSent?.guid == _messages[index].guid,
                                          showHero: fullAnimation,
                                          showReplies: true,
                                          bloc: messageService,
                                          autoplayEffect: index == 0 && _messages[index].originalROWID != null,
                                        )),
                                    )
                                    );

                                if (fullAnimation) {
                                  return SizeTransition(
                                    axis: Axis.vertical,
                                    sizeFactor: animation
                                        .drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut))),
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
                                      child: Opacity(
                                        opacity: animation.isCompleted || !_messages[index].isFromMe! ? 1 : 0,
                                        child: messageWidget,
                                      ),
                                    ),
                                  );
                                }

                                return messageWidget;
                              }),
                      SliverPadding(
                        padding: EdgeInsets.all(70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Obx(() => Container(
                    color: dragging.value ? context.theme.colorScheme.bubble(context, widget.chat.isIMessage).withAlpha(50) : Colors.transparent,
                  )),
            ),
          ),
        ],
      ),
    );
    if (kIsWeb) return child;
    return DropTarget(
      onDragEntered: (details) {
        dragging.value = true;
      },
      onDragExited: (details) {
        dragging.value = false;
      },
      onDragDone: (details) async {
        List<Map> files = [];
        for (XFile file in details.files) {
          files.add({
            "path": file.path,
            "size": await file.length(),
            "name": file.name,
            "bytes": await file.readAsBytes(),
          });
        }
        for (Map file in files) {
          eventDispatcher.emit('add-attachment', file);
        }
        dragging.value = false;
      },
      child: child,
    );
  }
}
