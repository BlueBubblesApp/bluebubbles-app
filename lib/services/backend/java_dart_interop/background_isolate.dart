import 'dart:ui';

import 'package:bluebubbles/layouts/startup/upgrading_db.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    MethodChannelInterface().invokeMethod("initialize-background-handle", {"handle": callbackHandle.toRawHandle()});
  }
}

@pragma('vm:entry-point')
backgroundIsolateEntrypoint() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  final documentsDirectory =
  //ignore: unnecessary_cast, we need this as a workaround
    (await getApplicationDocumentsDirectory()) as Directory;
  Directory objectBoxDirectory = Directory(join(documentsDirectory.path, 'objectbox'));
  final sqlitePath = join(documentsDirectory.path, "chat.db");

  Future<void> initStore() async {
    debugPrint("Trying to attach to an existing ObjectBox store");
    try {
      store = Store.attach(getObjectBoxModel(), join(documentsDirectory.path, 'objectbox'));
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      debugPrint("Failed to attach to existing store, opening from path");
      try {
        store = await openStore(directory: join(documentsDirectory.path, 'objectbox'));
      } catch (e, s) {
        debugPrint(e.toString());
        debugPrint(s.toString());
      }
    }
    debugPrint("Opening boxes");
    attachmentBox = store.box<Attachment>();
    chatBox = store.box<Chat>();
    fcmDataBox = store.box<FCMData>();
    handleBox = store.box<Handle>();
    messageBox = store.box<Message>();
    scheduledBox = store.box<ScheduledMessage>();
    themeBox = store.box<ThemeStruct>();
  }

  if (!await objectBoxDirectory.exists() && await File(sqlitePath).exists()) {
    runApp(UpgradingDB());
    debugPrint("Converting sqflite to ObjectBox...");
    Stopwatch s = Stopwatch();
    s.start();
    await DBProvider.db.initDB(initStore: initStore);
    s.stop();
    debugPrint("Migrated in ${s.elapsedMilliseconds} ms");
  } else {
    if (await File(sqlitePath).exists() && prefs.getBool('objectbox-migration') != true) {
      runApp(UpgradingDB());
      debugPrint("Converting sqflite to ObjectBox...");
      Stopwatch s = Stopwatch();
      s.start();
      await DBProvider.db.initDB(initStore: initStore);
      s.stop();
      debugPrint("Migrated in ${s.elapsedMilliseconds} ms");
    } else {
      await initStore();
    }
  }

  await SettingsManager().init();
  await SettingsManager().getSavedSettings(headless: true);
  if (!ContactManager().hasFetchedContacts) await ContactManager().loadContacts(headless: true);
  MethodChannelInterface().init(customChannel: _backgroundChannel);
}
