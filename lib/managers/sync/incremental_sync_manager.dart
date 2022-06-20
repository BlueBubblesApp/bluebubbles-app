import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/sync/sync_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../repository/models/io/chat.dart';

class IncrementalSyncManager extends SyncManager {
  final tag = 'IncrementalSyncManager';

  int startTimestamp;

  int? endTimestamp;

  int messageCount;

  int chatsSynced = 0;

  int messagesSynced = 0;

  String? chatGuid;

  bool saveDate;

  Function? onComplete;

  int? syncStart;

  IncrementalSyncManager(this.startTimestamp,
      {
        this.endTimestamp,
        this.messageCount = 25,
        this.chatGuid,
        this.saveDate = true,
        this.onComplete,
        bool saveLogs = false
      }) : super("Incremental", saveLogs: saveLogs);

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    super.start();

    // Store the time we started syncing
    RxInt lastSync = SettingsManager().settings.lastIncrementalSync;
    syncStart = endTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    addToOutput("Starting incremental sync for messages since: ${lastSync.value}");

    // 0: Hit API endpoint to check for updated messages
    // 1: If no new updated messages, complete the sync
    // 2: If there are new messages, fetch them by page
    // 3: Enumerate the chats into cache
    // 4: Sync the chats
    // 5: Merge synced chats back into cache
    // 6: For each chat, bulk sync the messages

    // 0: Hit API endpoint to check for updated messages
    int pages = 0;
    int batchSize = 0;
    dio.Response<dynamic> uMessageCountRes = await api.messageCount(
      after: DateTime.fromMillisecondsSinceEpoch(lastSync.value),
      before: DateTime.fromMillisecondsSinceEpoch(syncStart!)
    );
    uMessageCountRes.

    // End the sync
    await complete();
  }

  @override
  Future<void> complete() async {
    // Once we have added everything, save the last sync date
    if (saveDate && syncStart != null) {
      addToOutput("Saving last sync date: $syncStart");

      Settings _settingsCopy = SettingsManager().settings;
      _settingsCopy.lastIncrementalSync.value = syncStart!;
      await SettingsManager().saveSettings(_settingsCopy);
    }

    // Call this first so listeners can react before any
    // "heavier" calls are made
    await super.complete();

    if (SettingsManager().settings.showIncrementalSync.value) {
      showSnackbar('Success', '🔄 Incremental sync complete 🔄');
    }

    if (onComplete != null) {
      onComplete!();
    }
  }
}
