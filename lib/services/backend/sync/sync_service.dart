import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' show join;

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
        isolate = await FlutterIsolate.spawn(incrementalSyncIsolate, port.sendPort);
      } catch (e) {
        Logger.error('Got error when opening isolate: $e');
        port.close();
      }
      result = await completer.future;
      if (result.isNotEmpty && (result.first.isNotEmpty || result.last.isNotEmpty)) {
        contacts.addAll(Contact.getContacts());
      }
      isolate?.kill();
    }
    cs.completeContactsRefresh(contacts, reloadUI: result);

    isIncrementalSyncing.value = false;
  }
}

@pragma('vm:entry-point')
Future<List<List<int>>> incrementalSyncIsolate(SendPort? port) async {
  try {
    if (!kIsWeb && !kIsDesktop) {
      WidgetsFlutterBinding.ensureInitialized();
      ls.isUiThread = false;
      await ss.init(headless: true);
      await fs.init(headless: true);
      store = Store.attach(getObjectBoxModel(), join(fs.appDocDir.path, 'objectbox'));
      attachmentBox = store.box<Attachment>();
      chatBox = store.box<Chat>();
      contactBox = store.box<Contact>();
      fcmDataBox = store.box<FCMData>();
      handleBox = store.box<Handle>();
      messageBox = store.box<Message>();
      themeBox = store.box<ThemeStruct>();
    }

    int syncStart = ss.settings.lastIncrementalSync.value;
    final incrementalSyncManager = IncrementalSyncManager(syncStart);
    await incrementalSyncManager.start();
    chats.sort();
  } catch (ex, s) {
    Logger.error('Incremental sync failed! Error: $ex');
    Logger.error(s.toString());
  }
  Logger.info('Starting contact refresh');
  try {
    final refreshedItems = await cs.refreshContacts();
    Logger.info('Finished contact refresh, shouldRefresh $refreshedItems');
    port?.send(refreshedItems);
    return refreshedItems;
  } catch (ex) {
    Logger.error('Contacts refresh failed! Error: $ex');
    port?.send([]);
    return [];
  }
}