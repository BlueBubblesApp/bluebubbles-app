import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/services/services.dart';
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

  // A flag telling the "complete" function to save the timestamp/row ID markers.
  bool saveMarker;

  // A callback to call when the sync is complete
  Function? onComplete;

  // The default extra fields to fetch with the messages
  List<String> defaultWithQuery = [
    "chats", "chats.participants", "attachments", "attributedBody", "messageSummaryInfo", "payloadData"];

  IncrementalSyncManager({
      this.startRowId,
      this.endRowId,
      this.startTimestamp,
      this.endTimestamp,
      this.batchSize = 1000,
      this.saveMarker = false,
      this.onComplete,
      bool saveLogs = false
  }) : super("Incremental", saveLogs: saveLogs) {
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
    int serverVersion = (await ss.getServerDetails()).item4;
    bool isMin_1_2_0 = serverVersion >= 142; // Server: v1.2.0 (1 * 100 + 2 * 21 + 0)
    bool isMin_1_6_0 = serverVersion >= 226; // Server: v1.6.0 (1 * 100 + 6 * 21 + 0)

    try {
      // If we've don't have a startRowId (null or 0), then sync using timestamps
      if (isMin_1_6_0 && (startRowId ?? 0) > 0) {
        addToOutput("Syncing with server version >= 1.6.0");
        await startMin_1_6_0();
      } else if (isMin_1_2_0) {
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
  }

  Future<void> startMin_1_6_0() async {
    if (startRowId == null) {
      throw Exception("startRowId cannot be null for server versions >= 1.6.0");
    }

    // Query the API for messages.
    // This endpoint will return the total messages that match the query in v1.6.0+
    addToOutput('Fetching messages...');
    dio.Response<dynamic> messagesRes = await http.messages(
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
    dio.Response<dynamic> uMessageCountRes = await http.messageCount(
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
    dio.Response<dynamic> uMessageCountRes = await http.messageCount(
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
        messagesResponse = await http.messages(
            where: buildRowIdWhereArgs(startRowId!, endRowId),
            offset: i * batchSize,
            limit: batchSize,
            withQuery: defaultWithQuery);
      } else {
        messagesResponse = await http.messages(
            after: startTimestamp,
            before: endTimestamp,
            offset: i * batchSize,
            limit: batchSize,
            withQuery: defaultWithQuery);
      }

      int messageCount = messagesResponse.data['data'].length;
      addToOutput('Page ${i + 1} returned $messageCount message(s)...',
          level: LogLevel.DEBUG);

      if (messageCount == 0) break;
      await syncMessages(messagesResponse.data['data'], total);
    }

    // If we've synced chats, we should also update the latest message
    if (syncedChats.isNotEmpty) {
      await Chat.syncLatestMessages(syncedChats.values.toList(), true);
    }
  }

  Future<void> syncMessages(List<dynamic> messages, int total) async {
    // If we don't get any messages return false (no more messages)
    if (messages.isEmpty) return;

    // Enumerate the chats into cache
    Map<String, Chat> chatCache = {};
    Map<String, List<Message>> messagesToSync = {};
    for (var msgData in messages) {
      for (var chat in msgData['chats']) {
        if (!chatCache.containsKey(chat['guid'])) {
          chatCache[chat['guid']] = Chat.fromMap(chat);
        }

        if (!messagesToSync.containsKey(chat['guid'])) {
          messagesToSync[chat['guid']] = [];
        }

        Message msg = Message.fromMap(msgData);
        messagesToSync[chat['guid']]!.add(msg);

        // Save the last synced ROWID
        if (msg.originalROWID != null && (lastSyncedRowId == null || msg.originalROWID! > lastSyncedRowId!)) {
          lastSyncedRowId = msg.originalROWID;
        }

        // Save the last synced timestamp
        if (lastSyncedTimestamp == null || msg.dateCreated.millisecondsSinceEpoch > lastSyncedTimestamp!) {
          lastSyncedTimestamp = msg.dateCreated.millisecondsSinceEpoch;
        }
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
    for (var item in messagesToSync.entries) {
      Chat? theChat = chatCache[item.key];
      if (theChat == null || item.value.isEmpty) continue;

      List<Message> s = await Chat.bulkSyncMessages(theChat, item.value);
      messagesSynced += s.length;
      setProgress(messagesSynced, total);
    }
  }

  List<Map<String, dynamic>> buildRowIdWhereArgs(int startRowId, int? endRowId) {
    List<Map<String, dynamic>> whereArgs = [
      {
        'statement': 'message.ROWID > :startRowId',
        'args': {
          'startRowId': startRowId
        }
      }
    ];

    if (endRowId != null && endRowId > startRowId) {
      whereArgs.add({
        'statement': 'message.ROWID <= :endRowId',
        'args': {
          'endRowId': endRowId
        }
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
      if (startTimestamp != null) {
        ss.settings.lastIncrementalSync.value = syncStartedAt;
      } else if (lastSyncedTimestamp != null) {
        ss.settings.lastIncrementalSync.value = lastSyncedTimestamp!;
      }

      // The lastRowId should always get set, even when sycing using timestamps
      if (lastSyncedRowId != null) {
        ss.settings.lastIncrementalSyncRowId.value = lastSyncedRowId!;
      }

      await ss.saveSettings();
    }

    // Call this first so listeners can react before any
    // "heavier" calls are made
    await super.complete();

    if (ss.settings.showIncrementalSync.value) {
      showSnackbar('Success', '🔄 Incremental sync complete 🔄');
    }

    if (onComplete != null) {
      onComplete!();
    }
  }
}
