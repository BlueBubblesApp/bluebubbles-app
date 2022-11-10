import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/app/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:scroll_to_index/scroll_to_index.dart';

class MessagesView extends StatefulWidget {
  final MessagesService? customService;
  final ConversationViewController controller;

  MessagesView({
    Key? key,
    this.customService,
    required this.controller,
  }) : super(key: key);

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends OptimizedState<MessagesView> {
  bool initialized = false;
  bool fetching = false;
  late bool noMoreMessages = widget.customService != null;
  List<Message> _messages = <Message>[];

  RxList<Widget> smartReplies = <Widget>[].obs;
  RxList<Widget> internalSmartReplies = <Widget>[].obs;

  late final messageService = widget.customService ?? ms(chat.guid)
    ..init(chat, handleNewMessage, handleUpdatedMessage, handleDeletedMessage);
  final smartReply = GoogleMlKit.nlp.smartReply();
  final listKey = GlobalKey<SliverAnimatedListState>();
  final RxBool dragging = false.obs;

  ConversationViewController get controller => widget.controller;
  AutoScrollController get scrollController => controller.scrollController;
  bool get showSmartReplies => ss.settings.smartReply.value && !kIsWeb && !kIsDesktop;
  Chat get chat => controller.chat;

  @override
  void initState() {
    super.initState();

    eventDispatcher.stream.listen((e) async {
      if (e.item1 == "refresh-messagebloc" && e.item2 == chat.guid) {
        // Clear state items
        noMoreMessages = false;
        _messages = [];
        // Reload the state after refreshing
        messageService.reload();
        messageService.init(chat, handleNewMessage, handleUpdatedMessage, handleDeletedMessage);
        setState(() {});
      } else if (e.item1 == "add-custom-smartreply") {
        if (e.item2["path"] != null) {
          internalSmartReplies.add(
            _buildReply("Attach recent photo", onTap: () async {
              controller.pickedAttachments.add(e.item2);
              internalSmartReplies.clear();
            })
          );
        }
      }
    });

    updateObx(() async {
      final searchMessage = messageService.struct.messages.firstOrNull;
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
      setState(() {});
      _messages.forEachIndexed((i, _) {
        listKey.currentState!.insertItem(i, duration: const Duration(milliseconds: 0));
      });
      // scroll to message if needed
      if (searchMessage != null) {
        final index = _messages.indexWhere((element) => element.guid == searchMessage.guid);
        await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
        scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 500));
      }
      initialized = true;
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && !kIsDesktop) smartReply.close();
    messageService.close();
    for (Message m in _messages) {
      getActiveMwc(m.guid!)?.close();
    }
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
    if (noMoreMessages || fetching) return;
    fetching = true;

    // Start loading the next chunk of messages
    noMoreMessages = !(await messageService.loadChunk(_messages.length).catchError((e) {
      Logger.error("Failed to fetch message chunk! $e");
    }));

    final oldLength = _messages.length;
    _messages = messageService.struct.messages;
    _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    fetching = false;
    _messages.sublist(max(oldLength - 1, 0)).forEachIndexed((i, _) {
      listKey.currentState!.insertItem(i, duration: const Duration(milliseconds: 0));
    });
  }

  void handleNewMessage(Message message) {
    _messages.add(message);
    _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    final insertIndex = _messages.indexOf(message);
    listKey.currentState!.insertItem(
      insertIndex,
      duration: const Duration(milliseconds: 300),
    );

    if (insertIndex == 0 && showSmartReplies) {
      _addMessageToSmartReply(message);
      updateReplies(updateConversation: false);
    }
  }

  void handleUpdatedMessage(Message message, {String? oldGuid}) {
    final index = _messages.indexWhere((e) => e.guid == (oldGuid ?? message.guid));
    _messages[index] = message;
  }

  void handleDeletedMessage(Message message) {
    final index = _messages.indexWhere((e) => e.guid == message.guid);
    _messages.removeAt(index);
    listKey.currentState!.removeItem(index, (context, animation) => const SizedBox.shrink());
  }

  Widget _buildReply(String text, {Function()? onTap}) => Container(
    margin: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      border: Border.all(
        width: 2,
        style: BorderStyle.solid,
        color: context.theme.colorScheme.properSurface,
      ),
      borderRadius: BorderRadius.circular(19),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap ?? () {
        outq.queue(OutgoingItem(
            type: QueueType.newMessage,
            chat: controller.chat,
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
    return DropTarget(
      onDragEntered: (details) {
        dragging.value = true;
      },
      onDragExited: (details) {
        dragging.value = false;
      },
      onDragDone: (details) async {
        List<PlatformFile> files = await Future.wait(details.files.map((e) async => PlatformFile(
          path: e.path,
          name: e.name,
          size: await e.length(),
          bytes: await e.readAsBytes(),
        )));
        controller.pickedAttachments.addAll(files);
        dragging.value = false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onHorizontalDragUpdate: (details) {
          if (ss.settings.skin.value != Skins.Samsung && !kIsWeb && !kIsDesktop) {
            controller.timestampOffset.value += details.delta.dx * 0.3;
          }
        },
        onHorizontalDragEnd: (details) {
          if (ss.settings.skin.value != Skins.Samsung) {
            controller.timestampOffset.value = 0;
          }
        },
        onHorizontalDragCancel: () {
          if (ss.settings.skin.value != Skins.Samsung) {
            controller.timestampOffset.value = 0;
          }
        },
        child: AnimatedOpacity(
          opacity: _messages.isEmpty && widget.customService == null ? 0 : (dragging.value ? 0.3 : 1),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeIn,
          child: ScrollbarWrapper(
            reverse: true,
            controller: scrollController,
            showScrollbar: true,
            child: CustomScrollView(
              controller: scrollController,
              reverse: true,
              physics: ss.settings.betterScrolling.value
                  ? const NeverScrollableScrollPhysics()
                  : ThemeSwitcher.getScrollPhysics(),
              slivers: <Widget>[
                if (showSmartReplies)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: iOS ? 8.0 : 0.0, right: 5),
                      child: Obx(() => AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        child: smartReplies.isNotEmpty || internalSmartReplies.isNotEmpty ? SizedBox(
                          height: context.theme.extension<BubbleText>()!.bubbleText.fontSize! + 35,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            children: smartReplies..addAll(internalSmartReplies),
                          ),
                        ) : const SizedBox.shrink())
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (controller.showTypingIndicator.value &&
                          (samsung || ss.settings.alwaysShowAvatars.value))
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: ContactAvatarWidget(
                            key: Key("${chat.participants.first.address}-typing-indicator"),
                            handle: chat.participants.first,
                            size: 30,
                            fontSize: 14,
                            borderThickness: 0.1,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Obx(() => TypingIndicator(
                          visible: controller.showTypingIndicator.value,
                        )),
                      ),
                    ],
                  ),
                ),
                if (_messages.isEmpty && widget.customService != null)
                  const SliverToBoxAdapter(
                    child: NewMessageLoader(
                        text: "Loading surrounding message context..."
                    ),
                  ),
                SliverAnimatedList(
                  initialItemCount: _messages.length + 1,
                  key: listKey,
                  itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                    // paginate
                    if (index == _messages.length) {
                      if (!noMoreMessages && initialized) {
                        if (!fetching) {
                          loadNextChunk();
                        }
                        return const NewMessageLoader();
                      }

                      return const SizedBox.shrink();
                    }

                    Message? olderMessage;
                    Message? newerMessage;
                    if (index + 1 < _messages.length) {
                      olderMessage = _messages[index + 1];
                    }
                    if (index - 1 >= 0) {
                      newerMessage = _messages[index - 1];
                    }

                    Widget messageWidget = Padding(
                      padding: const EdgeInsets.only(left: 5.0, right: 5.0),
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
                          showHero: index == 0,
                          showReplies: true,
                          bloc: messageService,
                          controller: controller,
                          autoplayEffect: index == 0 && _messages[index].originalROWID != null,
                        ),
                      ),
                    );

                    if (index == 0) {
                      return SizeTransition(
                        axis: Axis.vertical,
                        sizeFactor: animation.drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut))),
                        child: SlideTransition(
                          position: animation.drive(
                            Tween(
                              begin: const Offset(0.0, 1),
                              end: const Offset(0.0, 0.0),
                            ).chain(
                              CurveTween(
                                curve: Curves.easeInOut,
                              ),
                            ),
                          ),
                          child: messageWidget,
                        ),
                      );
                    }

                    return messageWidget;
                  }
                ),
                const SliverPadding(
                  padding: EdgeInsets.all(70),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
