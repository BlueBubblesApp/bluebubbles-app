import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/helpers/backend/isolate_helpers.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

SyncService sync = Get.isRegistered<SyncService>() ? Get.find<SyncService>() : Get.put(SyncService());

class SyncService extends GetxService {
  int numberOfMessagesPerPage = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;
  final RxBool isIncrementalSyncing = false.obs;

  FullSyncManager? _manager;
  FullSyncManager? get fullSyncManager => _manager;

  Future<void> startFullSync() async {
    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    ss.settings.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await ss.saveSettings();

    _manager = FullSyncManager(
        messageCount: numberOfMessagesPerPage.toInt(),
        skipEmptyChats: skipEmptyChats,
        saveLogs: saveToDownloads
    );
    await _manager!.start();
  }

  Future<void> startIncrementalSync() async {
    isIncrementalSyncing.value = true;
    final contacts = <Contact>[];
    Map<String, dynamic> result;

    if (!Platform.isAndroid) {
      result = await _incrementalSync();
    } else {
      result = await runBackgroundTask(_incrementalSyncIsolate);
    }

    // Load chat changes
    if (result["chats"].isNotEmpty) {
      Logger.debug("Syncing ${result["chats"].length} chats...");
      List<Chat> updatedChatInfo = await Chat.getLatestMessages((result["chats"] as List<int?>).whereNotNull().toList());
      await GlobalChatService.syncChats(updatedChatInfo);
    }

    // Handle contacts
    if (!Platform.isAndroid && result["contacts"].isNotEmpty) {
      contacts.addAll(cs.contacts);
    } else if (result["contacts"].isNotEmpty && (result["contacts"].first.isNotEmpty || result["contacts"].last.isNotEmpty)) {
      contacts.addAll(Contact.getContacts());

      // auto upload contacts if requested
      if (ss.settings.syncContactsAutomatically.value) {
        Logger.debug("Contact changes detected, uploading to server...");
        final _contacts = <Map<String, dynamic>>[];
        for (Contact c in contacts) {
          var map = c.toMap();
          _contacts.add(map);
        }
        http.createContact(_contacts).catchError((err, stack) {
          if (err is Response) {
            Logger.error(err.data["error"]["message"].toString(), error: err, trace: stack);
          } else {
            Logger.error("Failed to create contacts!", error: err, trace: stack);
          }
          return Response(requestOptions: RequestOptions(path: ''));
        });
      }
    }

    cs.completeContactsRefresh(contacts, reloadUI: result["contacts"] as List<List<int>>);
    isIncrementalSyncing.value = false;
  }
}

Future<Map<String, dynamic>> _incrementalSync() async {
  int syncStart = ss.settings.lastIncrementalSync.value;
  int startRowId = ss.settings.lastIncrementalSyncRowId.value;

  // Subtract 3 days from the last sync date
  syncStart = DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
  final IncrementalSyncManager syncer = IncrementalSyncManager(
    startTimestamp: syncStart, startRowId: startRowId, saveMarker: true);

  try {
    await syncer.start();
  } catch (ex, s) {
    Logger.error('Incremental sync failed!', error: ex, trace: s);
  }

  Map<String, dynamic> output = {
    "contacts": [],
    "chats": [],
  };

  Logger.info('Starting contact refresh');
  try {
    final refreshedItems = await cs.refreshContacts();
    Logger.info('Finished contact refresh, shouldRefresh $refreshedItems');
    output["contacts"] = refreshedItems;
  } catch (ex, stack) {
    Logger.error('Contacts refresh failed!', error: ex, trace: stack);
    output["contacts"] = [];
  }

  // Insert chats to return
  output["chats"] = syncer.syncedChats.values.map((e) => e.id).toList();
  return output;
}

@pragma('vm:entry-point')
void _incrementalSyncIsolate(List<Object?> items) async {
  final SendPort? port = items.firstOrNull as SendPort?;
  final String? address = items.lastOrNull as String?;

  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = BadCertOverride();
    await StartupTasks.initIncrementalSyncServices();
    http.originOverride = address;
  }

  Map<String, dynamic> output = await _incrementalSync();

  // Send data over the port or just return it
  port?.send(output);
}