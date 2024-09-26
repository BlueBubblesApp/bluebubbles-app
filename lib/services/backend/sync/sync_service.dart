import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
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
    List<List<int>> result = [];
    if (kIsWeb || kIsDesktop) {
      result = await incrementalSyncIsolate.call(null);
      if (result.isNotEmpty && (result.first.isNotEmpty || result.last.isNotEmpty)) {
        contacts.addAll(cs.contacts);
      }
    } else {
      final completer = Completer<List<List<int>>>();
      final port = RawReceivePort();
      port.handler = (List<List<int>> response) {
        port.close();
        completer.complete(response);
      };

      FlutterIsolate? isolate;
      try {
        isolate = await FlutterIsolate.spawn(incrementalSyncIsolate, [port.sendPort, http.originOverride]);
      } catch (e, stack) {
        Logger.error('Got error when opening isolate!', error: e, trace: stack);
        port.close();
      }
      result = await completer.future;
      if (result.isNotEmpty && (result.first.isNotEmpty || result.last.isNotEmpty)) {
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
      isolate?.kill();
    }
    cs.completeContactsRefresh(contacts, reloadUI: result);

    isIncrementalSyncing.value = false;
  }
}

@pragma('vm:entry-point')
Future<List<List<int>>> incrementalSyncIsolate(List? items) async {
  final SendPort? port = items?.firstOrNull;
  final String? address = items?.lastOrNull;
  try {
    if (!kIsWeb && !kIsDesktop) {
      WidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = BadCertOverride();

      await StartupTasks.initIncrementalSyncServices();

      http.originOverride = address;
    }

    int syncStart = ss.settings.lastIncrementalSync.value;
    int startRowId = ss.settings.lastIncrementalSyncRowId.value;
    final incrementalSyncManager = IncrementalSyncManager(
      startTimestamp: syncStart, startRowId: startRowId, saveMarker: true);
    await incrementalSyncManager.start();
  } catch (ex, s) {
    Logger.error('Incremental sync failed!', error: ex, trace: s);
  }
  Logger.info('Starting contact refresh');
  try {
    final refreshedItems = await cs.refreshContacts();
    Logger.info('Finished contact refresh, shouldRefresh $refreshedItems');
    port?.send(refreshedItems);
    return refreshedItems;
  } catch (ex, stack) {
    Logger.error('Contacts refresh failed!', error: ex, trace: stack);
    port?.send([]);
    return [];
  }
}