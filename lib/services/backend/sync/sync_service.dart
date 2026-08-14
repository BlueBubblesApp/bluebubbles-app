import 'dart:async';
import 'dart:math' as math;

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/ui/async_task.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/contact_v2_interface.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:bluebubbles/services/isolates/incremental_sync_isolate.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_it/get_it.dart';
import 'package:universal_io/universal_io.dart';

// ignore: non_constant_identifier_names
SyncService get SyncSvc => GetIt.I<SyncService>();

class SyncService {
  int numberOfMessagesPerPage = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;
  bool syncGroupChatIcons = false;
  int? syncTimeFilter;
  final RxBool isIncrementalSyncing = false.obs;

  static const Duration _incrementalSyncCooldown = Duration(seconds: 30);
  static const int _dispatchChunkSize = 50;
  DateTime? _lastIncrementalSyncTimestamp;

  FullSyncManager? _manager;
  FullSyncManager? get fullSyncManager => _manager;

  void initFullSync() {
    _manager = FullSyncManager(
        messageCount: numberOfMessagesPerPage.toInt(),
        skipEmptyChats: skipEmptyChats,
        saveLogs: saveToDownloads,
        syncGroupChatIcons: syncGroupChatIcons,
        syncTimeFilter: syncTimeFilter);
  }

  Future<void> startFullSync() async {
    if (_manager == null) {
      initFullSync();
    }

    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    SettingsSvc.settings.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await SettingsSvc.settings.saveOneAsync('lastIncrementalSync');
    await _manager!.start();
  }

  Future<void> startIncrementalSync({bool useGlobalIsolate = false}) async {
    if (isIncrementalSyncing.value) return;

    final now = DateTime.now();
    if (_lastIncrementalSyncTimestamp != null &&
        now.difference(_lastIncrementalSyncTimestamp!) < _incrementalSyncCooldown) {
      Logger.debug(
        'Skipping incremental sync... Last ran ${now.difference(_lastIncrementalSyncTimestamp!).inSeconds}s ago '
        '(cooldown: ${_incrementalSyncCooldown.inSeconds}s)',
        tag: 'Incremental Chat Sync',
      );
      return;
    }

    _lastIncrementalSyncTimestamp = now;
    isIncrementalSyncing.value = true;
    int errors = 0;

    // Per-page tracking: record message IDs and chat subtitle message IDs that were
    // already applied by per-page events so the final return can skip redundant work.
    final processedMessageIds = <int>{};
    final processedSubtitleByChat = <String, int>{}; // chatGuid → message DB ID

    // This runs on the UI thread (isolate event listeners are invoked synchronously),
    // so a page of up to `batchSize` messages must never be hydrated in one block.
    Future<void> onPageComplete(dynamic data) async {
      if (data is! Map<String, dynamic>) return;
      final messageIdsByChat =
          (data['messageIdsByChat'] as Map).map((k, v) => MapEntry(k as String, (v as List).cast<int>()));
      final latestPerChat = Map<String, int>.from(data['latestMessageIdPerChat'] as Map);

      // repositionImmediate: false so a page touching many chats rebuilds the list once.
      for (final entry in latestPerChat.entries) {
        final msg = await runAsync(() => Database.messages.get(entry.value));
        if (msg == null) continue;
        // If this chat was created for the first time during this sync,
        // ChatState doesn't exist yet — register it so updateChatLatestMessage
        // isn't a silent no-op.
        if (ChatsSvc.getChatState(entry.key) == null) {
          final chat = msg.chat.target;
          if (chat != null) await ChatsSvc.addChat(chat, immediate: true);
        }
        ChatsSvc.updateChatLatestMessage(entry.key, msg, repositionImmediate: false);
        processedSubtitleByChat[entry.key] = entry.value;
      }

      // Only an open conversation view needs the individual messages — every other
      // chat is served by the subtitle update above.
      for (final entry in messageIdsByChat.entries) {
        if (maybeFindMessagesSvc(entry.key) == null) continue;
        for (int i = 0; i < entry.value.length; i += _dispatchChunkSize) {
          // Re-resolve every chunk: the user can leave this chat between chunks
          final service = maybeFindMessagesSvc(entry.key);
          if (service == null) break;
          final chunk = entry.value.sublist(i, math.min(i + _dispatchChunkSize, entry.value.length));
          final messages = await runAsync(() => Database.messages.getMany(chunk).whereType<Message>().toList());
          for (final message in messages) {
            if (message.guid == null) continue;
            await service.addNewMessage(message);
            if (message.id != null) processedMessageIds.add(message.id!);
          }
        }
      }
    }

    final syncIsolate = GetIt.I<IncrementalSyncIsolate>();
    syncIsolate.addEventListener(IsolateEvent.incrementalSyncPageComplete, onPageComplete);

    try {
      Logger.info('Starting incremental chat sync...', tag: 'Incremental Chat Sync');
      final chatStopwatch = Stopwatch()..start();
      final syncedMessages = await SyncInterface.performIncrementalSync(useGlobalIsolate: useGlobalIsolate);
      if (syncedMessages.isNotEmpty) {
        // latestMessageIdPerChat is keyed by chat GUID, so syncedMessages already contains
        // at most one message per chat. Deduplicate defensively by keeping the latest
        // message per chat GUID in case the data ever changes.
        final Map<String, Message> latestPerChat = {};
        for (final message in syncedMessages) {
          final chatGuid = message.chat.target?.guid;
          if (chatGuid == null) continue;
          final existing = latestPerChat[chatGuid];
          if (existing == null ||
              (message.dateCreated != null &&
                  (existing.dateCreated == null || message.dateCreated!.isAfter(existing.dateCreated!)))) {
            latestPerChat[chatGuid] = message;
          }
        }

        // IncrementalSyncManager.complete() already called ChatsSvc.updateChat() for every
        // synced chat. Here we only need to push the subtitle update into ChatState.
        // Skip chats where the per-page event already applied the same (or newer) message.
        for (final entry in latestPerChat.entries) {
          final message = entry.value;
          if (message.id != null && processedSubtitleByChat[entry.key] == message.id) continue;
          ChatsSvc.updateChatLatestMessage(entry.key, message, repositionImmediate: false);
        }

        // Dispatch newly synced messages to any currently active chat view.
        // Skip messages already dispatched by a per-page event.
        // MessagesService.addNewMessage() is a no-op if the message is already present,
        // so this is safe even without the skip, but avoiding the call reduces churn.
        for (final message in syncedMessages) {
          if (message.id != null && processedMessageIds.contains(message.id)) continue;
          final chatGuid = message.chat.target?.guid;
          if (chatGuid == null || message.guid == null) continue;
          if (Get.isRegistered<MessagesService>(tag: chatGuid)) {
            unawaited(Get.find<MessagesService>(tag: chatGuid).addNewMessage(message));
          }
        }
      }

      chatStopwatch.stop();
      Logger.info(
          'Incremental chat sync completed! Synced ${syncedMessages.length} messages across '
          '${syncedMessages.map((m) => m.chat.target?.guid).toSet().length} chats '
          'in ${chatStopwatch.elapsedMilliseconds}ms',
          tag: 'Incremental Chat Sync');
    } catch (e, stack) {
      Logger.error('Incremental chat sync failed!', error: e, trace: stack, tag: 'Incremental Chat Sync');
      errors += 1;
    } finally {
      syncIsolate.removeEventListener(IsolateEvent.incrementalSyncPageComplete, onPageComplete);
    }

    final contactSyncResult = await performContactSyncToHandles();
    if (!contactSyncResult) {
      errors += 1;
    }

    final contactUploadResult = await performContactSyncToServer();
    if (!contactUploadResult) {
      errors += 1;
    }

    if (errors > 0) {
      await showToast('Incremental sync completed with $errors errors', isError: true);
    } else if (SettingsSvc.settings.showIncrementalSync.value) {
      await showToast('Incremental sync complete');
    }

    isIncrementalSyncing.value = false;
  }

  Future<bool> performContactSyncToHandles() async {
    try {
      Logger.info('Starting contact refresh', tag: 'Incremental Contact Sync');
      final contactStopwatch = Stopwatch()..start();
      final refreshedHandleIds = await ContactsSvcV2.syncContactsToHandles();
      contactStopwatch.stop();
      Logger.info(
          'Finished contact refresh, refreshed ${refreshedHandleIds.length} handles in ${contactStopwatch.elapsedMilliseconds}ms',
          tag: 'Incremental Contact Sync');

      if (refreshedHandleIds.isNotEmpty) {
        ContactsSvcV2.notifyHandlesUpdated(refreshedHandleIds);
      }

      return true;
    } catch (ex, stack) {
      Logger.error('Contacts refresh failed!', error: ex, trace: stack, tag: 'Incremental Contact Sync');
      return false;
    }
  }

  Future<bool> performContactSyncToServer() async {
    try {
      // Auto upload contacts if requested
      if (Platform.isAndroid && SettingsSvc.settings.syncContactsAutomatically.value) {
        Logger.debug("Starting contact upload to server...", tag: "Contact Upload");
        final contactUploadStopwatch = Stopwatch()..start();
        // Get all contacts from ContactServiceV2
        final contactsV2 = await ContactsSvcV2.getAllContacts();
        final _contacts = <Map<String, dynamic>>[];
        for (final c in contactsV2) {
          _contacts.add(c.toServerMap());
        }

        await ContactV2Interface.uploadContacts(_contacts);
        contactUploadStopwatch.stop();
        Logger.debug("Contact upload complete in ${contactUploadStopwatch.elapsedMilliseconds}ms",
            tag: "Contact Upload");
      }

      return true;
    } catch (e, stack) {
      Logger.error("Failed to upload contacts!", error: e, trace: stack, tag: "Contact Upload");
      return false;
    }
  }
}
