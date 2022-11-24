import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/window_effects.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/setup/failure_to_start.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/setup/splash_screen.dart';
import 'package:bluebubbles/layouts/setup/upgrading_db.dart';
import 'package:bluebubbles/layouts/testing_mode.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/managers/background_isolate.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/navigator_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/dart_vlc.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_cached_fonts/dynamic_cached_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_dart/firebase_dart.dart';

// ignore: implementation_imports
import 'package:firebase_dart/src/auth/utils.dart' as fdu;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide MenuItem;
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' show basename, dirname, join, split, joinAll;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:version/version.dart' as ver;
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

// final SentryClient _sentry = SentryClient(
//     dsn:
//         "https://3123d4f0d82d405190cb599d0e904adc@o373132.ingest.sentry.io/5372783");

bool get isInDebugMode {
  // Assume you're in production mode.
  bool inDebugMode = false;

  // Assert expressions are only evaluated during development. They are ignored
  // in production. Therefore, this code only sets `inDebugMode` to true
  // in a development environment.
  assert(inDebugMode = true);

  return inDebugMode;
}

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
late SharedPreferences prefs;
late final FirebaseApp app;
late final Store store;
late final Box<Attachment> attachmentBox;
late final Box<Chat> chatBox;
late final Box<FCMData> fcmDataBox;
late final Box<Handle> handleBox;
late final Box<Message> messageBox;
late final Box<ScheduledMessage> scheduledBox;
late final Box<ThemeStruct> themeBox;
late final Box<ThemeEntry> themeEntryBox;
late final Box<ThemeObject> themeObjectBox;
final RxBool fontExistsOnDisk = false.obs;
final RxBool downloadingFont = false.obs;
final RxnDouble progress = RxnDouble();
final RxnInt totalSize = RxnInt();
late final CorePalette? monetPalette;
Color? windowsAccentColor;
late final Database db;

String? _recentIntent;

String? get recentIntent => _recentIntent;

set recentIntent(String? intent) {
  _recentIntent = intent;

  // After 5 seconds, we want to set the intent to null
  if (intent != null) {
    Future.delayed(Duration(seconds: 5), () {
      _recentIntent = null;
    });
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
    // If there is a bad certificate callback, override it if the host is part of
    // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        String serverUrl = sanitizeServerAddress() ?? "";
        return serverUrl.contains(host);
      }; // add your localhost detection logic here if you want
  }
}

@pragma('vm:entry-point')
//ignore: prefer_void_to_null
Future<Null> main() async {
  await initApp(false);
}

@pragma('vm:entry-point')
// ignore: prefer_void_to_null
Future<Null> bubble() async {
  await initApp(true);
}

//ignore: prefer_void_to_null
Future<Null> initApp(bool isBubble) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Logger.init();
  Logger.startup.value = true;
  Logger.info('Startup Logs');

  if (kIsDesktop) {
    await WindowManager.instance.ensureInitialized();
    await DartVLC.initialize();
  }

  HttpOverrides.global = MyHttpOverrides();
  LifeCycleManager().isBubble = isBubble;

  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) async {
    Logger.error(details.exceptionAsString());
    Logger.error(details.stack.toString());
    if (isInDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to
      // Sentry.
      Zone.current.handleUncaughtError(details.exception, details.stack!);
    }
  };
  dynamic exception;
  StackTrace? stacktrace;
  if ((Platform.isLinux || Platform.isWindows) && kIsDesktop) {
    //ignore: unnecessary_cast, we need this as a workaround
    Directory appData = (await getApplicationSupportDirectory()) as Directory;
    if (!await Directory(join(appData.path, "objectbox")).exists()) {
      // Migrate to new appdata location if this function returns the new place and we still have the old place
      if (basename(appData.absolute.path) == "bluebubbles") {
        Directory oldAppData =
        Platform.isWindows
            ? Directory(join(dirname(dirname(appData.absolute.path)), "com.bluebubbles\\bluebubbles_app"))
            : Directory(join(dirname(appData.absolute.path), "bluebubbles_app"));
        bool storeApp = basename(dirname(dirname(appData.absolute.path))) != "Roaming";
        if (await oldAppData.exists()) {
          Logger.info("Copying appData to new directory");
          copyDirectory(oldAppData, appData);
          Logger.info("Finished migrating appData");
        } else if (Platform.isWindows) {
          // Find the other appdata.
          String appDataRoot = joinAll(split(appData.absolute.path).slice(0, 4));
          if (storeApp) {
            // If current app is store, we first look for new location nonstore appdata in case people are installing
            // diff versions
            oldAppData = Directory(join(appDataRoot, "Roaming", "BlueBubbles", "bluebubbles"));
            // If that doesn't exist, we look in the old non-store location
            if (!await oldAppData.exists()) {
              oldAppData = Directory(join(appDataRoot, "Roaming", "com.bluebubbles", "bluebubbles_app"));
            }
            if (await oldAppData.exists()) {
              Logger.info("Copying appData from NONSTORE location to new directory");
              copyDirectory(oldAppData, appData);
              Logger.info("Finished migrating appData");
            }
          } else {
            oldAppData = Directory(join(
                appDataRoot,
                "Local",
                "Packages",
                "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw",
                "LocalCache",
                "Roaming",
                "BlueBubbles",
                "bluebubbles"));
            if (!await oldAppData.exists()) {
              oldAppData = Directory(join(
                  appDataRoot,
                  "Local",
                  "Packages",
                  "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw",
                  "LocalCache",
                  "Roaming",
                  "com.bluebubbles",
                  "bluebubbles_app"));
            }
            if (await oldAppData.exists()) {
              Logger.info("Copying appData from STORE location to new directory");
              copyDirectory(oldAppData, appData);
              Logger.info("Finished migrating appData");
            }
          }
        }
      }
    }
  }
  try {
    prefs = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      Directory documentsDirectory =
      //ignore: unnecessary_cast, we need this as a workaround
      (kIsDesktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory()) as Directory;
      Directory objectBoxDirectory = Directory(join(documentsDirectory.path, 'objectbox'));
      final sqlitePath = join(documentsDirectory.path, "chat.db");

      Future<void> initStore() async {
        bool? useCustomPath = prefs.getBool("use-custom-path");
        String? customStorePath = prefs.getString("custom-path");
        if (!kIsDesktop) {
          Logger.info("Trying to attach to an existing ObjectBox store");
          try {
            store = Store.attach(getObjectBoxModel(), join(documentsDirectory.path, 'objectbox'));
          } catch (e, s) {
            Logger.error(e);
            Logger.error(s);
            Logger.info("Failed to attach to existing store, opening from path");
            try {
              store = await openStore(directory: join(documentsDirectory.path, 'objectbox'));
            } catch (e, s) {
              Logger.error(e);
              Logger.error(s);
            }
          }
        } else if (useCustomPath == true && Platform.isWindows) {
          customStorePath ??= "C:\\bluebubbles_app";
          objectBoxDirectory = Directory(join(customStorePath, "objectbox"));
          if (kIsDesktop) {
            await objectBoxDirectory.create(recursive: true);
          }
          Logger.info("Opening ObjectBox store from custom path: ${join(customStorePath, 'objectbox')}");
          store = await openStore(directory: join(customStorePath, "objectbox"));
        } else {
          try {
            if (kIsDesktop) {
              await Directory(join(documentsDirectory.path, 'objectbox')).create(recursive: true);
            }
            Logger.info("Opening ObjectBox store from path: ${join(documentsDirectory.path, 'objectbox')}");
            store = await openStore(directory: join(documentsDirectory.path, 'objectbox'));
          } catch (e, s) {
            Logger.error(e);
            Logger.error(s);
            if (Platform.isWindows) {
              Logger.info("Failed to open store from default path. Using custom path");
              customStorePath ??= "C:\\bluebubbles_app";
              prefs.setBool("use-custom-path", true);
              objectBoxDirectory = Directory(join(customStorePath, "objectbox"));
              await objectBoxDirectory.create(recursive: true);
              Logger.info("Opening ObjectBox store from custom path: ${objectBoxDirectory.path}");
              store = await openStore(directory: join(customStorePath, 'objectbox'));
            }
            // TODO Linux fallback
          }
        }
        attachmentBox = store.box<Attachment>();
        chatBox = store.box<Chat>();
        fcmDataBox = store.box<FCMData>();
        handleBox = store.box<Handle>();
        messageBox = store.box<Message>();
        scheduledBox = store.box<ScheduledMessage>();
        themeBox = store.box<ThemeStruct>();
        themeEntryBox = store.box<ThemeEntry>();
        themeObjectBox = store.box<ThemeObject>();
        if (themeBox.isEmpty()) {
          prefs.setString("selected-dark", "OLED Dark");
          prefs.setString("selected-light", "Bright White");
          themeBox.putMany(Themes.defaultThemes);
        }
      }

      if (!(await objectBoxDirectory.exists()) && await File(sqlitePath).exists()) {
        runApp(UpgradingDB());
        print("Converting sqflite to ObjectBox...");
        Stopwatch s = Stopwatch();
        s.start();
        await DBProvider.db.initDB(initStore: initStore);
        s.stop();
        Logger.info("Migrated in ${s.elapsedMilliseconds} ms");
      } else {
        if (await File(sqlitePath).exists() && prefs.getBool('objectbox-migration') != true) {
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
    FirebaseDart.setup(
      platform: fdu.Platform.web(
        currentUrl: Uri.base.toString(),
        isMobile: false,
        isOnline: true,
      ),
    );
    var options = FirebaseOptions(
        appId: 'my_app_id',
        apiKey: 'apiKey',
        projectId: 'my_project',
        messagingSenderId: 'ignore',
        authDomain: 'my_project.firebaseapp.com');
    app = await Firebase.initializeApp(options: options);
    await initializeDateFormatting();
    await SettingsManager().init();
    await SettingsManager().getSavedSettings(headless: true);
    if (!ContactManager().hasFetchedContacts && !kIsDesktop && !kIsWeb) {
      await ContactManager().loadContacts(headless: true);
    }
    if (SettingsManager().settings.immersiveMode.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (kIsDesktop) {
      PackageInfo? packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (_) {
        Logger.error("Getting packageInfo failed, using bluebubbles_app");
      }
      LaunchAtStartup.setup(packageInfo?.appName ?? "bluebubbles_app");
      if (SettingsManager().settings.launchAtStartup.value) {
        await LaunchAtStartup.enable();
      } else {
        await LaunchAtStartup.disable();
      }
    }
    // this is to avoid a fade-in transition between the android native splash screen
    // and our dummy splash screen
    if (!SettingsManager().settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
      runApp(MaterialApp(
          home: SplashScreen(shouldNavigate: false),
          theme: ThemeData(
              backgroundColor: SchedulerBinding.instance.window.platformBrightness == Brightness.dark
                  ? Colors.black
                  : Colors.white)));
    }
    Get.put(AttachmentDownloadService());
    if (!kIsWeb && !kIsDesktop) {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_stat_icon');
      final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin!.initialize(initializationSettings);
      tz.initializeTimeZones();
      // it doesn't matter if this errors
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterNativeTimezone.getLocalTimezone()));
      } catch (_) {}
      if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
        EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
      }
      await FlutterLibphonenumber().init();
    }
    if (kIsDesktop) {
      await WindowManager.instance.setTitle('BlueBubbles');
      await Window.initialize();
      if (Platform.isWindows) {
        await Window.hideWindowControls();
      }
      WindowManager.instance.addListener(DesktopWindowListener());
      doWhenWindowReady(() async {
        await WindowManager.instance.setMinimumSize(Size(300, 300));
        Display primary = await ScreenRetriever.instance.getPrimaryDisplay();
        Size size = primary.size;
        Rect bounds = Rect.fromLTWH(0, 0, size.width, size.height);

        double? width = prefs.getDouble("window-width");
        double? height = prefs.getDouble("window-height");
        if (width != null && height != null) {
          if ((width == width.clamp(300, bounds.width)) && (height == height.clamp(300, bounds.height))) {
            await WindowManager.instance.setSize(Size(width, height));
          }
        }

        double? posX = prefs.getDouble("window-x");
        double? posY = prefs.getDouble("window-y");
        if (posX != null && posY != null && width != null && height != null) {
          if ((posX == posX.clamp(bounds.left, bounds.right - width)) &&
              (posY == posY.clamp(bounds.top, bounds.bottom - height))) {
            await WindowManager.instance.setPosition(Offset(posX, posY));
          }
        } else {
          await WindowManager.instance.setAlignment(Alignment.center);
        }

        await WindowManager.instance.setTitle('BlueBubbles');
        await WindowManager.instance.show();
      });

      if (Platform.isWindows) {
        windowsAccentColor = await DynamicColorPlugin.getAccentColor();
      }
    }
    if (!kIsWeb) {
      try {
        DynamicCachedFonts.loadCachedFont(
            "https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf",
            fontFamily: "Apple Color Emoji")
            .then((_) {
          fontExistsOnDisk.value = true;
        });
      } on StateError catch (_) {
        fontExistsOnDisk.value = false;
      }
    } else if (kIsWeb) {
      final idbFactory = idbFactoryBrowser;
      idbFactory.open("BlueBubbles.db", version: 1, onUpgradeNeeded: (VersionChangeEvent e) {
        final db = (e.target as OpenDBRequest).result;
        if (!db.objectStoreNames.contains("BBStore")) {
          db.createObjectStore("BBStore");
        }
      }).then((_db) async {
        db = _db;
        final txn = db.transaction("BBStore", idbModeReadOnly);
        final store = txn.objectStore("BBStore");
        Uint8List? bytes = await store.getObject("iosFont") as Uint8List?;
        await txn.completed;

        if (!isNullOrEmpty(bytes)!) {
          fontExistsOnDisk.value = true;
          final fontLoader = FontLoader("Apple Color Emoji");
          final cachedFontBytes = ByteData.view(bytes!.buffer);
          fontLoader.addFont(
            Future<ByteData>.value(cachedFontBytes),
          );
          await fontLoader.load();
        }
      });
    }

    if (kIsDesktop) {
      await dotenv.load(fileName: '.env');
    }
  } catch (e, s) {
    Logger.error(e);
    Logger.error(s);
    exception = e;
    stacktrace = s;
  }

  monetPalette = await DynamicColorPlugin.getCorePalette();

  if (exception == null) {
    ThemeData light = ThemeStruct
        .getLightTheme()
        .data;
    ThemeData dark = ThemeStruct
        .getDarkTheme()
        .data;

    final tuple = Platform.isWindows ? applyWindowsAccent(light, dark) : applyMonet(light, dark);
    light = tuple.item1;
    dark = tuple.item2;

    runApp(Main(
      lightTheme: light,
      darkTheme: dark,
    ));
  } else {
    runApp(FailureToStart(e: exception, s: stacktrace));
    throw Exception("$exception $stacktrace");
  }
}

class DesktopWindowListener extends WindowListener {
  @override
  void onWindowFocus() {
    LifeCycleManager().opened(null);
  }

  @override
  void onWindowBlur() {
    LifeCycleManager().close();
  }

  @override
  void onWindowResized() async {
    prefs.setDouble("window-width", (await WindowManager.instance.getSize()).width);
    prefs.setDouble("window-height", (await WindowManager.instance.getSize()).height);
  }

  @override
  void onWindowMoved() async {
    prefs.setDouble("window-x", (await WindowManager.instance.getPosition()).dx);
    prefs.setDouble("window-y", (await WindowManager.instance.getPosition()).dy);
  }
}

/// The [Main] app.
///
/// This is the entry for the whole app (when the app is visible or not fully closed in the background)
/// This main widget controls
///     - Theming
///     - [NavgatorManager]
///     - [Home] widget
class Main extends StatelessWidget with WidgetsBindingObserver {
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  const Main({Key? key, required this.lightTheme, required this.darkTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(

      /// These are the default white and dark themes.
      /// These will be changed by [SettingsManager] when you set a custom theme
      light: lightTheme.copyWith(
          textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark: darkTheme.copyWith(
          textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),

      /// The default is that the dark and light themes will follow the system theme
      /// This will be changed by [SettingsManager]
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) =>
          GetMaterialApp(

            /// Hide the debug banner in debug mode
            debugShowCheckedModeBanner: false,

            title: 'BlueBubbles',

            /// Set the light theme from the [AdaptiveTheme]
            theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),

            /// Set the dark theme from the [AdaptiveTheme]
            darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),

            /// [NavigatorManager] is set as the navigator key so that we can control navigation from anywhere
            navigatorKey: NavigatorManager().navigatorKey,

            /// [Home] is the starting widget for the app
            home: Home(),

            shortcuts: {
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const OpenSettingsIntent(),
              LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
              if (kIsDesktop)
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const OpenSearchIntent(),
              LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
              if (kIsDesktop) LogicalKeySet(
                  LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
              if (kIsDesktop)
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR):
                const StartIncrementalSyncIntent(),
              if (kIsDesktop)
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.exclamation):
              const HeartRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.at):
              const LikeRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.numberSign):
              const DislikeRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.dollar):
              const LaughRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.percent):
              const EmphasizeRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.caret):
              const QuestionRecentIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown): const OpenNextChatIntent(),
              if (kIsDesktop) LogicalKeySet(
                  LogicalKeyboardKey.control, LogicalKeyboardKey.tab): const OpenNextChatIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp): const OpenPreviousChatIntent(),
              if (kIsDesktop)
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
                const OpenPreviousChatIntent(),
              LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const OpenChatDetailsIntent(),
              LogicalKeySet(LogicalKeyboardKey.escape): const GoBackIntent(),
            },

            builder: (context, child) =>
                SecureApplication(
                  child: Builder(builder: (context) {
                    if (SettingsManager().canAuthenticate && !LifeCycleManager().isAlive) {
                      if (SettingsManager().settings.shouldSecure.value) {
                        SecureApplicationProvider.of(context, listen: false)!.lock();
                        if (SettingsManager().settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                          SecureApplicationProvider.of(context, listen: false)!.secure();
                        }
                      }
                    }
                    return SecureGate(
                      blurr: 0,
                      opacity: 1.0,
                      lockedBuilder: (context, controller) =>
                          Container(
                            color: context.theme.colorScheme.background,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                                    child: Text(
                                      "BlueBubbles is currently locked. Please unlock to access your messages.",
                                      style: context.theme.textTheme.titleLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Container(height: 20.0),
                                  ClipOval(
                                    child: Material(
                                      color: context.theme.colorScheme.primary, // button color
                                      child: InkWell(
                                        child: SizedBox(
                                            width: 60,
                                            height: 60,
                                            child: Icon(Icons.lock_open, color: context.theme.colorScheme.onPrimary)),
                                        onTap: () async {
                                          var localAuth = LocalAuthentication();
                                          bool didAuthenticate = await localAuth.authenticate(
                                              localizedReason: 'Please authenticate to unlock BlueBubbles',
                                              options: AuthenticationOptions(stickyAuth: true));
                                          if (didAuthenticate) {
                                            controller!.authSuccess(unlock: true);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      child: child ?? Container(),
                    );
                  }),
                ),

            defaultTransition: Transition.cupertino,

            getPages: [
              GetPage(page: () => TestingMode(), name: "/testing-mode", binding: TestingModeBinding()),
            ],
          ),
    );
  }
}

/// [Home] widget is responsible for holding the main UI view.
///
/// It renders the main view and also initializes a few managers
///
/// The [LifeCycleManager] also is binded to the [WidgetsBindingObserver]
/// so that it can know when the app is closed, paused, or resumed
class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  ReceivePort port = ReceivePort();
  bool serverCompatible = true;
  bool fullyLoaded = false;

  @override
  void initState() {
    super.initState();

    if (kIsDesktop) {
      if (Platform.isWindows) {
        // Delete temp dir in case any notif icons weren't cleared
        getApplicationSupportDirectory().then((d) async {
          Directory temp = Directory(join(d.path, "temp"));
          if (await temp.exists()) await temp.delete(recursive: true);
        });
      }
      Future.delayed(Duration.zero, () async {
        await localNotifier.setup(
          appName: "BlueBubbles",
        );
        await initSystemTray();
        if (Platform.isWindows) {
          await WindowsTaskbar.resetOverlayIcon();
        }
      });
    }

    // we want to refresh the page rather than loading a new instance of [Home]
    // to avoid errors
    if (LifeCycleManager().isAlive && kIsWeb) {
      html.window.location.reload();
    }

    // Initalize a bunch of managers
    MethodChannelInterface().init();

    if (!kIsWeb) {
      if (!LifeCycleManager().isBubble) {
        // This initialization sets the function address in the native code to be used later
        BackgroundIsolateInterface.initialize();
        // Create the notification in case it hasn't been already. Doing this multiple times won't do anything, so we just do it on every app start
        NotificationManager().createNotificationChannel(
          NotificationManager.NEW_MESSAGE_CHANNEL,
          "New Messages",
          "For new messages retreived",
        );
        NotificationManager().createNotificationChannel(
          NotificationManager.SOCKET_ERROR_CHANNEL,
          "Socket Connection Error",
          "Notifications that will appear when the connection to the server has failed",
        );
        // create a send port to receive messages from the background isolate when
        // the UI thread is active
        final result = IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
        if (!result) {
          IsolateNameServer.removePortNameMapping('bg_isolate');
          IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
        }
        port.listen((dynamic data) {
          Logger.info("SendPort received action ${data['action']}");
          if (data['action'] == 'new-message') {
            // Add it to the queue with the data as the item
            IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_MESSAGE_EVENT, item: {"data": data}));
          } else if (data['action'] == 'update-message') {
            // Add it to the queue with the data as the item
            IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_UPDATE_MESSAGE, item: {"data": data}));
          }
        });
      }
    }

    // We initialize the [LifeCycleManager] so that it is open, because [initState] occurs when the app is opened
    LifeCycleManager().opened(context);

    // Listen to a refresh-all event in case the entire ap
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh-all' && mounted) {
        setState(() {});
      }
    });

    // Get the saved settings from the settings manager after the first frame
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await SettingsManager().getSavedSettings();

      if (SettingsManager().settings.colorsFromMedia.value) {
        try {
          await MethodChannelInterface().invokeMethod("start-notif-listener");
        } catch (_) {}
      }

      if (kIsWeb && SettingsManager().settings.finishedSetup.value) {
        String? str = await SettingsManager().getServerVersion();
        ver.Version version = ver.Version.parse(str!);
        int sum = version.major * 100 + version.minor * 21 + version.patch;
        if (sum < 42) {
          setState(() {
            serverCompatible = false;
          });
        }

        // override ctrl-f action in browsers
        html.document.onKeyDown.listen((e) {
          if (e.keyCode == 114 || (e.ctrlKey && e.keyCode == 70)) {
            e.preventDefault();
          }
        });
      }

      // check for server updates on app launch
      if (SettingsManager().settings.finishedSetup.value) {
        api.checkUpdate().then((response) {
          if (response.statusCode == 200) {
            bool available = response.data['data']['available'] ?? false;
            Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};
            if (!available || prefs.getString("update-check") == metadata['version']) return;
            Get.defaultDialog(
              title: "Server Update Check",
              titleStyle: context.theme.textTheme.headlineMedium,
              textConfirm: "OK",
              cancel: Container(height: 0, width: 0),
              content: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 15.0,
                    ),
                    Text("Updates available:", style: context.theme.textTheme.bodyMedium),
                    SizedBox(
                      height: 15.0,
                    ),
                    if (metadata.isNotEmpty)
                      Text("Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ??
                          "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}")
                  ]
              ),
              onConfirm: () {
                if (metadata['version'] != null) {
                  prefs.setString("update-check", metadata['version']);
                }
                Navigator.of(context).pop();
              },
              backgroundColor: context.theme.colorScheme.properSurface,
            );
          }
        });
      }

      if (!kIsWeb && !kIsDesktop) {
        if (!LifeCycleManager().isBubble) {
          // Get sharing media from files shared to the app from cold start
          // This one only handles files, not text
          ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) async {
            if (!SettingsManager().settings.finishedSetup.value) return;
            if (value.isEmpty) return;

            // If we don't have storage permission, we can't do anything
            if (!await Permission.storage
                .request()
                .isGranted) return;

            // Add the attached files to a list
            List<PlatformFile> attachments = [];
            for (SharedMediaFile element in value) {
              attachments.add(PlatformFile(
                name: element.path
                    .split("/")
                    .last,
                path: element.path,
                size: 0,
              ));
            }

            if (attachments.isEmpty) return;

            // Go to the new chat creator, with all of our attachments
            CustomNavigator.pushAndRemoveUntil(
              context,
              ConversationView(
                existingAttachments: attachments,
                isCreator: true,
              ),
                  (route) => route.isFirst,
            );
          });

          // Same thing as [getInitialMedia] except for text
          ReceiveSharingIntent.getInitialText().then((String? text) {
            if (!SettingsManager().settings.finishedSetup.value) return;
            if (text == null) return;

            // Go to the new chat creator, with all of our text
            CustomNavigator.pushAndRemoveUntil(
              context,
              ConversationView(
                existingText: text,
                isCreator: true,
              ),
                  (route) => route.isFirst,
            );
          });
        }

        // Request native code to retreive what the starting intent was
        //
        // The starting intent will be set when you click on a notification
        // This is only really necessary when opening a notification and the app is fully closed
        MethodChannelInterface().invokeMethod("get-starting-intent").then((value) {
          if (!SettingsManager().settings.finishedSetup.value) return;
          if (value['guid'] != null) {
            LifeCycleManager().isBubble = value['bubble'] == "true";
            MethodChannelInterface().openChat(value['guid'].toString());
          }
        });
      }
      if (!SettingsManager().settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      }
    });

    // Load in the pre-cached assets
    ChatManager().loadAssets();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() async {
    Locale myLocale = Localizations.localeOf(context);
    SettingsManager().countryCode = myLocale.countryCode;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Call the [LifeCycleManager] events based on the [state]
    if (state == AppLifecycleState.paused && !LifeCycleManager().isBubble) {
      SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
        Logger.error("Error caught while hiding keyboard: ${e.toString()}");
      });
      LifeCycleManager().close();
    } else if (state == AppLifecycleState.resumed) {
      LifeCycleManager().opened(context);
    }
  }

  /// Just in case the theme doesn't change automatically
  /// Workaround for adaptive_theme issue #32
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (AdaptiveTheme
        .maybeOf(context)
        ?.mode == AdaptiveThemeMode.system) {
      if (AdaptiveTheme
          .maybeOf(context)
          ?.brightness == Brightness.light) {
        AdaptiveTheme.maybeOf(context)?.setLight();
      } else {
        AdaptiveTheme.maybeOf(context)?.setDark();
      }
      AdaptiveTheme.maybeOf(context)?.setSystem();
    }
  }

  /// Render
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme
          .colorScheme.background, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    if (kIsDesktop && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await WindowEffects.setEffect(color: context.theme.backgroundColor);
        EventDispatcher().stream.listen((Map<String, dynamic> event) async {
          if (!event.containsKey("type")) return;

          if (event["type"] == 'theme-update') {
            Color? color = mounted ? context.theme.backgroundColor : Get.context?.theme.backgroundColor;
            if (color != null) {
              await WindowEffects.setEffect(color: color);
            }
          }

          if (event["type"] == 'popup-pushed') {
            bool popup = event["data"] as bool;
            if (popup) {
              SettingsManager().settings.windowEffect.value = WindowEffect.disabled;
            } else {
              SettingsManager().settings.windowEffect.value =
                  WindowEffect.values.firstWhereOrNull((effect) => effect.toString() ==
                      prefs.getString('window-effect')) ?? WindowEffect.aero;
            }
          }
        });
      });
    }

    final Rx<Color> _backgroundColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? context
        .theme.colorScheme.background : Colors.transparent).obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _backgroundColor.value =
          effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme
            .colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
        actions: {
          OpenSettingsIntent: OpenSettingsAction(context),
          OpenNewChatCreatorIntent: OpenNewChatCreatorAction(context),
          OpenSearchIntent: OpenSearchAction(context),
          OpenNextChatIntent: OpenNextChatAction(context),
          OpenPreviousChatIntent: OpenPreviousChatAction(context),
          StartIncrementalSyncIntent: StartIncrementalSyncAction(),
          GoBackIntent: GoBackAction(context),
        },
        child: Obx(() =>
            Scaffold(
              backgroundColor: _backgroundColor.value,
              body: Builder(
                builder: (BuildContext context) {
                  if (SettingsManager().settings.finishedSetup.value) {
                    Logger.startup.value = false;
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeRight,
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.portraitUp,
                      if (SettingsManager().settings.allowUpsideDownRotation.value)
                        DeviceOrientation.portraitDown,
                    ]);
                    if (!serverCompatible && kIsWeb) {
                      return FailureToStart(
                        otherTitle: "Server version too low, please upgrade!",
                        e: "Required Server Version: v0.2.0",
                      );
                    }
                    return ConversationList(
                      showArchivedChats: false,
                      showUnknownSenders: false,
                    );
                  } else {
                    if (context.isPhone) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                      ]);
                    }
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: TitleBarWrapper(
                          child: kIsWeb || kIsDesktop ? SetupView() : SplashScreen(shouldNavigate: fullyLoaded)),
                    );
                  }
                },
              ),
            )),
      ),
    );
  }
}

Future<void> initSystemTray() async {
  final systemTray = SystemTray();
  String path;
  if (Platform.isWindows) {
    path = joinAll([dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.ico']);
  } else if (Platform.isMacOS) {
    path = joinAll(['AppIcon']);
  } else {
    path = joinAll([dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
  }

  // We first init the systray menu and then add the menu entries
  await systemTray.initSystemTray(title: "BlueBubbles", iconPath: path, toolTip: "BlueBubbles");

  final Menu menu = Menu();
  await menu.buildFrom(
      [
        MenuItemLable(
          label: 'Open App',
          onClicked: (_) async {
            LifeCycleManager().opened(null);
            await WindowManager.instance.show();
          },
        ),
        MenuItemLable(
          label: 'Hide App',
          onClicked: (_) async {
            LifeCycleManager().close();
            await WindowManager.instance.hide();
          },
        ),
        MenuItemLable(
          label: 'Close App',
          onClicked: (_) async {
            await WindowManager.instance.close();
          },
        ),
      ]
  );

  await systemTray.setContextMenu(menu);

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) async {
    switch (eventName) {
      case 'click':
        await WindowManager.instance.show();
        break;
      case "right-click":
        await systemTray.popUpContextMenu();
        break;
    }
  });
}

void copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false).forEach((element) async {
      if (element is Directory) {
        Directory newDirectory = Directory(join(destination.absolute.path, basename(element.path)));
        newDirectory.createSync();
        Logger.info("Created new directory ${basename(element.path)}");

        copyDirectory(element.absolute, newDirectory);
      } else if (element is File) {
        element.copySync(join(destination.path, basename(element.path)));
        Logger.info("Created file ${basename(element.path)}");
      }
    });
