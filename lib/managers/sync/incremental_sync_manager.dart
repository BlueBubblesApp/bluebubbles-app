import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/sync/sync_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class IncrementalSyncManager extends SyncManager {
  final tag = 'IncrementalSyncManager';

  int startTimestamp;

  late int endTimestamp;

  int messageCount;

  int chatsSynced = 0;

  int messagesSynced = 0;

  int? processId;

  String? chatGuid;

  bool saveDate;

  Function? onComplete;

  int? syncStart;

  IncrementalSyncManager(this.startTimestamp,
      {int? endTimestamp, this.messageCount = 25, this.chatGuid, this.saveDate = true, this.onComplete})
      : super("Incremental") {
    this.endTimestamp = endTimestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    super.start();

    // Setup the socket process and error handler
    processId = SocketManager().addSocketProcess(([bool finishWithError = false]) {});

    // Store the time we started syncing
    RxInt lastSync = SettingsManager().settings.lastIncrementalSync;
    syncStart = DateTime.now().millisecondsSinceEpoch;
    addToOutput("Starting incremental sync for messages since: ${lastSync.value}");

    // only get up to 1000 messages (arbitrary limit)
    int batches = 10;
    for (int i = 0; i < batches; i++) {
      // Build request params. We want all details on the messages
      Map<String, dynamic> params = {};
      if (chatGuid != null) {
        params["chatGuid"] = chatGuid;
      }

      params["withBlurhash"] = false; // Maybe we want it?
      params["limit"] = 100;
      params["offset"] = i * batches;
      params["after"] = lastSync.value; // Get everything since the last sync
      params["withChats"] = true; // We want the chats too so we can save them correctly
      params["withChatParticipants"] = true; // We want participants on web only
      params["withAttachments"] = true; // We want the attachment data
      params["withHandle"] = true; // We want to know who sent it
      params["sort"] = "DESC"; // Sort my DESC so we receive the newest messages first

      List<dynamic> messages = await SocketManager().getMessages(params)!;
      if (messages.isEmpty) {
        addToOutput("No more new messages found during incremental sync");
        break;
      } else {
        addToOutput("Incremental sync found ${messages.length} messages. Syncing...");
      }

      if (messages.isNotEmpty) {
        await MessageHelper.bulkAddMessages(null, messages, onProgress: (progress, total) {
          setProgress(progress, total);
        }, notifyForNewMessage: !kIsWeb);
      }
    }

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

    if (processId != null) {
      SocketManager().finishSocketProcess(processId);
      processId = null;
    }

    if (onComplete != null) {
      onComplete!();
    }
  }
}
