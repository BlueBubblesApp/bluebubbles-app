import 'dart:ui';

import 'package:bluebubbles/layouts/startup/upgrading_db.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
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
  isUiThread = false;
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  await fs.init();
  await settings.init(headless: true);
  Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
  final sqlitePath = join(fs.appDocDir.path, "chat.db");

  Future<void> initStore() async {
    debugPrint("Trying to attach to an existing ObjectBox store");
    try {
      store = Store.attach(getObjectBoxModel(), join(fs.appDocDir.path, 'objectbox'));
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      debugPrint("Failed to attach to existing store, opening from path");
      try {
        store = await openStore(directory: join(fs.appDocDir.path, 'objectbox'));
      } catch (e, s) {
        debugPrint(e.toString());
        debugPrint(s.toString());
      }
    }
    debugPrint("Opening boxes");
    attachmentBox = store.box<Attachment>();
    chatBox = store.box<Chat>();
    contactBox = store.box<Contact>();
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
    if (await File(sqlitePath).exists() && settings.prefs.getBool('objectbox-migration') != true) {
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

  MethodChannelInterface().init(customChannel: _backgroundChannel);
}
