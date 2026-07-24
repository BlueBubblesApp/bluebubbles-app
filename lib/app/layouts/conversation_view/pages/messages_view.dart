import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/mixins/messages_service_mixin.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/messages_view_components.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'handlers/drop_zone_manager.dart';
import 'handlers/message_animation_orchestrator.dart';
import 'handlers/smart_replies_manager.dart';

class MessagesView extends StatefulWidget {
  final MessagesService? customService;
  final ConversationViewController controller;
  final String? initialScrollToGuid;

  const MessagesView({
    super.key,
    this.customService,
    this.initialScrollToGuid,
    required this.controller,
  });

  @override
  MessagesViewState createState() => MessagesViewState();
}

class MessagesViewState extends State<MessagesView> with MessagesServiceMixin, ThemeHelpers {
  bool handlersInitialized = false;
  bool fetching = false;
  bool noMoreMessages = false;
  List<Message> _messages = <Message>[];

  // GlobalKey for SliverAnimatedList
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey<SliverAnimatedListState>();

  // Notifier for list structure changes only (add/remove)
  final ValueNotifier<int> _listVersion = ValueNotifier<int>(0);

  // Per-message GlobalKeys so that element state (e.g. UrlPreview) survives
  // index shifts when a new message is inserted at the front of the list.
  final Map<String, GlobalKey> _messageKeys = {};

  // Debounce setState calls to prevent rapid rebuilds
  Timer? _setStateDebouncer;
  StreamSubscription? _eventSubscription;

  // Managers for different responsibilities
  late final SmartRepliesManager smartRepliesManager;
  late final DropZoneManager dropZoneManager;
  late final MessageAnimationOrchestrator animationOrchestrator;

  RxMap<String, Widget> internalSmartReplies = <String, Widget>{}.obs;
  final RxBool latestMessageDeliveredState = false.obs;
  final RxBool jumpingToOldestUnread = false.obs;

  ConversationViewController get controller => widget.controller;
  AutoScrollController get scrollController => controller.scrollController;

  Chat get chat => controller.chat;

  bool get smartRepliesEnabled => !kIsWeb && !kIsDesktop && SettingsSvc.settings.smartReply.value;

  bool get showSmartReplies => smartRepliesEnabled && smartRepliesManager.shouldShowSmartReplies(_messages.isEmpty);

  @override
  void initState() {
    super.initState();
    smartRepliesManager = SmartRepliesManager();
    dropZoneManager = DropZoneManager(controller: controller);
    animationOrchestrator = MessageAnimationOrchestrator();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Fires after this frame rather than racing against loadChunk.
      controller.markMessagesViewReady();

      // Trigger a rebuild to display the messages.
      setState(() {});
    });

    _eventSubscription = EventDispatcherSvc.stream.listen((e) async {
      if (!mounted) return;
      if (e.type == "refresh-messagebloc" && e.data == chat.guid) {
        // Clear state items
        noMoreMessages = false;
        _messages = [];
        _messageKeys.clear();
        // Reload the state after refreshing
        await reloadMessagesService(
          chat,
          controller,
          onNewMessage: handleNewMessage,
          onUpdatedMessage: handleUpdatedMessage,
          onDeletedMessage: handleDeletedMessage,
          onJumpToMessage: jumpToMessage,
          messages: _messages,
        );
        if (!mounted) return;
        setState(() {});
      } else if (e.type == "add-custom-smartreply") {
        if (!mounted) return;
        if (e.data != null && internalSmartReplies['attach-recent'] == null) {
          internalSmartReplies['attach-recent'] = _buildReply("Attach recent photo", onTap: () async {
            controller.pickedAttachments.add(e.data);
            internalSmartReplies.clear();
          });
        }
      }
    });

    () async {
      if (chat.isIMessage && !chat.isGroup) {
        getFocusState();
      }

      // Only load if not already initialized from customService
      if (!handlersInitialized) {
        // Get or create the service
        final service =
            widget.customService != null ? registerMessagesSvc(widget.customService!) : ensureMessagesSvc(chat.guid);

        // Initialize with handlers
        service.init(
          chat,
          handleNewMessage,
          handleUpdatedMessage,
          handleDeletedMessage,
          jumpToMessage,
          _messages,
        );

        // Load messages if needed (check service flag to avoid redundant loads).
        // Wrap in try-catch: if loadChunk throws (e.g. server HTTP error for a
        // brand-new chat), we must still initialise handlers and mark the view
        // ready so pendingSend can fire and handleNewMessage works correctly.
        try {
          if (!service.messagesLoaded) {
            await service.loadChunk(0, controller);
          }
        } catch (e, s) {
          Logger.error('MessagesView: loadChunk failed, continuing with empty state',
              error: e, trace: s, tag: 'MessagesView');
        }

        _messages = service.struct.messages;
        _messages.sort(Message.sort);

        // Initialize the mixin's service reference and create controllers.
        // This MUST always run so _messageService is non-null when
        // handleNewMessage → createStateForMessage is later called.
        initializeMessagesService(
          chat,
          _messages,
          controller,
          customService: service,
          onNewMessage: handleNewMessage,
          onUpdatedMessage: handleUpdatedMessage,
          onDeletedMessage: handleDeletedMessage,
          onJumpToMessage: jumpToMessage,
        );

        // Recreate the list key to force SliverAnimatedList to rebuild with correct item count
        _listKey = GlobalKey<SliverAnimatedListState>();
        handlersInitialized = true;
        if (!mounted) return;
        setState(() {});

        // Notify SendAnimation that handlers + list key are fully ready so that
        // any pending send fires after the rebuilt SliverAnimatedList is mounted.
        controller.markMessagesViewReady();
      }

      // If this is a search result, load surrounding context and scroll/highlight it
      if (widget.initialScrollToGuid != null) {
        await _scrollToSearchResult(widget.initialScrollToGuid!);
      }

      if (!(_messages.firstOrNull?.isFromMe ?? true)) {
        updateReplies();
      }
      if (SettingsSvc.settings.scrollToLastUnread.value && chat.lastReadMessageGuid != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (messageService.getMessageStateIfExists(chat.lastReadMessageGuid!)?.built ?? false) return;
          internalSmartReplies['scroll-last-read'] = _buildReply("Jump to oldest unread", onTap: () async {
            if (jumpingToOldestUnread.value) return;
            jumpingToOldestUnread.value = true;
            await jumpToMessage(chat.lastReadMessageGuid!);
            internalSmartReplies.remove('scroll-last-read');
            jumpingToOldestUnread.value = false;
          });
        });
      }
    }();
  }

  @override
  void dispose() {
    // Clean up managers
    if (_messages.isNotEmpty) {
      chat.lastReadMessageGuid = _messages.first.guid;
      chat.saveAsync(updateLastReadMessageGuid: true);
    }

    // Reset the ready-signal so a future pendingSend on the same CVC starts fresh.
    controller.resetMessagesViewReady();

    // When a customService is provided it is shared with (or transferred to) the
    // ConversationView we are navigating to.  Calling close() on it can delete
    // it from GetX's registry when lastReloadedChat differs from the chat's tag
    // (e.g. the user arrived from a different conversation).  That would cause
    // prepMessage's Get.isRegistered guard to return false, silently skipping
    // addNewMessage so the pending send never appears in the list — a bug that
    // only surfaces in release/AOT mode where the dispose races the send.
    // Solution: just detach our local reference and leave the service intact.
    disposeMessagesService(
      force: widget.customService == null,
      onlyDetach: widget.customService != null,
    );

    // Controllers are now disposed by MessagesService.onClose()
    _setStateDebouncer?.cancel();
    _eventSubscription?.cancel();
    _listVersion.dispose();
    super.dispose();
  }

  Future<void> _scrollToSearchResult(String guid) async {
    if (!mounted) return;

    // Find the target message in the current (pre-seeded) message list
    final targetMessage = _messages.firstWhereOrNull((m) => m.guid == guid);
    if (targetMessage == null) return;

    // Load messages surrounding the search result
    final method = messageService.method == "local" ? SearchMethod.local : SearchMethod.network;
    await loadSearchChunk(targetMessage, method);

    if (!mounted) return;

    // Merge newly loaded messages into the local list
    final oldGuids = Set<String>.from(_messages.map((m) => m.guid).whereType<String>());
    final newMessages =
        messageService.struct.messages.where((m) => m.guid != null && !oldGuids.contains(m.guid)).toList();

    if (newMessages.isNotEmpty) {
      createStatesForMessages(newMessages, controller);
      _messages = List<Message>.from(messageService.struct.messages);
      _messages.sort(Message.sort);
      _listKey = GlobalKey<SliverAnimatedListState>();
      if (mounted) setState(() {});
      // Allow the list to render before scrolling
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;
    await jumpToMessage(guid);
  }

  void getFocusState() {
    if (!SettingsSvc.serverDetails.isMinMonterey) return;
    final recipient = chat.handles.firstOrNull;
    if (recipient != null) {
      HttpSvc.handle.handleFocusState(recipient.address).then((response) {
        if (!mounted) return;
        final status = response.data['data']['status'];
        controller.recipientNotifsSilenced.value = status != "none";
      }).catchError((error, stack) async {
        Logger.error('Failed to get focus state!', error: error, trace: stack);
      });
    }
  }

  Future<void> jumpToMessage(String guid) async {
    // check if the message is already loaded
    int index = _messages.indexWhere((element) => element.guid == guid);
    if (index != -1) {
      await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
      scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 2000));
      return;
    }
    // otherwise fetch until it is loaded
    final message = Message.findOne(guid: guid);
    final query = (Database.messages.query(Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull()))
          ..link(Message_.chat, Chat_.id.equals(chat.id!))
          ..order(Message_.dateCreated, flags: Order.descending))
        .build();
    final ids = await query.findIdsAsync();
    final pos = ids.indexOf(message!.id!);
    await _loadMoreMessages(limit: pos + 10);
    index = _messages.indexWhere((element) => element.guid == guid);
    if (index != -1) {
      await scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
      scrollController.highlight(index, highlightDuration: const Duration(milliseconds: 2000));
    } else {
      showSnackbar("Error", "Failed to find message!");
    }
  }

  void updateReplies({bool updateConversation = true}) async {
    if (!smartRepliesEnabled || isNullOrEmpty(_messages) || !mounted || !LifecycleSvc.isAlive) {
      return;
    }

    if (updateConversation) {
      _messages.reversed
          .where((e) => !isNullOrEmpty(e.fullText) && e.dateCreated != null)
          .skip(max(_messages.length - 5, 0))
          .forEach((message) {
        smartRepliesManager.addMessageToContext(message);
      });
    }
    Logger.info("Getting smart replies...");
    await smartRepliesManager.generateSuggestions();
    if (mounted) {
      // Update observable if smart replies changed
      if (smartRepliesManager.smartReplies.isNotEmpty) {
        // Note: the RxList is already updated in the manager, just ensure UI knows
      }
    }
  }

  Future<void> _loadMoreMessages({int limit = 25}) async {
    if (noMoreMessages || fetching) {
      Logger.debug("_loadMoreMessages: Skipping - noMoreMessages=$noMoreMessages, fetching=$fetching");
      return;
    }
    fetching = true;
    final previousLength = _messages.length;
    Logger.debug("_loadMoreMessages: Starting - current messages: $previousLength");

    // Start loading the next chunk of messages using mixin method
    noMoreMessages = !(await loadNextChunk(controller, _messages, limit: limit).catchError((e, stack) {
      Logger.error("Failed to fetch message chunk!", error: e, trace: stack);
      fetching = false;
      return true;
    }));

    if (!mounted) return;

    if (noMoreMessages) {
      Logger.debug("loadNextChunk: No more messages available");
      fetching = false;
      setState(() {});
      return;
    }

    final oldLength = _messages.length;
    final oldMessageGuids = Set<String>.from(_messages.map((m) => m.guid).whereType<String>());

    final newMessagesFromService = messageService.struct.messages;
    final newMessages = newMessagesFromService.where((m) => !oldMessageGuids.contains(m.guid)).toList();

    Logger.debug(
        "loadNextChunk: Found ${newMessages.length} new messages (old: $oldLength, new: ${newMessagesFromService.length})");

    // Initialize message widget controllers for new messages
    for (final newMsg in newMessages) {
      createStateForMessage(newMsg, controller);
    }

    // Update the list without animation (bulk load)
    _messages = newMessagesFromService;
    _messages.sort(Message.sort);
    fetching = false;

    // Batch loading: recreate the list key to force rebuild without animation
    _listKey = GlobalKey<SliverAnimatedListState>();
    if (mounted) setState(() {});
  }

  void handleNewMessage(Message message) async {
    // Check if widget is still mounted before processing
    if (!mounted) {
      return;
    }

    Logger.debug("handleNewMessage: Received new message ${message.guid}, current count: ${_messages.length}");

    // Check if message already exists to prevent duplicates
    final existingIndex = _messages.indexWhere((m) => m.guid == message.guid);
    if (existingIndex != -1) {
      Logger.debug(
          "handleNewMessage: Message ${message.guid} already exists at index $existingIndex, skipping duplicate");
      return;
    }

    // Capture before adding so we know whether a rebuild is needed to hide the loader.
    final wasEmpty = _messages.isEmpty;
    _messages.add(message);
    _messages.sort(Message.sort);
    final insertIndex = _messages.indexOf(message);

    // Initialize message widget controller
    createStateForMessage(message, controller);

    // Mark this message for animation (all new messages)
    animationOrchestrator.markAnimating(message);

    // Use insertItem to animate the list sliding up to make space (all messages)
    final duration = animationOrchestrator.getInsertionDuration();
    _listKey.currentState?.insertItem(
      insertIndex,
      duration: duration,
    );

    // Update version tracker
    _listVersion.value++;

    // When the first message arrives via socket into an empty view, the
    // "Loading surrounding message context..." SliverToBoxAdapter won't
    // disappear on its own (insertItem only updates the SliverAnimatedList,
    // not sibling slivers). Force a full rebuild to hide the loader.
    if (wasEmpty && mounted) setState(() {});

    // Clear animation flag after animation completes
    Future.delayed(duration, () {
      animationOrchestrator.clearAnimating(message, mounted: mounted);
    });

    if (insertIndex == 0 && smartRepliesEnabled) {
      smartRepliesManager.addMessageToContext(message);
      if (message.isFromMe!) {
        smartRepliesManager.smartReplies.clear();
      } else {
        updateReplies(updateConversation: false);
      }
    }

    if (insertIndex == 0 && !message.isFromMe! && SettingsSvc.settings.receiveSoundPath.value != null) {
      if (kIsDesktop && (ChatsSvc.getChatState(chat.guid)?.isActive.value ?? false)) {
        Player player = Player();
        player.stream.completed
            .firstWhere((completed) => completed)
            .then((_) async => Future.delayed(const Duration(milliseconds: 500), () async => await player.dispose()));
        await player.setVolume(SettingsSvc.settings.soundVolume.value.toDouble());
        await player.open(Media(SettingsSvc.settings.receiveSoundPath.value!));
      } else if (ChatsSvc.isChatActive(chat.guid)) {
        PlayerController controller = PlayerController();
        await controller
            .preparePlayer(
                path: SettingsSvc.settings.receiveSoundPath.value!,
                volume: SettingsSvc.settings.soundVolume.value / 100)
            .then((_) => controller.startPlayer());
      }
    }
  }

  void handleUpdatedMessage(Message message, {String? oldGuid}) {
    // Check if widget is still mounted before processing
    if (!mounted) return;

    Logger.debug("handleUpdatedMessage: Updating message ${oldGuid ?? message.guid}");
    final index = _messages.indexWhere((e) => e.guid == (oldGuid ?? message.guid));
    if (index != -1) {
      _messages[index] = message;
      Logger.debug("handleUpdatedMessage: Updated message at index $index");
    } else {
      Logger.warn("handleUpdatedMessage: Message ${oldGuid ?? message.guid} not found in list");
    }
    if (message.wasDeliveredQuietly != latestMessageDeliveredState.value) {
      latestMessageDeliveredState.value = message.wasDeliveredQuietly;
    }
  }

  void handleDeletedMessage(Message message) {
    // Check if widget is still mounted before processing
    if (!mounted) return;

    Logger.debug("handleDeletedMessage: Deleting message ${message.guid}");
    final index = _messages.indexWhere((e) => e.guid == message.guid);
    if (index != -1) {
      _messages.removeAt(index);
      _messageKeys.remove(message.guid);
      Logger.debug("handleDeletedMessage: Removed message at index $index");
      _listVersion.value++;
      _setStateDebouncer?.cancel();
      _setStateDebouncer = Timer(const Duration(milliseconds: 16), () {
        if (mounted) setState(() {});
      });
    } else {
      Logger.warn("handleDeletedMessage: Message ${message.guid} not found in list");
    }
  }

  Widget _buildReply(String text, {Function()? onTap}) => Builder(
        builder: (replyContext) {
          final theme = Theme.of(replyContext);
          final hasBackground =
              ChatsSvc.getChatState(controller.chat.guid)?.customBackgroundPath.value?.isNotEmpty == true;
          return Container(
            margin: const EdgeInsets.all(5),
            decoration: hasBackground
                ? BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(19),
                  )
                : BoxDecoration(
                    border: Border.all(
                      width: 2,
                      style: BorderStyle.solid,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: onTap ??
                  () {
                    OutgoingMsgHandler.queue(OutgoingMessage(
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
                            jumpingToOldestUnread.value && text == "Jump to oldest unread"
                                ? "Jumping to oldest unread..."
                                : text,
                            theme.extension<BubbleText>()!.bubbleText,
                          ),
                        ),
                      )),
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (DropEventDetails details) => dropZoneManager.onDropOver(details),
      onDragUpdated: (DropEventDetails details) => dropZoneManager.onDropOver(details),
      onDragExited: (DropEventDetails details) => dropZoneManager.onDropLeave(details),
      onDragDone: (DropDoneDetails details) async => await dropZoneManager.onPerformDrop(details, controller),
      child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onHorizontalDragUpdate: (details) {
            if (SettingsSvc.settings.skin.value != Skins.Samsung && !kIsWeb && !kIsDesktop) {
              controller.timestampOffset.value += details.delta.dx * 0.3;
            }
          },
          onHorizontalDragEnd: (details) {
            if (SettingsSvc.settings.skin.value != Skins.Samsung) {
              controller.timestampOffset.value = 0;
            }
          },
          onHorizontalDragCancel: () {
            if (SettingsSvc.settings.skin.value != Skins.Samsung) {
              controller.timestampOffset.value = 0;
            }
          },
          child: Stack(
            children: [
              Obx(
                () => AnimatedOpacity(
                  opacity: _messages.isEmpty && widget.customService == null
                      ? 0
                      : (dropZoneManager.dragging.value ? 0.3 : 1),
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
                          SliverToBoxAdapter(
                            child: SmartRepliesRow(
                              controller: controller,
                              smartReplies: smartRepliesManager.smartReplies,
                              internalSmartReplies: internalSmartReplies,
                            ),
                          ),
                          if (!chat.isGroup && chat.isIMessage)
                            SliverToBoxAdapter(
                              child: NotificationsSilencedBanner(
                                controller: controller,
                                latestMessage: _messages.firstOrNull,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: TypingIndicatorRow(
                              controller: controller,
                            ),
                          ),
                          if (_messages.isEmpty)
                            const SliverToBoxAdapter(
                              child: Loader(text: "Loading surrounding message context..."),
                            ),
                          Builder(
                            builder: (context) {
                              return SliverAnimatedList(
                                key: _listKey,
                                initialItemCount: _messages.length + 1,
                                itemBuilder: (BuildContext context, int index, Animation<double> animation) {
                                  try {
                                    // paginate
                                    if (index >= _messages.length) {
                                      if (!noMoreMessages && handlersInitialized && index == _messages.length) {
                                        if (!fetching) {
                                          _loadMoreMessages();
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
                                    final messageId = message.guid ?? 'unknown-$index';
                                    final messageWidget = RepaintBoundary(
                                      key: _messageKeys.putIfAbsent(messageId, () => GlobalKey()),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                        child: AutoScrollTag(
                                          key: ValueKey("$messageId-scrolling"),
                                          index: index,
                                          controller: scrollController,
                                          highlightColor: context.theme.colorScheme.surface.withValues(alpha: 0.7),
                                          child: MessageHolder(
                                            cvController: controller,
                                            message: message,
                                            oldMessage: olderMessage,
                                            newMessage: newerMessage,
                                          ),
                                        ),
                                      ),
                                    );

                                    // Animate sent messages with size + slide + fade (only if outgoing from this device)
                                    final isFromMe = message.isFromMe ?? false;
                                    if (isFromMe &&
                                        message.isSending &&
                                        animationOrchestrator.isMessageAnimating(message)) {
                                      return animationOrchestrator.buildSentMessageAnimation(
                                        child: messageWidget,
                                        animation: animation,
                                      );
                                    }

                                    // Animate other messages with size + slide only (received or from other devices)
                                    if (animationOrchestrator.isMessageAnimating(message)) {
                                      return animationOrchestrator.buildReceivedMessageAnimation(
                                        child: messageWidget,
                                        animation: animation,
                                      );
                                    }

                                    return messageWidget;
                                  } catch (e, stack) {
                                    Logger.error("Error in SliverAnimatedList itemBuilder at index $index",
                                        error: e, trace: stack);
                                    return SizedBox(
                                      key: ValueKey('error-$index'),
                                      height: 50,
                                      child: Center(
                                        child: Text('Error loading message at index $index'),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.all(70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DragDropOverlay(
                dragging: dropZoneManager.dragging,
              ),
            ],
          )),
    );
  }
}

class Loader extends StatelessWidget {
  const Loader({super.key, this.text});

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
          child: SettingsSvc.settings.skin.value == Skins.iOS
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
