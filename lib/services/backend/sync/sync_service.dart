import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/utils/general_utils.dart';
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
    if (kIsWeb || kIsDesktop) {
      contacts.addAll((await incrementalSyncIsolate.call(null)).map((e) => Contact.fromMap(e)));
    } else {
      contacts.addAll((await incrementalSyncIsolate.call(null)).map((e) => Contact.fromMap(e)));
      /*final completer = Completer<List<Map<String, dynamic>>>();
      final port = RawReceivePort();
      port.handler = (List<Map<String, dynamic>> response) {
        port.close();
        completer.complete(response);
      };

      try {
        await FlutterIsolate.spawn(incrementalSyncIsolate, port.sendPort);
      } catch (e) {
        Logger.error('Got error when opening isolate: $e');
        port.close();
      }

      contacts.addAll((await completer.future).map((e) => Contact.fromMap(e)));
      FlutterIsolate.killAll();*/
    }
    cs.completeContactsRefresh(contacts);

    isIncrementalSyncing.value = false;
  }
}

@pragma('vm:entry-point')
Future<List<Map<String, dynamic>>> incrementalSyncIsolate(SendPort? port) async {
  try {
    /*if (!kIsWeb && !kIsDesktop) {
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
      scheduledBox = store.box<ScheduledMessage>();
      themeBox = store.box<ThemeStruct>();
    }*/

    int syncStart = ss.settings.lastIncrementalSync.value;
    final incrementalSyncManager = IncrementalSyncManager(syncStart);
    await incrementalSyncManager.start();
    final map = await cs.refreshContacts();
    port?.send(map);
    return map;
  } catch (ex) {
    Logger.error('Incremental sync failed! Error: $ex');
    port?.send([]);
    return <Map<String, dynamic>>[];
  }
}