import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;

class IncrementalSyncManager extends SyncManager {
  final tag = 'IncrementalSyncManager';

  int startTimestamp;

  int? endTimestamp;

  int batchSize;

  int maxMessages;

  int chatsSynced = 0;

  int messagesSynced = 0;

  String? chatGuid;

  bool saveDate;

  bool updateChatList;

  bool notifyForNewMessages;

  Function? onComplete;

  IncrementalSyncManager(this.startTimestamp,
      {this.batchSize = 1000,
      this.maxMessages = 10000,
      this.chatGuid,
      this.updateChatList = true,
      this.saveDate = true,
      this.notifyForNewMessages = false,
      this.onComplete,
      bool saveLogs = false})
      : super("Incremental", saveLogs: saveLogs);

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    super.start();
    addToOutput(
        "Starting incremental sync for messages since: $startTimestamp");

    // 0: Hit API endpoint to check for updated messages
    // 1: If no new updated messages, complete the sync
    // 2: If there are new messages, fetch them by page
    // 3: Enumerate the chats into cache
    // 4: Sync the chats
    // 5: Merge synced chats back into cache
    // 6: For each chat, bulk sync the messages

    // Check the server version and page differently based on that.
    // In < 1.2.0, the message query API endpoint was a bit broken.
    // It would not include messages with the text being null. As such,
    // the count can be slightly lower than the real count. To account
    // for this, we just multiple the count by 2. This way, even if all
    // the messages have a null text, we can still account for them when we fetch.
    int serverVersion = (await ss.getServerDetails()).item4;
    bool isBugged = serverVersion < 142; // Server: v1.2.0

    // 0: Hit API endpoint to check for updated messages
    dio.Response<dynamic> uMessageCountRes = await http.messageCount(
      after: DateTime.fromMillisecondsSinceEpoch(startTimestamp),
    );

    // 1: If no new updated messages, complete the sync
    int count = uMessageCountRes.data['data']['total'];

    // Manually set/modify the count if we are on a bugged server
    if (isBugged) {
      // If count is 0, fetch 1 page.
      // If > 0, fetch count * 2 to account for any possible null texts
      if (count == 0) {
        count = batchSize;
      } else {
        count = count * 2;
      }
    }

    addToOutput('Found $count message(s) to sync...');
    if (count == 0) {
      return await complete();
    }

    int pages = (count / batchSize).ceil();

    // 2: If there are new messages, fetch them by page
    int syncedMessages = 0;
    Map<String, Chat> syncedChats = {};
    for (var i = 0; i < pages; i++) {
      addToOutput('Fetching page ${i + 1} of $pages...');
      dio.Response<dynamic> messages = await http.messages(
          after: startTimestamp,
          offset: i * batchSize,
          limit: batchSize,
          withQuery: ["chats", "chats.participants", "attachments", "attributedBody", "messageSummaryInfo", "payloadData"]);

      int messageCount = messages.data['data'].length;
      addToOutput('Page ${i + 1} returned $messageCount message(s)...',
          level: LogLevel.DEBUG);

      // If we don't get any messages back, break out so we can complete.
      if (messageCount == 0) break;

      // 3: Enumerate the chats into cache
      Map<String, Chat> chatCache = {};
      Map<String, List<Message>> messagesToSync = {};
      bool shouldStop = false;
      for (var msgData in messages.data['data'] as List<dynamic>) {
        for (var chat in msgData['chats']) {
          if (!chatCache.containsKey(chat['guid'])) {
            chatCache[chat['guid']] = Chat.fromMap(chat);
          }

          if (!messagesToSync.containsKey(chat['guid'])) {
            messagesToSync[chat['guid']] = [];
          }

          Message msg = Message.fromMap(msgData);

          // If the message is out of our date range, skip it,
          // then break out of the loop after syncing
          var date = msg.dateCreated!.millisecondsSinceEpoch;
          bool skip = date < startTimestamp;
          if (!shouldStop && skip) {
            shouldStop = true;
          }

          if (!skip) {
            messagesToSync[chat['guid']]!.add(msg);
          }
        }
      }

      // 4: Sync the chats
      List<Chat> theChats = await Chat.bulkSyncChats(chatCache.values.toList());

      // 5: Merge synced chats back into cache
      for (var chat in theChats) {
        if (!chatCache.containsKey(chat.guid)) continue;
        chatCache[chat.guid] = chat;
      }

      // Add everything to the global cache
      syncedChats.addAll(chatCache);

      // 6: For each chat, bulk sync the messages
      for (var item in messagesToSync.entries) {
        Chat? theChat = chatCache[item.key];
        if (theChat == null || item.value.isEmpty) continue;

        List<Message> s = await Chat.bulkSyncMessages(theChat, item.value);
        syncedMessages += s.length;
        setProgress(syncedMessages, count);
      }

      if (shouldStop) break;
    }

    // If we've synced chats, we should also update the latest message
    if (syncedChats.isNotEmpty) {
      await Chat.syncLatestMessages(syncedChats.values.toList(), true);
    }

    // End the sync
    await complete();
  }

  @override
  Future<void> complete() async {
    // Once we have added everything, save the last sync date
    if (saveDate) {
      addToOutput("Saving last sync date...");

      ss.settings.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
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
