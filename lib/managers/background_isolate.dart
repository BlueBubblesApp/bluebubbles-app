import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/upgrading_db.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:universal_io/io.dart';

abstract class BackgroundIsolateInterface {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(callbackHandler)!;
    MethodChannelInterface().invokeMethod("initialize-background-handle", {"handle": callbackHandle.toRawHandle()});
  }
}

callbackHandler() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  // due to a flutter change we need to manually register plugins
  // should be removeable in flutter 2.11
  if (Platform.isAndroid) {
    SharedPreferencesAndroid.registerWith();
    PathProviderAndroid.registerWith();
  } else if (kIsWeb) {
    // do nothing
  } else if (Platform.isLinux) {
    SharedPreferencesLinux.registerWith();
    PathProviderLinux.registerWith();
  } else if (Platform.isWindows) {
    SharedPreferencesWindows.registerWith();
    PathProviderWindows.registerWith();
  }
  prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    var documentsDirectory =
        //ignore: unnecessary_cast, we need this as a workaround
        (kIsDesktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory()) as Directory;
    Directory objectBoxDirectory = Directory(join(documentsDirectory.path, 'objectbox'));
    final sqlitePath = join(documentsDirectory.path, "chat.db");

    Future<void> initStore({bool saveThemes = false}) async {
      String? storeRef = prefs.getString("objectbox-reference");
      bool? useCustomPath = prefs.getBool("use-custom-path");
      String? customStorePath = prefs.getString("custom-path");
      if (!kIsDesktop && storeRef != null) {
        debugPrint("Opening ObjectBox store from reference");
        try {
          store = Store.fromReference(getObjectBoxModel(), base64.decode(storeRef).buffer.asByteData());
        } catch (_) {
          debugPrint("Failed to open store from reference, opening from path");
          try {
            store = await openStore(directory: join(documentsDirectory.path, 'objectbox'));
          } catch (e, s) {
            debugPrint(e.toString());
            debugPrint(s.toString());
          }
        }
      } else if (useCustomPath == true && Platform.isWindows) {
        customStorePath ??= "C:\\bluebubbles_app";
        objectBoxDirectory = Directory(join(customStorePath, "objectbox"));
        objectBoxDirectory.createSync(recursive: true);
        debugPrint("Opening ObjectBox store from custom path: ${join(customStorePath, 'objectbox')}");
        store = await openStore(directory: join(customStorePath, "objectbox"));
      } else {
        try {
          if (kIsDesktop) {
            Directory(join(documentsDirectory.path, 'objectbox')).createSync(recursive: true);
          }
          debugPrint("Opening ObjectBox store from path: ${join(documentsDirectory.path, 'objectbox')}");
          store = await openStore(directory: join(documentsDirectory.path, 'objectbox'));
        }  catch (e, s) {
          debugPrint(e.toString());
          debugPrint(s.toString());
          if (Platform.isWindows) {
            debugPrint("Failed to open store from default path. Using custom path");
            customStorePath ??= "C:\\bluebubbles_app";
            prefs.setBool("use-custom-path", true);
            objectBoxDirectory = Directory(join(customStorePath, "objectbox"));
            objectBoxDirectory.createSync(recursive: true);
            debugPrint("Opening ObjectBox store from custom path: ${objectBoxDirectory.path}");
            store = await openStore(directory: join(customStorePath, 'objectbox'));
          }
          // TODO Linux fallback
        }
      }
      prefs.setString("objectbox-reference", base64.encode(store.reference.buffer.asUint8List()));
      debugPrint("Opening boxes");
      attachmentBox = store.box<Attachment>();
      chatBox = store.box<Chat>();
      fcmDataBox = store.box<FCMData>();
      handleBox = store.box<Handle>();
      messageBox = store.box<Message>();
      scheduledBox = store.box<ScheduledMessage>();
      themeEntryBox = store.box<ThemeEntry>();
      themeObjectBox = store.box<ThemeObject>();
      if (saveThemes && themeObjectBox.isEmpty()) {
        for (ThemeObject theme in Themes.themes) {
          if (theme.name == "OLED Dark") theme.selectedDarkTheme = true;
          if (theme.name == "Bright White") theme.selectedLightTheme = true;
          theme.save(updateIfNotAbsent: false);
        }
      }
    }

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
  if (!ContactManager().hasFetchedContacts) await ContactManager().loadContacts(headless: true);
  MethodChannelInterface().init(customChannel: _backgroundChannel);
  await SocketManager().refreshConnection(connectToSocket: false);
  Get.put(AttachmentDownloadService());
}
