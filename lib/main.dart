import 'dart:async';
import 'dart:isolate';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/custom/custom_error_box.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/startup/failure_to_start.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/layouts/startup/splash_screen.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' show basename, dirname, join;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:system_tray/system_tray.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

// todo list desktop
/// Show notif badges

const databaseVersion = 2;
late final Store store;
late final Box<Attachment> attachmentBox;
late final Box<Chat> chatBox;
late final Box<Contact> contactBox;
late final Box<FCMData> fcmDataBox;
late final Box<Handle> handleBox;
late final Box<Message> messageBox;
late final Box<ScheduledMessage> scheduledBox;
late final Box<ThemeStruct> themeBox;
late final Box<ThemeEntry> themeEntryBox;
// ignore: deprecated_member_use_from_same_package
late final Box<ThemeObject> themeObjectBox;
final Completer<void> storeStartup = Completer();
final Completer<void> uiStartup = Completer();
bool isAuthing = false;

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
Future<Null> initApp(bool bubble) async {
  WidgetsFlutterBinding.ensureInitialized();
  /* ----- SERVICES INITIALIZATION ----- */
  ls.isBubble = bubble;
  ls.isUiThread = true;
  await ss.init();
  await fs.init();
  await Logger.init();
  Logger.startup.value = true;
  Logger.info('Startup Logs');
  await ts.init();
  await mcs.init();

  /* ----- RANDOM STUFF INITIALIZATION ----- */
  HttpOverrides.global = BadCertOverride();
  dynamic exception;
  StackTrace? stacktrace;

  /* ----- APPDATA MIGRATION ----- */
  if ((Platform.isLinux || Platform.isWindows) && kIsDesktop) {
    //ignore: unnecessary_cast, we need this as a workaround
    Directory appData = fs.appDocDir as Directory;
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
          String appDataRoot = p.joinAll(p.split(appData.absolute.path).slice(0, 4));
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
    /* ----- OBJECTBOX DB INITIALIZATION ----- */
    if (!kIsWeb) {
      Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
      if (!kIsDesktop) {
        Logger.info("Trying to attach to an existing ObjectBox store");
        try {
          store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
        } catch (e, s) {
          Logger.error(e);
          Logger.error(s);
          Logger.info("Failed to attach to existing store, opening from path");
          try {
            store = await openStore(directory: objectBoxDirectory.path);
          } catch (e, s) {
            Logger.error(e);
            Logger.error(s);
          }
        }
      } else {
        try {
          await objectBoxDirectory.create(recursive: true);
          Logger.info("Opening ObjectBox store from path: ${objectBoxDirectory.path}");
          store = await openStore(directory: objectBoxDirectory.path);
        } catch (e, s) {
          Logger.error(e);
          Logger.error(s);
          if (Platform.isWindows) {
            Logger.info("Failed to open store from default path. Using custom path");
            const customStorePath = "C:\\bluebubbles_app";
            ss.prefs.setBool("use-custom-path", true);
            ss.prefs.setString("custom-path", customStorePath);
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
      contactBox = store.box<Contact>();
      fcmDataBox = store.box<FCMData>();
      handleBox = store.box<Handle>();
      messageBox = store.box<Message>();
      themeBox = store.box<ThemeStruct>();
      themeEntryBox = store.box<ThemeEntry>();
      // ignore: deprecated_member_use_from_same_package
      themeObjectBox = store.box<ThemeObject>();
      if (themeBox.isEmpty()) {
        ss.prefs.setString("selected-dark", "OLED Dark");
        ss.prefs.setString("selected-light", "Bright White");
        themeBox.putMany(ts.defaultThemes);
      }
      int version = ss.prefs.getInt('dbVersion') ?? 1;

      migrate() {
        if (version < databaseVersion) {
          switch (databaseVersion) {
            // Version 2 changed handleId to match the server side ROWID, rather than client side ROWID
            case 2:
              Logger.info("Fetching all messages and handles...", tag: "DB-Migration");
              final messages = messageBox.getAll();
              if (messages.isNotEmpty) {
                final handles = handleBox.getAll();
                Logger.info("Replacing handleIds for messages...", tag: "DB-Migration");
                for (Message m in messages) {
                  if (m.isFromMe! || m.handleId == 0 || m.handleId == null) continue;
                  m.handleId = handles.firstWhereOrNull((e) => e.id == m.handleId)?.originalROWID ?? m.handleId;
                }
                Logger.info("Final save...", tag: "DB-Migration");
                messageBox.putMany(messages);
              }
              version = 2;
              migrate.call();
              return;
            default:
              return;
          }
        }
      }

      final Stopwatch s = Stopwatch();
      s.start();
      migrate.call();
      s.stop();
      Logger.info("Done in ${s.elapsedMilliseconds}ms", tag: "DB-Migration");
    }

    /* ----- SERVICES INITIALIZATION POST OBJECTBOX ----- */
    ss.prefs.setInt('dbVersion', databaseVersion);
    storeStartup.complete();
    ss.getFcmData();
    if (!kIsWeb) {
      await cs.init();
    }
    await notif.init();
    await intents.init();
    chats.init();
    socket;

    /* ----- DATE FORMATTING INITIALIZATION ----- */
    await initializeDateFormatting();

    /* ----- SPLASH SCREEN INITIALIZATION ----- */
    if (!ss.settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
      runApp(MaterialApp(
        home: SplashScreen(shouldNavigate: false),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSwatch(backgroundColor: SchedulerBinding.instance.window.platformBrightness == Brightness.dark
            ? Colors.black
            : Colors.white),
        )
      ));
    }

    /* ----- ANDROID SPECIFIC INITIALIZATION ----- */
    if (!kIsWeb && !kIsDesktop) {
      /* ----- TIME ZONE INITIALIZATION ----- */
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterNativeTimezone.getLocalTimezone()));
      } catch (_) {}

      /* ----- MLKIT INITIALIZATION ----- */
      if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
        EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
      }

      /* ----- PHONE NUMBER FORMATTING INITIALIZATION ----- */
      await FlutterLibphonenumber().init();
    }

    /* ----- DESKTOP SPECIFIC INITIALIZATION ----- */
    if (kIsDesktop) {
      /* ----- VLC INITIALIZATION ----- */
      DartVLC.initialize();

      /* ----- WINDOW INITIALIZATION ----- */
      await windowManager.ensureInitialized();
      await windowManager.setTitle('BlueBubbles');
      await Window.initialize();
      await Window.hideWindowControls();
      windowManager.addListener(DesktopWindowListener());
      doWhenWindowReady(() async {
        await windowManager.setMinimumSize(const Size(300, 300));
        Display primary = await ScreenRetriever.instance.getPrimaryDisplay();

        double? width = ss.prefs.getDouble("window-width");
        double? height = ss.prefs.getDouble("window-height");
        if (width != null && height != null) {
          width = width.clamp(300, primary.size.width);
          height = height.clamp(300, primary.size.height);
          await windowManager.setSize(Size(width, height));
          ss.prefs.setDouble("window-width", width);
          ss.prefs.setDouble("window-height", height);
        } else {
          Size size = await windowManager.getSize();
          width = size.width;
          height = size.height;
          ss.prefs.setDouble("window-width", width);
          ss.prefs.setDouble("window-height", height);
        }

        double? posX = ss.prefs.getDouble("window-x");
        double? posY = ss.prefs.getDouble("window-y");
        if (posX != null && posY != null) {
          posX = posX.clamp(0, primary.size.width - width);
          posY = posY.clamp(0, primary.size.height - height);
          await windowManager.setPosition(Offset(posX, posY));
          ss.prefs.setDouble("window-x", posX);
          ss.prefs.setDouble("window-y", posY);
        } else {
          await windowManager.setAlignment(Alignment.center);
          Offset offset = await windowManager.getPosition();
          posX = offset.dx;
          posY = offset.dy;
          ss.prefs.setDouble("window-x", posX);
          ss.prefs.setDouble("window-y", posY);
        }

        Size size = await windowManager.getSize();
        width = size.width;
        height = size.height;
        posX = posX.clamp(0, primary.size.width - width);
        posY = posY.clamp(0, primary.size.height - height);
        await windowManager.setPosition(Offset(posX, posY));
        ss.prefs.setDouble("window-x", posX);
        ss.prefs.setDouble("window-y", posY);

        await windowManager.setTitle('BlueBubbles');
        await windowManager.show();
      });

      /* ----- GIPHY API KEY INITIALIZATION ----- */
      await dotenv.load(fileName: '.env');
    }

    /* ----- EMOJI FONT INITIALIZATION ----- */
    fs.checkFont();
  } catch (e, s) {
    Logger.error(e);
    Logger.error(s);
    exception = e;
    stacktrace = s;
  }

  if (exception == null) {
    /* ----- THEME INITIALIZATION ----- */
    ThemeData light = ThemeStruct.getLightTheme().data;
    ThemeData dark = ThemeStruct.getDarkTheme().data;

    final tuple = ts.getStructsFromData(light, dark);
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

class BadCertOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
    // If there is a bad certificate callback, override it if the host is part of
    // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        String serverUrl = sanitizeServerAddress() ?? "";
        return serverUrl.contains(host);
      };
  }
}

class DesktopWindowListener extends WindowListener {
  @override
  void onWindowFocus() {
    ls.open();
  }

  @override
  void onWindowBlur() {
    ls.close();
  }

  @override
  void onWindowResized() async {
    Size size = await windowManager.getSize();
    ss.prefs.setDouble("window-width", size.width);
    ss.prefs.setDouble("window-height", size.height);
  }

  @override
  void onWindowMoved() async {
    Offset offset = await windowManager.getPosition();
    ss.prefs.setDouble("window-x", offset.dx);
    ss.prefs.setDouble("window-y", offset.dy);
  }
}

class Main extends StatelessWidget {
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  const Main({Key? key, required this.lightTheme, required this.darkTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark: darkTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BlueBubbles',
        theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),
        darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),
        navigatorKey: ns.key,
        home: Home(),
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const OpenSettingsIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const OpenSearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
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
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab): const OpenNextChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp): const OpenPreviousChatIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
                const OpenPreviousChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const OpenChatDetailsIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const GoBackIntent(),
        },
        builder: (context, child) => SafeArea(
          top: false,
          bottom: false,
          child: SecureApplication(
            child: Builder(
              builder: (context) {
                if (ss.canAuthenticate && (!ls.isAlive || !uiStartup.isCompleted)) {
                  if (ss.settings.shouldSecure.value) {
                    SecureApplicationProvider.of(context, listen: false)!.lock();
                    if (ss.settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                      SecureApplicationProvider.of(context, listen: false)!.secure();
                    }
                  }
                }
                return SecureGate(
                  blurr: 0,
                  opacity: 1.0,
                  lockedBuilder: (context, controller) {
                    final localAuth = LocalAuthentication();
                    if (!isAuthing) {
                      isAuthing = true;
                      localAuth.authenticate(
                          localizedReason: 'Please authenticate to unlock BlueBubbles',
                          options: const AuthenticationOptions(stickyAuth: true)
                      ).then((result) {
                        isAuthing = false;
                        if (result) {
                          SecureApplicationProvider.of(context, listen: false)!.authSuccess(unlock: true);
                        }
                      });
                    }
                    return Container(
                      color: context.theme.colorScheme.background,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                                      width: 60, height: 60, child: Icon(Icons.lock_open, color: context.theme.colorScheme.onPrimary)),
                                  onTap: () async {
                                    final localAuth = LocalAuthentication();
                                    bool didAuthenticate = await localAuth.authenticate(
                                        localizedReason: 'Please authenticate to unlock BlueBubbles',
                                        options: const AuthenticationOptions(stickyAuth: true)
                                    );
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
                    );
                  },
                  child: child ?? Container(),
                );
              },
            ),
          ),
        ),
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends OptimizedState<Home> with WidgetsBindingObserver {
  final ReceivePort port = ReceivePort();
  bool serverCompatible = true;
  bool fullyLoaded = false;

  @override
  void initState() {
    super.initState();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);

    /* ----- APP REFRESH LISTENER INITIALIZATION ----- */
    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'refresh-all') {
        setState(() {});
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      uiStartup.complete();

      if (!ls.isBubble && !kIsWeb && !kIsDesktop) {
        ls.createFakePort();
      }

      ErrorWidget.builder = (FlutterErrorDetails error) {
        Logger.error(error.exception);
        Logger.error("Stacktrace: ${error.stack.toString()}");
        return CustomErrorWidget(
          "An unexpected error occurred when rendering.",
        );
      };
      /* ----- SERVER VERSION CHECK ----- */
      if (kIsWeb && ss.settings.finishedSetup.value) {
        int version = (await ss.getServerDetails()).item4;
        if (version < 42) {
          setState(() {
            serverCompatible = false;
          });
        }

        /* ----- CTRL-F OVERRIDE ----- */
        html.document.onKeyDown.listen((e) {
          if (e.keyCode == 114 || (e.ctrlKey && e.keyCode == 70)) {
            e.preventDefault();
          }
        });
      }

      if (kIsDesktop) {
        if (Platform.isWindows) {
          /* ----- CONTACT IMAGE CACHE DELETION ----- */
          Directory temp = Directory(join(fs.appDocDir.path, "temp"));
          if (await temp.exists()) await temp.delete(recursive: true);
          /* ----- BADGE ICON DELETION ----- */
          await WindowsTaskbar.resetOverlayIcon();
        }

        /* ----- SYSTEM TRAY INITIALIZATION ----- */
        await initSystemTray();

        /* ----- RESET WINDOWS NOTIFICATION BADGE ----- */
        if (Platform.isWindows) {
          await WindowsTaskbar.resetOverlayIcon();
        }

        /* ----- WINDOWS NOTIFICATIONS INITIALIZATION ----- */
        if (Platform.isWindows) {
          await localNotifier.setup(appName: "BlueBubbles");
        }

        /* ----- WINDOW EFFECT INITIALIZATION ----- */
        if (Platform.isWindows) {
          await WindowEffects.setEffect(color: context.theme.colorScheme.background);

          eventDispatcher.stream.listen((event) async {
            if (event.item1 == 'theme-update') {
              await WindowEffects.setEffect(color: context.theme.colorScheme.background);
            }
          });
        }
      }

      // only show the dialog if setup is finished
      if (ss.settings.finishedSetup.value) {
        if (ss.prefs.getBool('1.11-warning') != true && !kIsWeb) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  "Important Notice",
                  style: context.theme.textTheme.titleLarge,
                ),
                content: Text(
                  "You now have the highly-anticipated v1.11 release! Due to a change with how the app handles contacts, you will need to fully quit and reopen the app this one time only to ensure your contacts populate.\n\nCheck out the changelog for some huge new features, and we hope you enjoy!",
                  style: context.theme.textTheme.bodyLarge
                ),
                backgroundColor: context.theme.colorScheme.properSurface,
                actions: <Widget>[
                  TextButton(
                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            }
          );
        }
        if ((fs.androidInfo?.version.sdkInt ?? 0) >= 33) {
          Permission.notification.request();
        }
      }
      if (ss.prefs.getBool('1.11-warning') != true) {
        ss.prefs.setBool('1.11-warning', true);
      }

      if (!ss.settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() async {
    Locale myLocale = Localizations.localeOf(context);
    countryCode = myLocale.countryCode;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Just in case the theme doesn't change automatically
  /// Workaround for adaptive_theme issue #32
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (AdaptiveTheme.maybeOf(context)?.mode == AdaptiveThemeMode.system) {
      if (AdaptiveTheme.maybeOf(context)?.brightness == Brightness.light) {
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
      systemNavigationBarColor: ss.settings.immersiveMode.value
          ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
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
        child: Obx(() => Scaffold(
          backgroundColor: context.theme.colorScheme.background.themeOpacity(context),
          body: Builder(
            builder: (BuildContext context) {
              if (ss.settings.finishedSetup.value) {
                Logger.startup.value = false;
                if (!serverCompatible && kIsWeb) {
                  return const FailureToStart(
                    otherTitle: "Server version too low, please upgrade!",
                    e: "Required Server Version: v0.2.0",
                  );
                }
                return ConversationList(
                  showArchivedChats: false,
                  showUnknownSenders: false,
                );
              } else {
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
    path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.ico']);
  } else if (Platform.isMacOS) {
    path = p.joinAll(['AppIcon']);
  } else {
    path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
  }

  // We first init the systray menu and then add the menu entries
  await systemTray.initSystemTray(title: "BlueBubbles", iconPath: path, toolTip: "BlueBubbles");

  final Menu menu = Menu();
  await menu.buildFrom(
    [
      MenuItemLabel(
        label: 'Open App',
        onClicked: (_) async {
          ls.open();
          await windowManager.show();
        },
      ),
      MenuItemLabel(
        label: 'Hide App',
        onClicked: (_) async {
          ls.close();
          await windowManager.hide();
        },
      ),
      MenuItemLabel(
        label: 'Close App',
        onClicked: (_) async {
          await windowManager.close();
        },
      ),
    ]
  );

  await systemTray.setContextMenu(menu);

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) async {
    switch (eventName) {
      case 'click':
        await windowManager.show();
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
