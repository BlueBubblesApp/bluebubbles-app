import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:dio/dio.dart' as dio;

class IncrementalSyncManager extends SyncManager {
  final tag = 'IncrementalSyncManager';

  // When the sync started
  late int syncStartedAt;

  // The start timestamp for the sync range
  int? startTimestamp;

  // The end timestamp for the sync range
  int? endTimestamp;

  // The start row ID for the sync range
  int? startRowId;

  // The end row ID for the sync range
  int? endRowId;

  // The last row ID we synced
  int? lastSyncedRowId;

  // The last timestamp we synced
  int? lastSyncedTimestamp;

  // The size for each page to fetch from the API
  int batchSize;

  // The total number of messages we synced
  int messagesSynced = 0;

  // A cache of all the chats we've synced
  Map<String, Chat> syncedChats = {};

  // Tracks the DB ID of the latest (highest dateCreated) message synced per chat.
  // Used by SyncActions to return message IDs instead of chat IDs so the interface
  // can hydrate Message objects and update ChatState subtitles.
  Map<String, int> latestMessageIdPerChat = {};

  // Tracks the latest group-photo-change message per chat across all sync pages.
  // isGroupPhotoChanged (groupActionType == 1) → photo changed.
  // isGroupPhotoRemoved (groupActionType == 2) → photo removed.
  // We keep only the latest (highest dateCreated) so that if multiple photo
  // changes arrive in the same sync the most-recent action wins.
  Map<String, ({DateTime? dateCreated, int groupActionType})> latestPhotoChangePerChat = {};

  // A flag telling the "complete" function to save the timestamp/row ID markers.
  bool saveMarker;

  // A callback to call when the sync is complete
  Function? onComplete;

  // The default extra fields to fetch with the messages
  List<String> defaultWithQuery = [
    "chats",
    "chats.participants",
    "attachments",
    "handle",
    "attributedBody",
    "messageSummaryInfo",
    "payloadData"
  ];

  IncrementalSyncManager(
      {this.startRowId,
      this.endRowId,
      this.startTimestamp,
      this.endTimestamp,
      this.batchSize = 1000,
      this.saveMarker = false,
      this.onComplete,
      bool saveLogs = false})
      : super("Incremental", saveLogs: saveLogs) {
    if (startRowId == null && startTimestamp == null) {
      throw Exception("Must provide either a startRowId or startTimestamp");
    }
  }

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    syncStartedAt = DateTime.now().millisecondsSinceEpoch;
    super.start();
    addToOutput(
        "Starting incremental sync (startTimestamp: $startTimestamp; endTimestamp: $endTimestamp; startRowId: $startRowId; endRowId: $endRowId)");

    // General flow of the sync:
    // 0: Hit API endpoint to check for updated messages
    // 1: If no new updated messages, complete the sync
    // 2: If there are new messages, fetch them by page
    // 3: Enumerate the chats into cache
    // 4: Sync the chats
    // 5: Merge synced chats back into cache
    // 6: For each chat, bulk sync the messages

    // Check the server version and sync differently based on the version.
    // This is due to bugs in certain server versions as well as new features
    // in server versions to make the sync more efficient.
    final serverDetails = SettingsSvc.serverDetails;

    try {
      // If we've don't have a startRowId (null or 0), then sync using timestamps
      if (serverDetails.supportsRowIdSync && (startRowId ?? 0) > 0) {
        addToOutput("Syncing with server version >= 1.6.0");
        await startMin_1_6_0();
      } else if (serverDetails.supportsImprovedSync) {
        addToOutput("Syncing with server version >= 1.2.0");
        await startMin_1_2_0();
      } else {
        addToOutput("Syncing with server version < 1.2.0");
        await startPre_1_2_0();
      }

      await complete();
    } catch (ex) {
      completeWithError(ex.toString());
    }

    return completer!.future;
  }

  Future<void> startMin_1_6_0() async {
    if (startRowId == null) {
      throw Exception("startRowId cannot be null for server versions >= 1.6.0");
    }

    // Query the API for messages.
    // This endpoint will return the total messages that match the query in v1.6.0+
    addToOutput('Fetching messages...');
    dio.Response<dynamic> messagesRes = await HttpSvc.message.query(
      where: buildRowIdWhereArgs(startRowId!, endRowId),
      limit: batchSize,
      offset: 0,
      withQuery: defaultWithQuery,
    );

    // If no new updated messages, complete the sync
    int total = messagesRes.data['metadata']['total'];
    addToOutput('Found $total message(s) to sync...');
    if (total == 0) return;

    // Sync the page we just fetched
    await syncMessages(messagesRes.data['data'], total);

    // Sync subsequent pages
    if (total > batchSize) {
      await syncMessagePages(total, startPage: 1, useRowId: true);
    }
  }

  Future<void> startMin_1_2_0() async {
    if (startTimestamp == null) {
      throw Exception("startTimestamp cannot be null for server versions >= 1.2.0 and < 1.6.0");
    }

    // Hit API endpoint to check for updated messages
    dio.Response<dynamic> uMessageCountRes = await HttpSvc.message.getCount(
      after: DateTime.fromMillisecondsSinceEpoch(startTimestamp!),
    );

    // If no new updated messages, complete the sync
    int total = uMessageCountRes.data['data']['total'];
    addToOutput('Found $total message(s) to sync...');
    await syncMessagePages(total);
  }

  Future<void> startPre_1_2_0() async {
    if (startTimestamp == null) {
      throw Exception("startTimestamp cannot be null for server versions < 1.2.0");
    }

    // In < 1.2.0, the message query API endpoint was a bit broken.
    // It would not include messages with the text being null. As such,
    // the count can be slightly lower than the real count. To account
    // for this, we just multiple the count by 2. This way, even if all
    // the messages have a null text, we can still account for them when we fetch.

    // Hit API endpoint to check for updated messages
    dio.Response<dynamic> uMessageCountRes = await HttpSvc.message.getCount(
      after: DateTime.fromMillisecondsSinceEpoch(startTimestamp!),
    );

    // If no new updated messages, complete the sync
    int count = uMessageCountRes.data['data']['total'];

    // Manually set/modify the count if we are on a bugged server
    // If count is 0, fetch 1 page.
    // If > 0, fetch count * 2 to account for any possible null texts
    if (count == 0) {
      count = batchSize;
    } else {
      count = count * 2;
    }

    addToOutput('Found $count message(s) to sync...');
    await syncMessagePages(count);
  }

  Future<void> syncMessagePages(int total, {int startPage = 0, bool useRowId = false}) async {
    if (total == 0) return;

    int pages = (total / batchSize).ceil();

    // If there are new messages, fetch them by page
    for (var i = startPage; i < pages; i++) {
      addToOutput('Fetching page ${i + 1} of $pages...');
      dio.Response<dynamic> messagesResponse;

      // Fetch the pages differently depending on the parameters.
      if (useRowId) {
        messagesResponse = await HttpSvc.message.query(
            where: buildRowIdWhereArgs(startRowId!, endRowId),
            offset: i * batchSize,
            limit: batchSize,
            withQuery: defaultWithQuery);
      } else {
        messagesResponse = await HttpSvc.message.query(
            after: startTimestamp,
            before: endTimestamp,
            offset: i * batchSize,
            limit: batchSize,
            withQuery: defaultWithQuery);
      }

      int messageCount = messagesResponse.data['data'].length;
      addToOutput('Page ${i + 1} returned $messageCount message(s)...', level: LogLevel.DEBUG);

      if (messageCount == 0) break;
      await syncMessages(messagesResponse.data['data'], total);
    }
  }

  Future<void> syncMessages(List<dynamic> messages, int total) async {
    // If we don't get any messages return false (no more messages)
    if (messages.isEmpty) return;

    // Enumerate the chats into cache
    Map<String, Chat> chatCache = {};
    Map<String, List<Map<String, dynamic>>> messagesToSync = {};

    // Tracks the latest group-name-change per chat, keyed by chat GUID.
    // We keep only the latest (highest dateCreated) so that if multiple name
    // changes arrive in the same batch the most-recent one wins.
    final Map<String, ({DateTime? dateCreated, String? groupTitle})> latestNameChangePerChat = {};

    for (var msgData in messages) {
      for (var chat in msgData['chats']) {
        if (!chatCache.containsKey(chat['guid'])) {
          chatCache[chat['guid']] = Chat.fromMap(chat);
        }

        if (!messagesToSync.containsKey(chat['guid'])) {
          messagesToSync[chat['guid']] = [];
        }

        // Create a Message object temporarily for local tracking and group event detection.
        // The raw msgData map (not the Message object) is passed to the sync action so
        // that attachment data from the server is preserved.
        Message msg = Message.fromMap(msgData);
        if (msg.error > 0) msg.errorMessage = serverErrorMessage(msg.error);
        messagesToSync[chat['guid']]!.add(msgData as Map<String, dynamic>);

        // Save the last synced ROWID
        if (msg.originalROWID != null && (lastSyncedRowId == null || msg.originalROWID! > lastSyncedRowId!)) {
          lastSyncedRowId = msg.originalROWID;
        }

        // Save the last synced timestamp
        if (msg.dateCreated != null && lastSyncedTimestamp == null ||
            msg.dateCreated!.millisecondsSinceEpoch > lastSyncedTimestamp!) {
          lastSyncedTimestamp = msg.dateCreated!.millisecondsSinceEpoch;
        }

        // Track the latest group-name-change message per chat.
        if (msg.isNameChange) {
          final chatGuid = chat['guid'] as String;
          final existing = latestNameChangePerChat[chatGuid];
          final msgDate = msg.dateCreated;
          if (existing == null ||
              (msgDate != null && existing.dateCreated != null && msgDate.isAfter(existing.dateCreated!))) {
            latestNameChangePerChat[chatGuid] = (dateCreated: msgDate, groupTitle: msg.groupTitle);
          }
        }

        // Track the latest group-photo-change message per chat.
        if (msg.isGroupPhotoEvent) {
          final chatGuid = chat['guid'] as String;
          final existing = latestPhotoChangePerChat[chatGuid];
          final msgDate = msg.dateCreated;
          if (existing == null ||
              (msgDate != null && existing.dateCreated != null && msgDate.isAfter(existing.dateCreated!))) {
            latestPhotoChangePerChat[chatGuid] = (dateCreated: msgDate, groupActionType: msg.groupActionType ?? 0);
          }
        }
      }
    }

    // Check which chats need full participant data from the server
    // This is needed because message API responses don't include participants for efficiency
    List<String> chatsNeedingParticipants = [];
    for (var chatGuid in chatCache.keys) {
      final existingChat = Chat.findOne(guid: chatGuid);
      // If chat doesn't exist or has no handles, we need to fetch participants
      if (existingChat == null || existingChat.handles.isEmpty) {
        chatsNeedingParticipants.add(chatGuid);
      }
    }

    // Fetch full chat data with participants for chats that need it
    if (chatsNeedingParticipants.isNotEmpty) {
      addToOutput('Fetching participant data for ${chatsNeedingParticipants.length} chat(s)...', level: LogLevel.DEBUG);
      for (var chatGuid in chatsNeedingParticipants) {
        try {
          final response = await HttpSvc.chat.fetchOne(chatGuid, withQuery: "participants");
          if (response.statusCode == 200 && response.data["data"] != null) {
            final chatData = response.data["data"];
            // Update the cache with the full chat data from the server
            chatCache[chatGuid] = Chat.fromMap(chatData);
          }
        } catch (ex) {
          Logger.warn("Failed to fetch participants for chat $chatGuid", error: ex, tag: tag);
        }
      }
    }

    // Apply the authoritative group name from group-name-change messages.
    // groupTitle on the message IS the name the chat was changed to, so it is
    // more reliable than whatever displayName happened to be embedded in the
    // first message's chat object.  We apply it here (after any participant
    // fetches that may have replaced chatCache entries) so that bulkSyncChats
    // receives the correct displayName and writes it to the DB.
    for (final entry in latestNameChangePerChat.entries) {
      final chat = chatCache[entry.key];
      if (chat != null) {
        chat.displayName = entry.value.groupTitle;
      }
    }

    // Sync the chats
    List<Chat> theChats = await Chat.bulkSyncChats(chatCache.values.toList());

    // Merge synced chats back into cache
    for (var chat in theChats) {
      if (!chatCache.containsKey(chat.guid)) continue;
      chatCache[chat.guid] = chat;
    }

    // Add everything to the global cache
    syncedChats.addAll(chatCache);

    // For each chat, bulk sync the messages
    final pageMessageIds = <int>[];
    final pageLatestMessageIdPerChat = <String, int>{};

    for (var item in messagesToSync.entries) {
      Chat? theChat = chatCache[item.key];
      if (theChat == null || item.value.isEmpty) continue;

      final syncResult = await SyncInterface.bulkSyncData(
        chatData: theChat.toMap(),
        messagesData: item.value,
      );
      messagesSynced += syncResult.messages.length;
      setProgress(messagesSynced, total);

      // Track the latest message per chat (highest dateCreated with a valid DB id)
      // so the action layer can return message IDs instead of chat IDs.
      final latest = syncResult.messages
          .where((m) => m.id != null && m.dateCreated != null)
          .fold<Message?>(null, (prev, m) => prev == null || m.dateCreated!.isAfter(prev.dateCreated!) ? m : prev);
      if (latest != null) {
        latestMessageIdPerChat[item.key] = latest.id!;
      }

      // Collect per-page data for the progressive UI update event.
      for (final m in syncResult.messages) {
        if (m.id != null) pageMessageIds.add(m.id!);
      }
      if (latest != null) {
        pageLatestMessageIdPerChat[item.key] = latest.id!;
      }
    }

    // Emit a per-page event so the main thread can update the UI incrementally
    // without waiting for all pages to finish.
    if (isIsolate && pageMessageIds.isNotEmpty) {
      IsolateEventEmitter.emit(IsolateEvent.incrementalSyncPageComplete, {
        'messageIds': pageMessageIds,
        'latestMessageIdPerChat': pageLatestMessageIdPerChat,
      });
    }
  }

  List<Map<String, dynamic>> buildRowIdWhereArgs(int startRowId, int? endRowId) {
    List<Map<String, dynamic>> whereArgs = [
      {
        'statement': 'message.ROWID > :startRowId',
        'args': {'startRowId': startRowId}
      }
    ];

    if (endRowId != null && endRowId > startRowId) {
      whereArgs.add({
        'statement': 'message.ROWID <= :endRowId',
        'args': {'endRowId': endRowId}
      });
    }

    return whereArgs;
  }

  @override
  Future<void> complete() async {
    // Once we have added everything, save the last sync date
    if (saveMarker) {
      addToOutput("Saving last sync markers...");

      // If we have a start timestamp, use the time that our sync started.
      // Otherwise, use the last timestamp we got from the API
      final toSave = ['lastIncrementalSync'];
      if (startTimestamp != null) {
        SettingsSvc.settings.lastIncrementalSync.value = syncStartedAt;
      } else if (lastSyncedTimestamp != null) {
        SettingsSvc.settings.lastIncrementalSync.value = lastSyncedTimestamp!;
      }

      // The lastRowId should always get set, even when sycing using timestamps
      if (lastSyncedRowId != null) {
        SettingsSvc.settings.lastIncrementalSyncRowId.value = lastSyncedRowId!;
        toSave.add('lastIncrementalSyncRowId');
      }

      await SettingsSvc.settings.saveManyAsync(toSave);
    }

    // Update the chat service with the latest chats.
    // Use addChat for chats we haven't seen locally yet — updateChat is a no-op
    // when no ChatState exists, which leaves brand-new chats invisible in the
    // list (and their latestMessage unset) until the app restarts.
    for (var chat in syncedChats.values) {
      if (ChatsSvc.getChatState(chat.guid) == null) {
        await ChatsSvc.addChat(chat, immediate: true);
      } else {
        ChatsSvc.updateChat(chat, override: true);
      }
    }

    // Apply group photo changes detected during the sync.
    // Each entry holds the most-recent photo-event action for that chat; we
    // re-fetch the icon from the server for changes, or clear it for removals.
    for (final entry in latestPhotoChangePerChat.entries) {
      final chat = syncedChats[entry.key];
      if (chat == null) continue;
      if (entry.value.groupActionType == 2) {
        // Photo explicitly removed — clear without an HTTP round-trip.
        await ChatsSvc.setChatCustomAvatarPath(chat, null);
      } else {
        // Photo added/changed — pull latest icon from server, then refresh state.
        await Chat.getIcon(chat, force: true);
        ChatsSvc.updateChat(chat, override: true);
      }
    }

    // Call this first so listeners can react before any
    // "heavier" calls are made
    await super.complete();

    if (onComplete != null) {
      onComplete!();
    }
  }
}
