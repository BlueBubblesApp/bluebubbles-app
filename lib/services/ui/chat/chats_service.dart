import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:bluebubbles/services/backend/notifications/desktop_notification.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey, MessageSaveResult;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
ChatsService get ChatsSvc => GetIt.I<ChatsService>();

class ChatsService {
  static const batchSize = 100;
  int currentCount = 0;
  StreamSubscription? countSub;
  bool headless = false;

  final RxBool hasChats = false.obs;
  Completer<void> loadedAllChats = Completer();
  final RxBool loadedFirstChatBatch = false.obs;

  /// Global unread count across all chats
  final RxInt unreadCount = 0.obs;

  /// Map of chat states for granular reactivity
  /// Key is the chat GUID, value is the ChatState
  /// The map itself doesn't need to be Rx because the underlying ChatState fields are
  final Map<String, ChatState> chatStates = {};

  ChatState? _activeChat;
  ChatState? get activeChat => _activeChat;
  set activeChat(ChatState? value) {
    _activeChat = value;
    final guid = value?.chat.guid;
    if (activeChatGuid.value != guid) activeChatGuid.value = guid;
  }

  /// Reactive guid of the active chat. Tiles observe this for highlighting instead
  /// of a ChatState instance — it survives chatStates being cleared/rebuilt (reset,
  /// reload) and never diverges from a permanent tile controller's captured state.
  final RxnString activeChatGuid = RxnString();

  /// Sorted list of chats maintained for efficient access
  /// Updated on add/update using binary search insertion O(log n + n)
  /// instead of sorting entire list O(n log n) on every access
  final List<Chat> _sortedChats = [];

  /// Reactive counter that increments when chat list order changes
  /// Used to trigger UI rebuilds when chats are repositioned
  final RxInt chatListVersion = 0.obs;

  /// Timer for debouncing chatListVersion updates to prevent rapid UI rebuilds
  Timer? _listVersionUpdateTimer;

  /// Listeners for redacted mode settings to update all ChatStates
  StreamSubscription? _redactedModeListener;
  StreamSubscription? _hideContactInfoListener;
  StreamSubscription? _generateFakeAvatarsListener;
  StreamSubscription? _hideAttachmentsListener;

  // ========== Helper Getters (replacing direct chats access) ==========

  /// Get all chats as a list (non-reactive), sorted by pin index and latest message date
  /// Returns the pre-sorted list for O(1) access instead of O(n log n) sorting
  List<Chat> get allChats {
    return _sortedChats;
  }

  /// Check if chats list is empty
  bool get isEmpty {
    return chatStates.isEmpty;
  }

  /// Get number of chats
  int get length {
    return chatStates.length;
  }

  /// Find chat by GUID
  Chat? findChatByGuid(String guid) {
    return chatStates[guid]?.chat;
  }

  /// Find chat by chat identifier
  Chat? findChatByChatIdentifier(String chatIdentifier) {
    return chatStates.values.map((state) => state.chat).firstWhereOrNull((c) => c.chatIdentifier == chatIdentifier);
  }

  /// Get chat at specific index (from sorted list)
  Chat? getChatAtIndex(int index) {
    final sortedChats = getSortedChats();
    if (index < 0 || index >= sortedChats.length) return null;
    return sortedChats[index];
  }

  /// Get filtered chats (archived, unknown senders, pinned)
  List<Chat> getFilteredChats({
    bool? showArchived,
    bool? showUnknown,
    bool? pinnedOnly,
    bool? excludePinned,
  }) {
    var chats = allChats;

    // Apply archived filter
    if (showArchived != null) {
      if (showArchived) {
        chats = chats.where((e) => e.isArchived ?? false).toList();
      } else {
        chats = chats.where((e) => !(e.isArchived ?? false)).toList();
      }
    }

    // Apply unknown senders filter
    if (showUnknown != null && SettingsSvc.settings.filterUnknownSenders.value) {
      if (showUnknown) {
        chats = chats.where((e) => !e.isGroup && e.handles.firstOrNull?.contactsV2.isEmpty != false).toList();
      } else {
        chats = chats
            .where((e) => e.isGroup || (!e.isGroup && e.handles.firstOrNull?.contactsV2.isNotEmpty == true))
            .toList();
      }
    }

    // Apply pinned filter
    if (pinnedOnly == true) {
      chats = chats.where((e) => e.isPinned ?? false).toList();
    } else if (excludePinned == true) {
      chats = chats.where((e) => !(e.isPinned ?? false)).toList();
    }

    return chats;
  }

  /// Get only group chats
  List<Chat> get groupChats {
    return allChats.where((c) => c.isGroup).toList();
  }

  /// Get pinned chats
  List<Chat> get pinnedChats {
    return getSortedChats().where((c) => (c.pinIndex ?? -1) >= 0).toList()
      ..sort((a, b) => (a.pinIndex ?? 0).compareTo(b.pinIndex ?? 0));
  }

  /// Search chats by title
  List<Chat> searchChats(String query) {
    return allChats
        .where((element) => element.getTitle().toLowerCase().replaceAll(" ", "").contains(query.toLowerCase()))
        .toList();
  }

  /// Get next chat in sorted list (for keyboard navigation)
  Chat? getNextChat(String currentGuid) {
    final sortedChats = getSortedChats();
    final index = sortedChats.indexWhere((e) => e.guid == currentGuid);
    if (index > -1 && index < sortedChats.length - 1) {
      return sortedChats[index + 1];
    }
    return null;
  }

  /// Get previous chat in sorted list (for keyboard navigation)
  Chat? getPreviousChat(String currentGuid) {
    final sortedChats = getSortedChats();
    final index = sortedChats.indexWhere((e) => e.guid == currentGuid);
    if (index > 0 && index < sortedChats.length) {
      return sortedChats[index - 1];
    }
    return null;
  }

  final List<Handle> webCachedHandles = [];

  void initDbWatchers() {
    if (headless) return;
    if (!kIsWeb) {
      // watch for new chats
      final countQuery = (Database.chats.query(Chat_.dateDeleted.isNull())..order(Chat_.id, flags: Order.descending))
          .watch(triggerImmediately: true);
      countSub = countQuery.listen((event) async {
        if (!SettingsSvc.settings.finishedSetup.value) return;
        final newCount = event.count();
        if (newCount > currentCount && currentCount != 0) {
          final chat = event.findFirst()!;
          if (chat.dbOnlyLatestMessageDate == null || chat.dbOnlyLatestMessageDate!.millisecondsSinceEpoch == 0) {
            // wait for the chat.addMessage to go through
            await Future.delayed(const Duration(milliseconds: 500));
          }
          await addChat(chat, immediate: true);
        }
        currentCount = newCount;
      });
    } else {
      countSub = WebListeners.newChat.listen((chat) async {
        if (!SettingsSvc.settings.finishedSetup.value) return;
        await addChat(chat, immediate: true);
      });
    }
  }

  Future<void> init({bool force = false, bool headless = false}) async {
    this.headless = headless;
    if ((!force && !SettingsSvc.settings.finishedSetup.value) || headless) return;
    Logger.info("Fetching chats...", tag: "ChatBloc");

    reset();

    // Get current count from database or server
    currentCount = getChatCount() ??
        (await HttpSvc.chat.getCount().catchError((err) {
          Logger.info("Error when fetching chat count!", tag: "ChatBloc");
          return Response(requestOptions: RequestOptions(path: ''));
        }))
            .data['data']['total'] ??
        0;

    loadedAllChats = Completer();
    if (currentCount != 0) {
      hasChats.value = true;
    } else {
      loadedFirstChatBatch.value = true;
      initDbWatchers();
      return;
    }

    // Clear existing chats to avoid duplicates on re-init
    if (chatStates.isNotEmpty) {
      chatStates.clear();
      _sortedChats.clear();
    }

    final batches = (currentCount / batchSize).ceil();
    for (int i = 0; i < batches; i++) {
      final chatBatch = await Chat.getChatsAsync(limit: batchSize, offset: i * batchSize);
      if (kIsWeb) {
        webCachedHandles.addAll(chatBatch.map((e) => e.handles).flattened.toList());
        final ids = webCachedHandles.map((e) => e.address).toSet();
        webCachedHandles.retainWhere((element) => ids.remove(element.address));
      }

      // Insert each chat at the correct position using binary search
      // This maintains proper ordering including pinIndex which DB queries cannot handle
      for (Chat c in chatBatch) {
        // Create ChatState and add to map
        final state = chatStates[c.guid] = ChatState(c);
        _setupChatStateListeners(state);

        if (activeChatGuid.value == c.guid) {
          _activeChat = state;
          state.updateActiveAndAliveInternal(true);
        }

        // Add to sorted list
        _insertChatSorted(c);
      }
      loadedFirstChatBatch.value = true;
      // Increment chatListVersion after every batch so the UI rebuilds for each batch,
      // not just the first. loadedFirstChatBatch only fires once (false→true), so
      // subsequent batches would otherwise silently mutate _sortedChats with no Obx signal.
      _scheduleListVersionUpdate();
    }

    loadedAllChats.complete();
    Logger.info("Finished fetching chats (${chatStates.length}).", tag: "ChatBloc");

    // Calculate initial unread count now that all chat states are populated.
    // The listener only fires on changes, so we need an explicit call here to
    // seed the badge with the correct value before any message is received.
    _recalculateUnreadCount();

    if (kIsDesktop) {
      unawaited(
        DesktopNotifications.cancelStale(keepGroups: chatStates.values.where((s) => s.hasUnreadMessage.value).map((s) => s.chat.guid).toList())
      );
    }

    // Initialize watchers AFTER loading all chats to avoid duplicates
    initDbWatchers();

    // Set up global listeners for redacted mode settings
    _setupRedactedModeListeners();

    if (kIsDesktop && Platform.isWindows) {
      /* ----- IMESSAGE:// HANDLER ----- */
      final _appLinks = AppLinks();
      _appLinks.stringLinkStream.listen((String string) async {
        if (!string.startsWith("imessage://")) return;
        final uri = Uri.tryParse(string
            .replaceFirst("imessage://", "imessage:")
            .replaceFirst("&body=", "?body=")
            .replaceFirst(RegExp(r'/$'), ''));
        if (uri == null) return;

        final address = uri.path;
        final handle = Handle.findOne(addressAndService: HandleLookupKey(address, "iMessage"));
        NavigationSvc.closeSettings(Get.context!);
        await NavigationSvc.pushAndRemoveUntil(
          Get.context!,
          NewChatCreator(
            initialSelected: [SelectedContact(displayName: handle?.displayName ?? address, address: address)],
            initialText: uri.queryParameters['body'],
          ),
          (route) => route.isFirst,
        );
      });
    }
  }

  /// Get ChatState for a specific chat GUID
  ChatState? getChatState(String guid) {
    return chatStates[guid];
  }

  /// Returns the [ChatState] for [chat], creating a bare one if it doesn't exist yet.
  ///
  /// Used by [ConversationView] to obtain a state instance before the chat list
  /// has fully loaded (e.g. opened via deep-link or chat creator). The returned
  /// state is cached in [chatStates] so subsequent lookups return the same instance.
  ChatState getOrCreateChatState(Chat chat) {
    return chatStates.putIfAbsent(chat.guid, () => ChatState(chat));
  }

  /// Set up listeners on a ChatState to track unread count changes
  void _setupChatStateListeners(ChatState chatState) {
    // Listen to hasUnreadMessage changes to update global unread count
    chatState.hasUnreadMessage.listen((hasUnread) {
      _recalculateUnreadCount();
    });
  }

  /// Set up global listeners for redacted mode settings that update all chat states
  void _setupRedactedModeListeners() {
    // Cancel existing listeners if any
    _redactedModeListener?.cancel();
    _hideContactInfoListener?.cancel();
    _generateFakeAvatarsListener?.cancel();
    _hideAttachmentsListener?.cancel();

    // Listen to redacted mode master toggle - when enabled, redact all chats; when disabled, unredact all
    _redactedModeListener = SettingsSvc.settings.redactedMode.listen((enabled) {
      for (final chatState in chatStates.values) {
        if (enabled) {
          chatState.redactFields();
        } else {
          chatState.unredactFields();
        }
      }
    });

    // Listen to hideContactInfo toggle - only affects contact info fields
    _hideContactInfoListener = SettingsSvc.settings.hideContactInfo.listen((enabled) {
      for (final chatState in chatStates.values) {
        if (enabled) {
          chatState.redactContactInfo();
        } else {
          chatState.unredactContactInfo();
        }
      }
    });

    // Listen to generateFakeAvatars toggle - only affects avatar field
    _generateFakeAvatarsListener = SettingsSvc.settings.generateFakeAvatars.listen((enabled) {
      for (final chatState in chatStates.values) {
        if (enabled) {
          chatState.redactAvatars();
        } else {
          chatState.unredactAvatars();
        }
      }
    });

    // Listen to hideAttachments toggle - updates shouldHideAttachments on all chat states
    _hideAttachmentsListener = SettingsSvc.settings.hideAttachments.listen((enabled) {
      final rm = SettingsSvc.settings.redactedMode.value;
      for (final chatState in chatStates.values) {
        chatState.updateShouldHideAttachmentsInternal(rm && enabled);
      }
    });
  }

  /// Recalculate the global unread count based on all chat states
  void _recalculateUnreadCount() {
    final count = chatStates.values.where((state) => state.hasUnreadMessage.value).length;
    if (unreadCount.value != count) {
      unreadCount.value = count;
    }
  }

  /// Schedule a debounced update to chatListVersion to prevent rapid UI rebuilds
  /// Debounces updates by 150ms - if multiple updates occur in rapid succession,
  /// only the last one will trigger a UI rebuild
  /// If [immediate] is true, bypasses debouncing and updates immediately (for new messages)
  void _scheduleListVersionUpdate({bool immediate = false}) {
    if (immediate) {
      _listVersionUpdateTimer?.cancel();
      chatListVersion.value++;
    } else {
      _listVersionUpdateTimer?.cancel();
      _listVersionUpdateTimer = Timer(const Duration(milliseconds: 250), () {
        chatListVersion.value++;
      });
    }
  }

  /// Re-sort [_sortedChats] in-place and notify the chat list UI.
  ///
  /// Call this after bulk pin-index changes that were applied outside of the
  /// normal [updateChat] / [_repositionChat] path (e.g. pinned-order panel).
  /// The UI notification is deferred to the next frame so this is safe to call
  /// from [State.dispose] (while the widget tree may still be locked).
  void refreshSortOrder() {
    _sortedChats.sort(_sortCompare);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduleListVersionUpdate(immediate: true);
    });
  }

  void close() {
    countSub?.cancel();
    _listVersionUpdateTimer?.cancel();
    _redactedModeListener?.cancel();
    _hideContactInfoListener?.cancel();
    _generateFakeAvatarsListener?.cancel();
    _hideAttachmentsListener?.cancel();
  }

  /// Get sorted chats (pin index first, then by latest message date)
  /// Returns the pre-sorted list - sorting is maintained on add/update
  List<Chat> getSortedChats() {
    return _sortedChats;
  }

  /// State-aware sort comparison used by [_findInsertionIndex] and [refreshSortOrder].
  ///
  /// Mirrors [Chat.sort] for pin-index ordering but resolves the latest-message
  /// date from [chatStates] instead of [Chat.dbOnlyLatestMessageDate].  Using the
  /// reactive state avoids a race condition where the DB write for the new message
  /// has not yet completed when the chat list needs to be repositioned.
  int _sortCompare(Chat a, Chat b) {
    final aIsPinned = a.isPinned ?? false;
    final bIsPinned = b.isPinned ?? false;

    // Both pinned with an explicit order → sort by pinIndex.
    if (aIsPinned && bIsPinned && a.pinIndex != null && b.pinIndex != null) {
      return a.pinIndex!.compareTo(b.pinIndex!);
    }

    // b is ordered-pinned, a is not → b comes first.
    if (bIsPinned && b.pinIndex != null && (!aIsPinned || a.pinIndex == null)) return 1;
    // a is ordered-pinned, b is not → a comes first.
    if (aIsPinned && a.pinIndex != null && (!bIsPinned || b.pinIndex == null)) return -1;

    // One pinned, one not.
    if (!aIsPinned && bIsPinned) return 1;
    if (aIsPinned && !bIsPinned) return -1;

    // Both unpinned (or both pinned without an index): sort by most-recent message.
    // Use ChatState latestMessage date to avoid the DB-write race condition.
    final aDate = chatStates[a.guid]?.latestMessage.value?.dateCreated ??
        a.dbOnlyLatestMessageDate ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = chatStates[b.guid]?.latestMessage.value?.dateCreated ??
        b.dbOnlyLatestMessageDate ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return -aDate.compareTo(bDate);
  }

  /// Find the correct insertion index for a chat using binary search
  /// Returns the index where the chat should be inserted to maintain sort order
  int _findInsertionIndex(Chat chat) {
    int left = 0;
    int right = _sortedChats.length;

    while (left < right) {
      final mid = (left + right) ~/ 2;
      final midChat = _sortedChats[mid];
      final comparison = _sortCompare(chat, midChat);

      if (comparison < 0) {
        right = mid;
      } else {
        left = mid + 1;
      }
    }

    return left;
  }

  /// Insert a chat into the sorted list at the correct position
  void _insertChatSorted(Chat chat) {
    final index = _findInsertionIndex(chat);
    _sortedChats.insert(index, chat);
  }

  /// Reposition a chat in the sorted list (used when chat is updated)
  /// If [immediate] is true, UI updates immediately; otherwise debounced (default: true for new messages)
  void _repositionChat(Chat chat, {bool immediate = true}) {
    // Find current position
    final currentIndex = _sortedChats.indexWhere((c) => c.guid == chat.guid);

    if (currentIndex == -1) {
      // Chat not found, just insert it
      _insertChatSorted(chat);
      return;
    }

    // Find where it should be (excluding current position)
    _sortedChats.removeAt(currentIndex);
    final newIndex = _findInsertionIndex(chat);

    // Only reposition if the index actually changed
    if (newIndex != currentIndex) {
      _sortedChats.insert(newIndex, chat);
      // Schedule UI rebuild (immediate for new messages, debounced for batch loads)
      _scheduleListVersionUpdate(immediate: immediate);
    } else {
      // Put it back in the same position
      _sortedChats.insert(currentIndex, chat);
    }
  }

  bool updateChat(Chat updated, {bool override = false, bool immediate = true}) {
    if (headless) return false;

    final state = chatStates[updated.guid];
    if (state != null) {
      final currentLatestMessage = state.latestMessage.value;
      final currentPinIndex = state.pinIndex.value;
      final currentIsPinned = state.isPinned.value;

      // Check if sort-order-relevant fields have changed
      final latestMessageChanged = updated.dbLatestMessage.target?.guid != currentLatestMessage?.guid ||
          updated.dbOnlyLatestMessageDate != currentLatestMessage?.dateCreated;
      final latestMessageTimestampChanged = updated.dbOnlyLatestMessageDate != currentLatestMessage?.dateCreated;
      final pinIndexChanged = updated.pinIndex != currentPinIndex;
      final isPinnedChanged = (updated.isPinned ?? false) != currentIsPinned;
      final sortOrderChanged =
          latestMessageChanged || latestMessageTimestampChanged || pinIndexChanged || isPinnedChanged;

      if (updated != state.chat || override) {
        state.updateFromChat(updated);
      }

      if (sortOrderChanged || override) {
        _repositionChat(state.chat, immediate: immediate);
      }

      return true;
    }

    return false;
  }

  void updateChats(List<Chat> updatedChats, {bool override = false}) {
    for (Chat c in updatedChats) {
      updateChat(c, override: override);
    }
  }

  Future<void> addChat(Chat toAdd, {bool immediate = false}) async {
    if (headless) return;
    // Check if chat already exists
    if (chatStates.containsKey(toAdd.guid)) {
      // Update existing chat instead (debounced during init, immediate for new chats)
      updateChat(toAdd, override: true, immediate: immediate);
      return;
    }

    // Create new ChatState and add to map
    chatStates[toAdd.guid] = ChatState(toAdd);
    _setupChatStateListeners(chatStates[toAdd.guid]!);

    // Insert into sorted list at correct position
    _insertChatSorted(toAdd);

    // _sortedChats isn't reactive; bump the list version so the UI rebuilds.
    _scheduleListVersionUpdate(immediate: immediate);
  }

  void removeChat(Chat toRemove) {
    if (headless) return;
    chatStates.remove(toRemove.guid);
    _sortedChats.removeWhere((c) => c.guid == toRemove.guid);
    _scheduleListVersionUpdate(immediate: true);
  }

  Future<void> markAllAsRead() async {
    try {
      // Phase 1: instant UI update from in-memory state — no DB query needed
      final unreadStates = chatStates.values.where((s) => s.hasUnreadMessage.value).toList();
      final chatIds = <int>[];

      for (final state in unreadStates) {
        state.hasUnreadMessage.value = false;
        final id = state.chat.id;
        if (id != null) {
          chatIds.add(id);
          if (!kIsDesktop && !kIsWeb) {
            MethodChannelSvc.actions.deleteNotification(
              notificationId: id,
              tag: NotificationsService.NEW_MESSAGE_TAG,
            );
          }
        }
      }

      if (chatIds.isEmpty) return;

      // Phase 2: DB write + HTTP calls dispatched to background isolate
      final shouldMark =
          SettingsSvc.settings.enablePrivateAPI.value && SettingsSvc.settings.privateMarkChatAsRead.value;
      await ChatInterface.markAllChatsRead(chatIds: chatIds, shouldMarkOnServer: shouldMark);
    } catch (e, stack) {
      Logger.error("Error marking all chats as read", error: e, trace: stack, tag: "ChatsService");
      showToast("Failed to mark all chats as read!");
    }
  }

  void updateChatPinIndex(int oldIndex, int newIndex) {
    final chatList = getSortedChats();
    final items = List<Chat>.from(chatList.where((c) => (c.pinIndex ?? -1) >= 0));
    items.sort((a, b) => (a.pinIndex ?? 0).compareTo(b.pinIndex ?? 0));

    final item = items[oldIndex];

    // Remove the item at the old index, and re-add it at the newIndex
    // We dynamically subtract 1 from the new index depending on if the newIndex is > the oldIndex
    items.removeAt(oldIndex);
    items.insert(newIndex + (oldIndex < newIndex ? -1 : 0), item);

    // Move the pinIndex for each of the chats, and save the pinIndex in the DB
    items.forEachIndexed((i, e) async {
      e.pinIndex = i;
      await e.saveAsync(updatePinIndex: true);

      // Update chat state
      final state = chatStates[e.guid];
      if (state != null) {
        state.pinIndex.value = i;
      }
    });
  }

  void removePinIndices() {
    final chatList = getSortedChats();
    // Create a snapshot to avoid concurrent modification during iteration
    final pinnedChats = List<Chat>.from(chatList.where((c) => (c.pinIndex ?? -1) >= 0 && c.pinIndex != null));
    for (var element in pinnedChats) {
      element.pinIndex = null;
      element.saveAsync(updatePinIndex: true);

      // Update chat state
      final state = chatStates[element.guid];
      if (state != null) {
        state.pinIndex.value = null;
      }

      // Trigger reposition to re-sort the chat
      _repositionChat(element, immediate: true);
    }
  }

  Future<void> updateShareTargets() async {
    if (Platform.isAndroid) {
      StartupTasks.waitForUI().then((_) async {
        // Create a snapshot to avoid concurrent modification during iteration
        final chatList = getSortedChats();
        final chatSnapshot = chatList.where((e) => !isNullOrEmpty(e.displayName ?? e.chatIdentifier)).take(4).toList();
        for (Chat c in chatSnapshot) {
          await MethodChannelSvc.actions.pushShareTarget(
            title: c.getTitle(),
            guid: c.guid,
            icon: await avatarAsBytes(chat: c, quality: 256),
          );
        }
      });
    }
  }

  /// Fetch chat information from the server
  Future<Chat?> fetchChat(String chatGuid, {withParticipants = true, withLastMessage = false}) async {
    Logger.info("Fetching full chat metadata from server.", tag: "Fetch-Chat");

    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await HttpSvc.chat.fetchOne(chatGuid, withQuery: withQuery.join(",")).catchError((err, stack) {
      Logger.error("Failed to fetch chat metadata!", error: err, trace: stack, tag: "Fetch-Chat");
      return Response(requestOptions: RequestOptions(path: ''));
    });

    if (response.statusCode == 200 && response.data["data"] != null) {
      Map<String, dynamic> chatData = response.data["data"];

      Logger.info("Got updated chat metadata from server. Saving.", tag: "Fetch-Chat");
      return (await ChatInterface.bulkSyncChats(chatsData: [chatData])).chats.first;
    }

    return null;
  }

  Future<List<Chat>> getChats({
    bool withParticipants = false,
    bool withLastMessage = false,
    int offset = 0,
    int limit = 100,
  }) async {
    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await HttpSvc.chat
        .query(withQuery: withQuery, offset: offset, limit: limit, sort: withLastMessage ? "lastmessage" : null)
        .catchError((err, stack) {
      Logger.error("Failed to fetch chats!", error: err, trace: stack, tag: "Fetch-Chat");
      return Response(requestOptions: RequestOptions(path: ''));
    });

    // parse chats from the response
    final chats = <Chat>[];
    for (var item in response.data["data"]) {
      try {
        var chat = Chat.fromMap(item);
        chats.add(chat);
      } catch (ex) {
        chats.add(Chat(guid: "ERROR", displayName: item.toString()));
      }
    }

    return chats;
  }

  Future<List<dynamic>> getMessages(String guid,
      {bool withAttachment = true,
      bool withHandle = true,
      int offset = 0,
      int limit = 25,
      String sort = "DESC",
      int? after,
      int? before}) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>["message.attributedBody", "message.messageSummaryInfo", "message.payloadData"];
    if (withAttachment) withQuery.add("attachment");
    if (withHandle) withQuery.add("handle");

    HttpSvc.chat
        .getMessages(guid,
            withQuery: withQuery.join(","), offset: offset, limit: limit, sort: sort, after: after, before: before)
        .then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err.toString();
      }
      if (!completer.isCompleted) completer.completeError(error);
    });

    return completer.future;
  }

  // ========== Chat Lifecycle Management Methods (migrated from ChatManager) ==========

  /// Set all chats to inactive synchronously
  void setAllInactiveSync({bool save = true, bool clearActive = true}) {
    Logger.debug('Setting chats to inactive (save: $save, clearActive: $clearActive)');

    String? skip;
    if (clearActive) {
      activeChat?.controller = null;
      activeChat = null;
    } else {
      skip = activeChat?.chat.guid;
    }

    chatStates.forEach((key, state) {
      if (key == skip) return;
      state.updateActiveInternal(false);
      state.updateAliveInternal(false);
    });

    if (save) {
      unawaited(PrefsSvc.messaging.clearLastOpenedChat());
    }
  }

  /// Set all chats to inactive asynchronously
  Future<void> setAllInactive() async {
    Logger.debug('Setting all chats to inactive');
    await PrefsSvc.messaging.clearLastOpenedChat();
    setAllInactiveSync(save: false);
  }

  /// Set a chat as the active chat
  Future<void> setActiveChat(Chat chat, {bool clearNotifications = true}) async {
    await PrefsSvc.messaging.setLastOpenedChat(chat.guid);
    setActiveChatSync(chat, clearNotifications: clearNotifications, save: false);
  }

  /// Set a chat as the active chat synchronously
  void setActiveChatSync(Chat chat, {bool clearNotifications = true, bool save = true}) {
    Logger.debug('Setting active chat to ${chat.guid} (${chat.displayName})');

    // Get or create the chat state
    final chatState = getOrCreateChatState(chat);

    // Set this chat as active
    activeChat = chatState;
    chatState.updateActiveAndAliveInternal(true);

    // Clear all other chats to inactive
    setAllInactiveSync(save: false, clearActive: false);

    if (clearNotifications) {
      // Defer the observable update to avoid updating during build phase
      Future.microtask(() {
        setChatHasUnread(chatState.chat, false, force: true);
      });
    }

    if (save) {
      unawaited(PrefsSvc.messaging.setLastOpenedChat(chat.guid));
    }
  }

  /// Set the active chat to dead (not alive)
  void setActiveToDead() {
    Logger.debug('Setting active chat to dead: ${activeChat?.chat.guid}');
    activeChat?.updateAliveInternal(false);
  }

  /// Set the active chat to alive
  void setActiveToAlive() {
    Logger.info('Setting active chat to alive: ${activeChat?.chat.guid}');
    activeChat?.updateAliveInternal(true);
  }

  /// Check if a chat is currently active (both active and alive)
  bool isChatActive(String guid) {
    final state = getChatState(guid);
    return state?.isChatActive ?? false;
  }

  /// Get the chat controller for a specific chat
  ChatState? getChatController(String guid) {
    return getChatState(guid);
  }

  // ========== End Chat Lifecycle Management ==========

  // ========== Chat Operations with Service Orchestration ==========

  /// Get chat count
  int? getChatCount() {
    return Database.chats.count();
  }

  /// Delete a chat with full UI cleanup and service state management.
  /// Set [deleteHandles] to true to also remove the chat's participant handles.
  Future<void> deleteChat(Chat chat, {bool deleteHandles = false}) async {
    if (kIsWeb) return;

    // Handle active chat cleanup
    if (activeChat?.chat.guid == chat.guid) {
      NavigationSvc.closeAllConversationView(Get.context!);
      await setAllInactive();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Collect handle IDs before deleting the chat (handles are lazy-loaded via ToMany).
    // Only include handles that are not shared with any other chat — if a handle
    // participates in multiple chats, removing it would break those other chats.
    List<int> handleIds = <int>[];
    if (deleteHandles) {
      final otherChats = allChats.where((c) => c.guid != chat.guid).toList();
      final otherHandleIds = otherChats.expand((c) => c.handles).map((h) => h.id).whereType<int>().toSet();
      handleIds = chat.handles.map((e) => e.id).whereType<int>().where((id) => !otherHandleIds.contains(id)).toList();
    }

    // Perform the actual DB deletion
    List<Message> messages = Chat.getMessages(chat);
    await ChatInterface.deleteChat(
      chatId: chat.id!,
      messageIds: messages.map((e) => e.id!).toList(),
      handleIds: handleIds,
    );

    // Remove from service state
    removeChat(chat);
  }

  /// Performs a full messaging reset: wipes all Messages, Attachments, Chats,
  /// Handles, and Contacts (ContactV2) from the database, deletes all
  /// associated files from disk, and flushes every in-memory service cache
  /// tied to that data.
  ///
  /// Does NOT touch Settings, themes, FCM data, or scheduled messages. Does
  /// NOT show any confirmation UI — callers must confirm with the user
  /// before invoking this.
  Future<void> deleteAllMessagingData() async {
    if (kIsWeb) return;

    // Close any active conversation view first (mirrors deleteChat() above).
    if (activeChat != null) {
      NavigationSvc.closeAllConversationView(Get.context!);
      setAllInactive();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Capture currently-registered per-chat MessagesService tags before
    // init() below clears chatStates — it's our only enumeration source.
    final chatGuids = chatStates.keys.toList();

    Database.resetMessagingData();
    await _deleteMessagingFiles();

    for (final guid in chatGuids) {
      maybeFindMessagesSvc(guid)?.close(force: true);
    }
    AttachmentsSvc.clearVideoThumbnailCache();
    HandleSvc.reset();

    // Use init() rather than reset() so the empty-database case is handled
    // correctly: reset() alone leaves loadedFirstChatBatch=false forever since
    // there are no chats left to trigger the "batch loaded" codepath, which
    // left the conversation list stuck on "Loading chats..." indefinitely.
    // init(force: true) calls reset() internally and then, for a zero-chat
    // database, sets loadedFirstChatBatch=true and re-initializes DB watchers
    // (same codepath FullSyncManager.complete() uses after a full resync).
    await init(force: true);
  }

  /// Deletes on-disk messaging data: attachments (originals/thumbnails/live-photo
  /// .mov), per-chat avatars, per-chat custom backgrounds, per-message balloon
  /// bundle directories, cached URL preview images, and cached contact avatars.
  Future<void> _deleteMessagingFiles() async {
    final paths = [
      FilesystemSvc.attachmentsPath,
      FilesystemSvc.avatarsPath,
      FilesystemSvc.customBackgroundsPath,
      FilesystemSvc.messagesPath,
      FilesystemSvc.urlPreviewsPath,
      FilesystemSvc.contactAvatarsPath,
    ];
    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  /// Soft delete a chat with full UI cleanup and service state management
  Future<void> softDeleteChat(Chat chat) async {
    if (kIsWeb) return;

    // Handle active chat cleanup
    if (activeChat?.chat.guid == chat.guid) {
      NavigationSvc.closeAllConversationView(Get.context!);
      await setAllInactive();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Perform the actual DB soft delete
    await ChatInterface.softDeleteChat(chatData: chat.toMap());
    chat.clearTranscript();

    // Propagate dateDeleted to ChatState before removing it so any live
    // listeners (e.g. ConversationTileController) can react reactively.
    getChatState(chat.guid)?.updateDateDeletedInternal(DateTime.now().toUtc());

    // Remove from service state
    removeChat(chat);
  }

  /// Undelete a chat
  Future<void> unDeleteChat(Chat chat) async {
    if (kIsWeb) return;
    await ChatInterface.unDeleteChat(chatData: chat.toMap());
  }

  /// Toggle chat pin status with service updates
  Future<Chat> _toggleChatPin(Chat chat, bool isPinned) async {
    // Perform DB operation
    await chat.togglePinAsync(isPinned);

    // Update service state
    updateChat(chat);

    // Pin status changes the filtered list (pinned vs non-pinned), so we must
    // explicitly trigger a list version update so all conversation list views re-filter.
    _scheduleListVersionUpdate(immediate: true);

    return chat;
  }

  /// Toggle chat archive status with service updates
  Future<Chat> _toggleChatArchive(Chat chat, bool isArchived) async {
    // Perform DB operation
    await chat.toggleArchivedAsync(isArchived);

    // Update service state
    updateChat(chat);

    // Archive status changes the filtered list (not sort order), so we must
    // explicitly trigger a list version update so all conversation list views re-filter.
    _scheduleListVersionUpdate(immediate: true);

    return chat;
  }

  /// Toggle chat unread status with active chat awareness
  Future<Chat> _toggleChatHasUnread(Chat chat, bool hasUnread,
      {bool force = false, bool clearLocalNotifications = true, bool privateMark = true}) async {
    // Check if chat is active and adjust behavior
    final isActive = isChatActive(chat.guid);

    if (isActive && hasUnread && !force) {
      // Don't mark as unread if chat is active (unless forced)
      return chat;
    }

    // Determine actual parameters based on active status
    bool actualClearNotifications = clearLocalNotifications;
    bool actualPrivateMark = privateMark;
    bool actualForce = force;

    if (isActive) {
      // Force mark as read if chat is active
      actualForce = true;
      actualPrivateMark = true;
    }

    // Perform DB operation with adjusted parameters
    await chat.toggleHasUnreadAsync(hasUnread,
        force: actualForce, clearLocalNotifications: actualClearNotifications, privateMark: actualPrivateMark);

    // Update service state
    updateChat(chat);

    return chat;
  }

  /// Add message to chat with full service orchestration
  Future<MessageSaveResult> addMessageToChat(Chat chat, Message message,
      {bool changeUnreadStatus = true, bool checkForMessageText = true, bool clearNotificationsIfFromMe = true}) async {
    // Perform the DB operation to add the message
    final result = await chat.addMessage(message,
        changeUnreadStatus: false, // We'll handle this with service awareness
        checkForMessageText: checkForMessageText,
        clearNotificationsIfFromMe: clearNotificationsIfFromMe);

    final isNewer = result.isNewer;

    // Handle service-level operations if this is a newer message
    if (isNewer) {
      // Add chat to service if it was previously deleted
      if (chat.dateDeleted != null) {
        await addChat(chat);
      } else {
        // Just update the existing chat in service
        updateChat(chat);
      }
    }

    // Handle unread status with active chat awareness
    if (checkForMessageText && changeUnreadStatus && isNewer) {
      final isActive = isChatActive(chat.guid);

      if (message.isFromMe! || isActive) {
        // Mark as read if from me or chat is active
        await _toggleChatHasUnread(chat, false,
            clearLocalNotifications: clearNotificationsIfFromMe, force: isActive, privateMark: isActive);
      } else {
        // Mark as unread if not from me and chat is not active
        await _toggleChatHasUnread(chat, true, privateMark: false);
      }
    }

    return result;
  }

  // ========== Chat Property Setters ==========
  // These update both the Chat model (DB) and ChatState (UI reactivity)

  /// Set chat pinned status
  Future<void> setChatPinned(Chat chat, bool value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.isPinned.value == value) return;

    // Update DB
    await _toggleChatPin(chat, value);

    // Update state if available
    state?.updateIsPinnedInternal(value);
  }

  /// Set chat pin index
  Future<void> setChatPinIndex(Chat chat, int? value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.pinIndex.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.pinIndex = value;
    await chatToUpdate.saveAsync(updatePinIndex: true);

    // Update state if available
    state?.updatePinIndexInternal(value);
  }

  /// Set chat unread status
  Future<void> setChatHasUnread(
    Chat chat,
    bool value, {
    bool force = false,
    bool clearLocalNotifications = true,
    bool privateMark = true,
  }) async {
    final state = getChatState(chat.guid);

    if (state != null && state.hasUnreadMessage.value == value && !force) return;

    // Update DB with active chat awareness
    await _toggleChatHasUnread(chat, value,
        force: force, clearLocalNotifications: clearLocalNotifications, privateMark: privateMark);

    // Update state if available
    state?.updateHasUnreadInternal(value);
  }

  /// Set chat muted status
  Future<void> setChatMuted(Chat chat, bool isMuted) async {
    final state = getChatState(chat.guid);

    final newMuteType = isMuted ? "mute" : null;
    if (state != null && state.muteType.value == newMuteType) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    await chatToUpdate.toggleMuteAsync(isMuted);

    // Update state if available
    state?.updateMutedInternal(newMuteType, null);
  }

  /// Set chat archived status
  Future<void> setChatArchived(Chat chat, bool value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.isArchived.value == value) return;

    // Update DB
    await _toggleChatArchive(chat, value);

    // Update state if available
    state?.updateArchivedInternal(value);
  }

  /// Set chat auto send read receipts
  Future<void> setChatAutoSendReadReceipts(Chat chat, bool? value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.autoSendReadReceipts.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    await chatToUpdate.toggleAutoReadAsync(value);

    // Update state if available
    state?.updateAutoSendReadReceiptsInternal(value);
  }

  /// Set chat auto send typing indicators
  Future<void> setChatAutoSendTypingIndicators(Chat chat, bool? value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.autoSendTypingIndicators.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    await chatToUpdate.toggleAutoTypeAsync(value);

    // Update state if available
    state?.updateAutoSendTypingIndicatorsInternal(value);
  }

  /// Set chat lock name status
  Future<void> setChatLockName(Chat chat, bool value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.lockChatName.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.lockChatName = value;
    await chatToUpdate.saveAsync(updateLockChatName: true);

    // Update state if available
    state?.updateLockChatNameInternal(value);
  }

  /// Set chat lock icon status
  Future<void> setChatLockIcon(Chat chat, bool value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.lockChatIcon.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.lockChatIcon = value;
    await chatToUpdate.saveAsync(updateLockChatIcon: true);

    // Update state if available
    state?.updateLockChatIconInternal(value);
  }

  /// Set chat display name
  Future<void> setChatDisplayName(Chat chat, String? value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.displayName.value == value) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.displayName = value;

    // Update state eagerly so the UI reflects the change immediately
    state?.updateDisplayNameInternal(value);

    await chatToUpdate.saveAsync(updateDisplayName: true);
  }

  /// Set chat custom avatar path
  Future<void> setChatCustomAvatarPath(Chat chat, String? value) async {
    final state = getChatState(chat.guid);
    final chatToUpdate = state?.chat ?? chat;
    final oldPath = chatToUpdate.customAvatarPath;

    if (oldPath == value) return;

    chatToUpdate.customAvatarPath = value;
    await chatToUpdate.saveAsync(updateCustomAvatarPath: true);

    // Update state if available
    state?.updateCustomAvatarPathInternal(value);

    if (!kIsWeb && oldPath != null && oldPath != value) {
      try {
        final file = File(oldPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Set chat custom background path
  Future<void> setChatCustomBackgroundPath(Chat chat, String? value) async {
    final state = getChatState(chat.guid);
    final resolvedPath = value ?? FilesystemSvc.getExistingChatBackgroundPath(chat.guid);
    final oldPath = state?.customBackgroundPath.value ?? FilesystemSvc.getExistingChatBackgroundPath(chat.guid);
    if (state != null && state.customBackgroundPath.value == resolvedPath) return;

    if (oldPath != null && oldPath != resolvedPath) {
      ThemesService.clearAdaptiveThemeCache(oldPath);
    }

    final lightThemeName = state?.customThemeLight.value ?? chat.customThemeLight;
    final darkThemeName = state?.customThemeDark.value ?? chat.customThemeDark;
    final usesAdaptiveBackgroundTheme =
        (lightThemeName != null && ThemesService.isAdaptiveBackgroundThemeName(lightThemeName)) ||
            (darkThemeName != null && ThemesService.isAdaptiveBackgroundThemeName(darkThemeName));
    if (resolvedPath != null && usesAdaptiveBackgroundTheme) {
      await ThemesService.upsertAdaptiveBackgroundThemesFromImage(resolvedPath, scopeKey: chat.guid);
    }

    state?.updateCustomBackgroundPathInternal(resolvedPath);
  }

  /// Set the custom light and dark themes for a specific chat.
  Future<void> setChatCustomThemes(
    Chat chat, {
    String? lightTheme,
    String? darkTheme,
  }) async {
    final state = getChatState(chat.guid);
    final changed =
        state == null || state.customThemeLight.value != lightTheme || state.customThemeDark.value != darkTheme;
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.customThemeLight = lightTheme;
    chatToUpdate.customThemeDark = darkTheme;
    await chatToUpdate.saveAsync(updateCustomThemes: true);

    state?.updateCustomThemeLightInternal(lightTheme);
    state?.updateCustomThemeDarkInternal(darkTheme);
    if (!changed) {
      state.bumpThemeVersion();
    }
  }

  /// Set chat latest message
  Future<void> setChatLatestMessage(Chat chat, Message value) async {
    final state = getChatState(chat.guid);
    if (state == null) return;

    // Update Chat model (use state.chat if available, otherwise use passed in chat)
    final chatToUpdate = state.chat;

    // Only save in the DB if it's not already the same latest message.
    if (state.latestMessage.value?.guid != value.guid) {
      chatToUpdate.setLatestMessage(value);
    }

    // Update state if available
    state.updateLatestMessageInternal(value);
  }

  /// Update chat latest message and subtitle in response to a new or updated message.
  /// Called by IncomingMessageHandler and SyncService to keep ChatState as the single
  /// source of truth for the conversation tile subtitle.
  ///
  /// Only moves the latest-message pointer forward in time — sync can report an
  /// older delta message as a chat's latest, which would rewind its sort order.
  /// The 2s tolerance allows a temp->real GUID swap. [allowOlder] opts out for the
  /// post-deletion recompute, which must fall back to an older surviving message.
  void updateChatLatestMessage(String chatGuid, Message message, {bool allowOlder = false}) {
    final state = getChatState(chatGuid);
    if (state == null) return;

    if (!allowOlder) {
      final current = state.latestMessage.value;
      final currentDate = current?.dateCreated;
      final incomingDate = message.dateCreated;
      const staleTolerance = Duration(seconds: 2);
      if (current != null &&
          current.guid != message.guid &&
          currentDate != null &&
          currentDate.millisecondsSinceEpoch > 0 &&
          incomingDate != null &&
          incomingDate.isBefore(currentDate.subtract(staleTolerance))) {
        return;
      }
    }

    state.updateLatestMessageInternal(message);
    final redacted = SettingsSvc.settings.redactedMode.value;
    final hideContactInfo = redacted && SettingsSvc.settings.hideContactInfo.value;
    final hideMessageContent = redacted && SettingsSvc.settings.hideMessageContent.value;
    state.updateSubtitleInternal(
        message.getNotificationText(hideContactInfo: hideContactInfo, hideMessageContent: hideMessageContent));
    state.chat.setLatestMessage(message);
    _repositionChat(state.chat, immediate: true);
  }

  /// Set chat text field text
  /// ChatState is updated synchronously and is the source of truth for the UI.
  /// The DB write is fire-and-forget so callers never need to await this.
  Future<void> setChatTextFieldText(Chat chat, String? value) async {
    final state = getChatState(chat.guid);

    if (state != null && state.textFieldText.value == value) return;

    // Update ChatState first — this is the source of truth for the text field UI.
    state?.updateTextFieldTextInternal(value);

    // Persist to the chat model and DB asynchronously (fire-and-forget).
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.textFieldText = value;
    unawaited(chatToUpdate.saveAsync(updateTextFieldText: true));
  }

  /// Set chat text field attachments
  /// ChatState is updated synchronously and is the source of truth for the UI.
  /// The DB write is fire-and-forget so callers never need to await this.
  Future<void> setChatTextFieldAttachments(Chat chat, List<String> value) async {
    final state = getChatState(chat.guid);

    if (state != null && listEquals(state.textFieldAttachments, value)) return;

    // Update ChatState first — this is the source of truth for the text field UI.
    state?.updateTextFieldAttachmentsInternal(value);

    // Persist to the chat model and DB asynchronously (fire-and-forget).
    final chatToUpdate = state?.chat ?? chat;
    chatToUpdate.textFieldAttachments = value;
    unawaited(chatToUpdate.saveAsync(updateTextFieldAttachments: true));
  }

  // ========== End Chat Property Setters ==========

  // ========== End Chat Operations ==========

  void reset({bool reinitWatchers = false}) {
    currentCount = 0;
    hasChats.value = false;
    _activeChat = null;
    chatStates.clear();
    _sortedChats.clear();
    loadedAllChats = Completer();
    loadedFirstChatBatch.value = false;
    webCachedHandles.clear();

    countSub?.cancel();
    if (reinitWatchers) {
      initDbWatchers();
    }
  }
}
