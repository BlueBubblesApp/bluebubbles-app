import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class MessagesView extends StatefulWidget {
  final MessagesService? customService;
  final ConversationViewController controller;

  MessagesView({
    super.key,
    this.customService,
    required this.controller,
  });

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends OptimizedState<MessagesView> {
  bool initialized = false;
  bool fetching = false;
  late bool noMoreMessages = widget.customService != null;
  List<Message> _messages = <Message>[];

  RxList<Widget> smartReplies = <Widget>[].obs;
  RxMap<String, Widget> internalSmartReplies = <String, Widget>{}.obs;

  late final messageService = widget.customService ?? ms(chat.guid)
    ..init(chat, handleNewMessage, handleUpdatedMessage, handleDeletedMessage, jumpToMessage);
  final smartReply = GoogleMlKit.nlp.smartReply();
  final listKey = GlobalKey<SliverAnimatedListState>();
  final RxBool dragging = false.obs;
  final RxInt numFiles = 0.obs;
  final RxBool latestMessageDeliveredState = false.obs;
  final RxBool jumpingToOldestUnread = false.obs;

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
        messageService.init(chat, handleNewMessage, handleUpdatedMessage, handleDeletedMessage, jumpToMessage);
        setState(() {});
      } else if (e.item1 == "add-custom-smartreply") {
        if (e.item2 != null && internalSmartReplies['attach-recent'] == null) {
          internalSmartReplies['attach-recent'] = _buildReply("Attach recent photo", onTap: () async {
            controller.pickedAttachments.add(e.item2);
            internalSmartReplies.clear();
          });
        }
      }
    });

    updateObx(() async {
      if (chat.isIMessage && !chat.isGroup) {
        getFocusState();
      }
      final searchMessage = (messageService.method == null) ? null : messageService.struct.messages.firstOrNull;
      if (messageService.method != null) {
        await messageService.loadSearchChunk(
            messageService.struct.messages.first, messageService.method == "local" ? SearchMethod.local : SearchMethod.network);
      } else if (messageService.struct.isEmpty) {
        await messageService.loadChunk(0, controller);
      }
      _messages = messageService.struct.messages;
      _messages.sort(Message.sort);
      setState(() {});
      _messages.forEachIndexed((i, m) {
        final c = mwc(m);
        c.cvController = controller;
        listKey.currentState!.insertItem(i, duration: const Duration(milliseconds: 0));
      });
      // scroll to message if needed
      if (searchMessage != null) {
        final index = _messages.indexWhere((element) => element.guid == searchMessage.guid);
        await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
        scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 500));
      } else if (!(_messages.firstOrNull?.isFromMe ?? true)) {
        updateReplies();
      }
      initialized = true;
      if (ss.settings.scrollToLastUnread.value && chat.lastReadMessageGuid != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (getActiveMwc(chat.lastReadMessageGuid!)?.built ?? false) return;
          internalSmartReplies['scroll-last-read'] = _buildReply("Jump to oldest unread", onTap: () async {
            if (jumpingToOldestUnread.value) return;
            jumpingToOldestUnread.value = true;
            await jumpToMessage(chat.lastReadMessageGuid!);
            internalSmartReplies.remove('scroll-last-read');
            jumpingToOldestUnread.value = false;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && !kIsDesktop) smartReply.close();
    chat.lastReadMessageGuid = _messages.first.guid;
    chat.save(updateLastReadMessageGuid: true);
    messageService.close(force: widget.customService != null);
    for (Message m in _messages) {
      getActiveMwc(m.guid!)?.close();
    }
    super.dispose();
  }

  void getFocusState() {
    if (!ss.isMinMontereySync) return;
    final recipient = chat.participants.firstOrNull;
    if (recipient != null) {
      http.handleFocusState(recipient.address).then((response) {
        final status = response.data['data']['status'];
        controller.recipientNotifsSilenced.value = status != "none";
      }).catchError((error) async {
        Logger.error('Failed to get focus state! Error: ${error.toString()}');
      });
    }
  }

  Future<void> jumpToMessage(String guid) async {
    // check if the message is already loaded
    int index = _messages.indexWhere((element) => element.guid == guid);
    if (index != -1) {
      await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
      scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 500));
      return;
    }
    // otherwise fetch until it is loaded
    final message = Message.findOne(guid: guid);
    final query = (messageBox.query(Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull()))
          ..link(Message_.chat, Chat_.id.equals(chat.id!))
          ..order(Message_.dateCreated, flags: Order.descending))
        .build();
    final ids = await query.findIdsAsync();
    final pos = ids.indexOf(message!.id!);
    await loadNextChunk(limit: pos + 10);
    index = _messages.indexWhere((element) => element.guid == guid);
    if (index != -1) {
      await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
      scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 500));
    } else {
      showSnackbar("Error", "Failed to find message!");
    }
  }

  void updateReplies({bool updateConversation = true}) async {
    if (!showSmartReplies || isNullOrEmpty(_messages)! || kIsWeb || kIsDesktop || !mounted || !ls.isAlive) return;

    if (updateConversation) {
      _messages.reversed.where((e) => !isNullOrEmpty(e.fullText)! && e.dateCreated != null).skip(max(_messages.length - 5, 0)).forEach((message) {
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
      smartReply.addMessageToConversationFromLocalUser(message.fullText, message.dateCreated!.millisecondsSinceEpoch);
    } else {
      smartReply.addMessageToConversationFromRemoteUser(
          message.fullText, message.dateCreated!.millisecondsSinceEpoch, message.handle?.address ?? "participant");
    }
  }

  Future<void> loadNextChunk({int limit = 25}) async {
    if (noMoreMessages || fetching) return;
    fetching = true;

    // Start loading the next chunk of messages
    noMoreMessages = !(await messageService.loadChunk(_messages.length, controller, limit: limit).catchError((e) {
      Logger.error("Failed to fetch message chunk! $e");
      return true;
    }));

    if (noMoreMessages) return setState(() {});

    final oldLength = _messages.length;
    _messages = messageService.struct.messages;
    _messages.sort(Message.sort);
    fetching = false;
    _messages.sublist(max(oldLength - 1, 0)).forEachIndexed((i, m) {
      if (!mounted) return;
      final c = mwc(m);
      c.cvController = controller;
      listKey.currentState!.insertItem(i, duration: const Duration(milliseconds: 0));
    });
    // should only happen when a reaction is the most recent message
    if (oldLength == 0) {
      setState(() {});
    }
  }

  void handleNewMessage(Message message) async {
    _messages.add(message);
    _messages.sort(Message.sort);
    final insertIndex = _messages.indexOf(message);

    if (listKey.currentState != null) {
      listKey.currentState!.insertItem(
        insertIndex,
        duration: const Duration(milliseconds: 500),
      );
    }

    if (insertIndex == 0 && showSmartReplies) {
      _addMessageToSmartReply(message);
      if (message.isFromMe!) {
        smartReplies.clear();
      } else {
        updateReplies(updateConversation: false);
      }
    }

    if (insertIndex == 0 && !message.isFromMe! && ss.settings.receiveSoundPath.value != null && cm.isChatActive(chat.guid)) {
      if (kIsDesktop) {
        Player player = Player();
        player.stream.completed
            .firstWhere((completed) => completed)
            .then((_) async => Future.delayed(const Duration(milliseconds: 500), () async => await player.dispose()));
        await player.setVolume(ss.settings.soundVolume.value.toDouble());
        await player.open(Media(ss.settings.receiveSoundPath.value!));
      } else {
        PlayerController controller = PlayerController();
        await controller
            .preparePlayer(path: ss.settings.receiveSoundPath.value!, volume: ss.settings.soundVolume.value / 100)
            .then((_) => controller.startPlayer());
      }
    }
  }

  void handleUpdatedMessage(Message message, {String? oldGuid}) {
    final index = _messages.indexWhere((e) => e.guid == (oldGuid ?? message.guid));
    if (index != -1) {
      _messages[index] = message;
    }
    if (message.wasDeliveredQuietly != latestMessageDeliveredState.value) {
      latestMessageDeliveredState.value = message.wasDeliveredQuietly;
    }
  }

  void handleDeletedMessage(Message message) {
    final index = _messages.indexWhere((e) => e.guid == message.guid);
    if (index != -1) {
      _messages.removeAt(index);
      listKey.currentState!.removeItem(index, (context, animation) => const SizedBox.shrink());
    }
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
          onTap: onTap ??
              () {
                outq.queue(OutgoingItem(
                  type: QueueType.sendMessage,
                  chat: controller.chat,
                  message: Message(
                    text: text,
                    dateCreated: DateTime.now(),
                    hasAttachments: false,
                    isFromMe: true,
                    handleId: 0,
                  ),
                ));
              },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 1.5, left: 13.0, right: 13.0),
              child: Obx(() => RichText(
                    text: TextSpan(
                      children: MessageHelper.buildEmojiText(
                        jumpingToOldestUnread.value && text == "Jump to oldest unread" ? "Jumping to oldest unread..." : text,
                        context.theme.extension<BubbleText>()!.bubbleText,
                      ),
                    ),
                  )),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const moonIcon = CupertinoIcons.moon_fill;
    return DropRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      formats: Formats.standardFormats,
      onDropOver: (DropOverEvent event) {
        if (!event.session.allowedOperations.contains(DropOperation.copy)) {
          dragging.value = false;
          return DropOperation.forbidden;
        }
        numFiles.value = event.session.items.where((item) => Formats.standardFormats.whereType<FileFormat>().any((f) => item.canProvide(f))).length;
        if (numFiles.value > 0) {
          dragging.value = true;
          return DropOperation.copy;
        }

        dragging.value = false;
        return DropOperation.forbidden;
      },
      onDropLeave: (_) {
        dragging.value = false;
      },
      onPerformDrop: (PerformDropEvent event) async {
        for (DropItem item in event.session.items) {
          final reader = item.dataReader!;
          FileFormat? format = reader.getFormats(Formats.standardFormats).whereType<FileFormat>().firstOrNull;

          if (format == null) return;

          reader.getFile(format, (file) async {
            Uint8List bytes = await file.readAll();
            controller.pickedAttachments.add(PlatformFile(
              path: file.fileName!,
              name: file.fileName!,
              size: file.fileSize!,
              bytes: bytes,
            ));
          });
        }
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
          child: Stack(
            children: [
              Obx(
                () => AnimatedOpacity(
                  opacity: _messages.isEmpty && widget.customService == null ? 0 : (dragging.value ? 0.3 : 1),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeIn,
                  child: DeferredPointerHandler(
                    child: ScrollbarWrapper(
                      reverse: true,
                      controller: scrollController,
                      showScrollbar: true,
                      child: CustomScrollView(
                        controller: scrollController,
                        reverse: true,
                        physics: ThemeSwitcher.getScrollPhysics(),
                        slivers: <Widget>[
                          if (showSmartReplies || internalSmartReplies.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Obx(() => AnimatedSize(
                                  duration: const Duration(milliseconds: 400),
                                  child: smartReplies.isNotEmpty || internalSmartReplies.isNotEmpty
                                      ? Padding(
                                          padding: EdgeInsets.only(top: iOS ? 8.0 : 0.0, right: 5),
                                          child: SizedBox(
                                            height: context.theme.extension<BubbleText>()!.bubbleText.fontSize! + 35,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              reverse: true,
                                              children: List<Widget>.from(smartReplies)..addAll(internalSmartReplies.values),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink())),
                            ),
                          if (!chat.isGroup && chat.isIMessage)
                            SliverToBoxAdapter(
                                child: AnimatedSize(
                              key: controller.focusInfoKey,
                              duration: const Duration(milliseconds: 250),
                              child: Obx(() => controller.recipientNotifsSilenced.value
                                  ? Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                String.fromCharCode(moonIcon.codePoint),
                                                style: TextStyle(
                                                  fontFamily: moonIcon.fontFamily,
                                                  package: moonIcon.fontPackage,
                                                  fontSize: context.theme.textTheme.bodyMedium!.fontSize,
                                                  color: context.theme.colorScheme.tertiaryContainer,
                                                ),
                                              ),
                                              Text(
                                                " ${chat.title ?? "Recipient"} has notifications silenced",
                                                style:
                                                    context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.tertiaryContainer),
                                              ),
                                            ],
                                          ),
                                          Obx(() {
                                            // DO NOT REMOVE, used to update Obx widget
                                            latestMessageDeliveredState.value;
                                            if (_messages.firstOrNull?.isFromMe == true &&
                                                _messages.firstOrNull?.dateRead == null &&
                                                _messages.firstOrNull?.wasDeliveredQuietly == true &&
                                                _messages.firstOrNull?.didNotifyRecipient == false) {
                                              return TextButton(
                                                child: Text("Notify Anyway",
                                                    style: context.theme.textTheme.labelLarge!
                                                        .copyWith(color: context.theme.colorScheme.tertiaryContainer)),
                                                onPressed: () async {
                                                  await http.notify(_messages.first.guid!);
                                                },
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          }),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink()),
                            )),
                          SliverToBoxAdapter(
                            child: Obx(() => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (controller.showTypingIndicator.value && ss.settings.alwaysShowAvatars.value && iOS)
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
                                      child: TypingIndicator(
                                        controller: controller,
                                      ),
                                    ),
                                  ],
                                )),
                          ),
                          if (_messages.isEmpty && widget.customService != null)
                            const SliverToBoxAdapter(
                              child: Loader(text: "Loading surrounding message context..."),
                            ),
                          SliverAnimatedList(
                              initialItemCount: _messages.length + 1,
                              key: listKey,
                              itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                                // paginate
                                if (index >= _messages.length) {
                                  if (!noMoreMessages && initialized && index == _messages.length) {
                                    if (!fetching) {
                                      loadNextChunk();
                                    }
                                    return const Loader();
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

                                final message = _messages[index];
                                final messageWidget = Padding(
                                  padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                  child: AutoScrollTag(
                                    key: ValueKey("${message.guid!}-scrolling"),
                                    index: index,
                                    controller: scrollController,
                                    highlightColor: context.theme.colorScheme.surface.withOpacity(0.7),
                                    child: MessageHolder(
                                      cvController: controller,
                                      message: message,
                                      oldMessageGuid: olderMessage?.guid,
                                      newMessageGuid: newerMessage?.guid,
                                    ),
                                  ),
                                );

                                if (index == 0) {
                                  return SizeTransition(
                                    key: ValueKey(_messages[index].guid!),
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
                                        child: AnimatedBuilder(
                                          animation: animation,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: message.guid!.contains("temp") &&
                                                      (!isNullOrEmpty(message.text)! || !isNullOrEmpty(message.subject)!) &&
                                                      !animation.isCompleted
                                                  ? 0
                                                  : 1,
                                              child: child,
                                            );
                                          },
                                          child: messageWidget,
                                        )),
                                  );
                                }

                                return SizedBox(
                                  key: ValueKey(_messages[index].guid!),
                                  child: messageWidget,
                                );
                              }),
                          const SliverPadding(
                            padding: EdgeInsets.all(70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Obx(
                () => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  color: context.theme.colorScheme.surface.withOpacity(dragging.value ? 0.4 : 0),
                  child: dragging.value
                      ? Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(iOS ? CupertinoIcons.paperclip : Icons.attach_file, color: context.theme.colorScheme.primary, size: 50),
                              Text("Attach ${numFiles.value} File${numFiles.value > 1 ? 's' : ''}",
                                  style: context.theme.textTheme.headlineLarge!.copyWith(color: context.theme.colorScheme.primary)),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          )),
    );
  }
}

class Loader extends StatelessWidget {
  const Loader({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text ?? "Loading more messages...",
            style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.outline),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ss.settings.skin.value == Skins.iOS
              ? Theme(
                  data: ThemeData(
                    cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark),
                  ),
                  child: const CupertinoActivityIndicator(),
                )
              : const SizedBox(height: 20, width: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ],
    );
  }
}
