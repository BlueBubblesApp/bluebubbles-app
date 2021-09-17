import 'dart:ui';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/upgrading_db.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/join_tables.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/scheduled.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

abstract class BackgroundIsolateInterface {
  static void initialize() {
    CallbackHandle callbackHandle =
        PluginUtilities.getCallbackHandle(callbackHandler)!;
    MethodChannelInterface().invokeMethod("initialize-background-handle",
        {"handle": callbackHandle.toRawHandle()});
  }
}

callbackHandler() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    var documentsDirectory = await getApplicationDocumentsDirectory();
    final objectBoxDirectory = Directory(documentsDirectory.path + '/objectbox/');
    //ignore: unnecessary_cast, we need this as a workaround
    if (kIsDesktop) documentsDirectory = (await getApplicationSupportDirectory()) as Directory;
    final sqlitePath = join(documentsDirectory.path, "chat.db");

    Future<void> Function() initStore = () async {
      store = await openStore();
      attachmentBox = store.box<Attachment>();
      chatBox = store.box<Chat>();
      fcmDataBox = store.box<FCMData>();
      handleBox = store.box<Handle>();
      messageBox = store.box<Message>();
      scheduledBox = store.box<ScheduledMessage>();
      themeEntryBox = store.box<ThemeEntry>();
      themeObjectBox = store.box<ThemeObject>();
      amJoinBox = store.box<AttachmentMessageJoin>();
      chJoinBox = store.box<ChatHandleJoin>();
      cmJoinBox = store.box<ChatMessageJoin>();
      tvJoinBox = store.box<ThemeValueJoin>();
    };

    if (!objectBoxDirectory.existsSync() && File(sqlitePath).existsSync()) {
      runApp(UpgradingDB());
      print("Converting sqflite to ObjectBox...");
      Stopwatch s = Stopwatch();
      s.start();
      await DBProvider.db.initDB(initStore: initStore);
      s.stop();
      print("Migrated in ${s.elapsedMilliseconds} ms");
    } else {
      if (File(sqlitePath).existsSync() && prefs.getBool('objectbox-migration') != true) {
        runApp(UpgradingDB());
        print("Converting sqflite to ObjectBox...");
        Stopwatch s = Stopwatch();
        s.start();
        await DBProvider.db.initDB(initStore: initStore);
        s.stop();
        print("Migrated in ${s.elapsedMilliseconds} ms");
      } else {
        await initStore();
      }
    }
  }
  await SettingsManager().init();
  await SettingsManager().getSavedSettings(headless: true);
  await ContactManager().getContacts(headless: true);
  MethodChannelInterface().init(customChannel: _backgroundChannel);
  await SocketManager().refreshConnection(connectToSocket: false);
}
