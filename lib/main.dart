import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/custom/custom_error_box.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
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
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:on_exit/init.dart';
import 'package:path/path.dart' show basename, join;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tray_manager/tray_manager.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

const databaseVersion = 4;
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
bool hasBadCert = false;

@pragma('vm:entry-point')
//ignore: prefer_void_to_null
Future<Null> main(List<String> arguments) async {
  await initApp(false, arguments);
}

@pragma('vm:entry-point')
// ignore: prefer_void_to_null
Future<Null> bubble() async {
  await initApp(true, []);
}

Future<void> checkInstanceLock() async {
  if (!kIsDesktop || !Platform.isLinux) return;
  Logger.debug("Starting process with PID $pid");

  final lockFile = File(join(fs.appDocDir.path, 'bluebubbles.lck'));
  final instanceFile = File(join(fs.appDocDir.path, '.instance'));
  onExit(() {
    if (lockFile.existsSync()) lockFile.deleteSync();
  });

  if (!lockFile.existsSync()) {
    lockFile.createSync();
  }
  if (!instanceFile.existsSync()) {
    instanceFile.createSync();
  }

  Logger.debug("Lockfile at ${lockFile.path}");
  String _pid = lockFile.readAsStringSync();
  String ps = Process.runSync('ps', ['-p', _pid]).stdout;
  if (kReleaseMode && "$pid" != _pid && ps.endsWith('bluebubbles\n')) {
    Logger.debug("Another instance is running. Sending foreground signal");
    instanceFile.openSync(mode: FileMode.write).closeSync();
    exit(0);
  }

  lockFile.writeAsStringSync("$pid");
  instanceFile.watch(events: FileSystemEvent.modify).listen((event) async {
    Logger.debug("Got Signal to go to foreground");
    doWhenWindowReady(() async {
      await windowManager.show();
      List<Tuple2<String, String>?> widAndNames = await (await Process.start('wmctrl', ['-pl']))
          .stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => line.replaceAll(RegExp(r"\s+"), " ").split(" "))
          .map((split) => split[2] == "$pid" ? Tuple2(split.first, split.last) : null)
          .where((tuple) => tuple != null)
          .toList();

      for (Tuple2<String, String>? window in widAndNames) {
        if (window?.item2 == "BlueBubbles") {
          Process.runSync('wmctrl', ['-iR', window!.item1]);
          break;
        }
      }
    });
  });
}

void performDatabaseMigrations({int? versionOverride}) {
  int version = versionOverride ?? ss.prefs.getInt('dbVersion') ?? (ss.settings.finishedSetup.value ? 1 : databaseVersion);
  if (version > databaseVersion) return;

  final Stopwatch s = Stopwatch();
  s.start();

  int nextVersion = version;
  Logger.debug("Performing database migration from version $version to $databaseVersion", tag: "DB-Migration");
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

      nextVersion = 2;
    // Version 3 modifies chat typing indicators and read receipts values to follow global setting initially
    case 3:
      final chats = chatBox.getAll();
      final papi = ss.settings.enablePrivateAPI.value;
      final typeGlobal = ss.settings.privateSendTypingIndicators.value;
      final readGlobal = ss.settings.privateMarkChatAsRead.value;
      for (Chat c in chats) {
        if (papi && readGlobal && !(c.autoSendReadReceipts ?? true)) {
          // dont do anything
        } else {
          c.autoSendReadReceipts = null;
        }
        if (papi && typeGlobal && !(c.autoSendTypingIndicators ?? true)) {
          // dont do anything
        } else {
          c.autoSendTypingIndicators = null;
        }
      }

      chatBox.putMany(chats);
      nextVersion = 3;
    // Version 4 saves FCM Data to the shared preferences for use in Tasker integration
    case 4:
      ss.getFcmData();
      ss.fcmData.save();
      nextVersion = 4;
  }

  if (nextVersion != version) {
    performDatabaseMigrations(versionOverride: nextVersion);
  }

  s.stop();
  Logger.info("Completed database migration in ${s.elapsedMilliseconds}ms", tag: "DB-Migration");
}

Future<void> initDatabaseMobile({bool? storeOpenStatus}) async {
  Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
  final isStoreOpen = storeOpenStatus ?? Store.isOpen(objectBoxDirectory.path);

  try {
    if (isStoreOpen) {
      Logger.info("Attempting to attach to an existing ObjectBox store...");
      store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
      Logger.info("Successfully attached to an existing ObjectBox store");
    } else {
      Logger.info("Opening new ObjectBox store from path: ${objectBoxDirectory.path}");
      store = await openStore(directory: objectBoxDirectory.path);
    }
  } catch (e, s) {
    Logger.error("Failed to open ObjectBox store!", error: e, trace: s);

    if (e.toString().contains("another store is still open using the same path")) {
      Logger.info("Retrying to attach to an existing ObjectBox store");
      await initDatabaseMobile(storeOpenStatus: true);
    }
  }
}

Future<void> initDatabaseDesktop() async {
  Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
  try {
    objectBoxDirectory.createSync(recursive: true);
    if (ss.prefs.getBool('use-custom-path') == true && ss.prefs.getString('custom-path') != null) {
      Directory oldCustom = Directory(join(ss.prefs.getString('custom-path')!, 'objectbox'));
      if (oldCustom.existsSync()) {
        Logger.info("Detected prior use of custom path option. Migrating...");
        copyDirectory(oldCustom, objectBoxDirectory);
      }
      await ss.prefs.remove('use-custom-path');
      await ss.prefs.remove('custom-path');
    }

    Logger.info("Opening ObjectBox store from path: ${objectBoxDirectory.path}");
    store = await openStore(directory: objectBoxDirectory.path);
  } catch (e, s) {
    if (Platform.isLinux) {
      Logger.debug("Another instance is probably running. Sending foreground signal");
      final instanceFile = File(join(fs.appDocDir.path, '.instance'));
      instanceFile.openSync(mode: FileMode.write).closeSync();
      exit(0);
    }

    Logger.error("Failed to initialize desktop database!", error: e, trace: s);
  }
}

Future<void> initDatabase() async {
  // Web doesn't use a database currently, so do not do anything
  if (kIsWeb) return;

  if (!kIsDesktop) {
    await initDatabaseMobile();
  } else {
    await initDatabaseDesktop();
  }

  try {
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

    if (!ss.settings.finishedSetup.value) {
      attachmentBox.removeAll();
      chatBox.removeAll();
      contactBox.removeAll();
      fcmDataBox.removeAll();
      handleBox.removeAll();
      messageBox.removeAll();
      themeBox.removeAll();
      themeEntryBox.removeAll();
      themeObjectBox.removeAll();
    }
  } catch (e, s) {
    Logger.error("Failed to setup ObjectBox boxes!", error: e, trace: s);
  }

  try {
    if (themeBox.isEmpty()) {
      await ss.prefs.setString("selected-dark", "OLED Dark");
      await ss.prefs.setString("selected-light", "Bright White");
      themeBox.putMany(ts.defaultThemes);
    }
  } catch (e, s) {
    Logger.error("Failed to seed themes!", error: e, trace: s);
  }

  try {
    performDatabaseMigrations();
  } catch (e, s) {
    Logger.error("Failed to perform database migrations!", error: e, trace: s);
  }

  storeStartup.complete();
}

//ignore: prefer_void_to_null
Future<Null> initApp(bool bubble, List<String> arguments) async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // First, initialize the filesystem service as it's used by other necessary services
      await fs.init();

      // Initialize the logger so we can start logging things immediately
      await Logger.init();

      // Check if another instance is running (Linux Only).
      // Automatically handled on Windows (I think)
      await checkInstanceLock();

      // Setup the settings service
      await ss.init();

      // The next thing we need to do is initialize the database.
      // If the database is not initialized, we cannot do anything.
      await initDatabase();

      // We then have to initialize all the services that the app will use.
      // Order matters here as some services may rely on others. For instance,
      // The MethodChannel service needs the database to be initialized to handle events.
      // The Lifecycle service needs the MethodChannel service to be initialized to send events.
      await mcs.init();
      await ls.init(isBubble: bubble);
      await ts.init();

      /* ----- RANDOM STUFF INITIALIZATION ----- */
      HttpOverrides.global = BadCertOverride();
      dynamic exception;
      StackTrace? stacktrace;

      FlutterError.onError = (details) {
        Logger.error("Rendering Error: ${details.exceptionAsString()}", error: details.exception, trace: details.stack);
      };

      try {
        /* ----- SERVICES INITIALIZATION POST OBJECTBOX ----- */
        await ss.prefs.setInt('dbVersion', databaseVersion);
        ss.getFcmData();
        if (!kIsWeb) {
          await cs.init();
        }
        await notif.init();
        await intents.init();
        if (!kIsDesktop) {
          chats.init();
          socket;
        }

        /* ----- DATE FORMATTING INITIALIZATION ----- */
        await initializeDateFormatting();

        /* ----- MEDIAKIT INITIALIZATION ----- */
        MediaKit.ensureInitialized();

        /* ----- SPLASH SCREEN INITIALIZATION ----- */
        if (!ss.settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
          runApp(MaterialApp(
              home: SplashScreen(shouldNavigate: false),
              theme: ThemeData(
                colorScheme: ColorScheme.fromSwatch(
                    backgroundColor:
                        PlatformDispatcher.instance.platformBrightness == Brightness.dark ? Colors.black : Colors.white),
              )));
        }

        /* ----- ANDROID SPECIFIC INITIALIZATION ----- */
        if (!kIsWeb && !kIsDesktop) {
          /* ----- TIME ZONE INITIALIZATION ----- */
          tz.initializeTimeZones();
          try {
            tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
          } catch (_) {}

          /* ----- MLKIT INITIALIZATION ----- */
          if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
            EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
          }
        }

        /* ----- DESKTOP SPECIFIC INITIALIZATION ----- */
        if (kIsDesktop) {
          /* ----- WINDOW INITIALIZATION ----- */
          await windowManager.ensureInitialized();
          await windowManager.setTitle('BlueBubbles');
          await Window.initialize();
          if (Platform.isWindows) {
            await Window.hideWindowControls();
          } else if (Platform.isLinux) {
            await windowManager
                .setTitleBarStyle(ss.settings.useCustomTitleBar.value ? TitleBarStyle.hidden : TitleBarStyle.normal);
          }
          windowManager.addListener(DesktopWindowListener.instance);
          doWhenWindowReady(() async {
            await windowManager.setMinimumSize(const Size(300, 300));
            Display primary = await ScreenRetriever.instance.getPrimaryDisplay();

            Size size = await windowManager.getSize();
            double width = ss.prefs.getDouble("window-width") ?? size.width;
            double height = ss.prefs.getDouble("window-height") ?? size.height;

            width = width.clamp(300, max(300, primary.size.width));
            height = height.clamp(300, max(300, primary.size.height));
            await windowManager.setSize(Size(width, height));
            await ss.prefs.setDouble("window-width", width);
            await ss.prefs.setDouble("window-height", height);

            await windowManager.setAlignment(Alignment.center);
            Offset offset = await windowManager.getPosition();
            double? posX = ss.prefs.getDouble("window-x") ?? offset.dx;
            double? posY = ss.prefs.getDouble("window-y") ?? offset.dy;

            posX = posX.clamp(0, max(0, primary.size.width - width));
            posY = posY.clamp(0, max(0, primary.size.height - height));
            await windowManager.setPosition(Offset(posX, posY), animate: true);
            await ss.prefs.setDouble("window-x", posX);
            await ss.prefs.setDouble("window-y", posY);

            await windowManager.setTitle('BlueBubbles');
            if (arguments.firstOrNull == "minimized") {
              await windowManager.hide();
            } else {
              await windowManager.show();
            }
            if (!(ss.canAuthenticate && ss.settings.shouldSecure.value)) {
              chats.init();
              socket;
            }
          });

          /* ----- GIPHY API KEY INITIALIZATION ----- */
          await dotenv.load(fileName: '.env', isOptional: true);
        }

        /* ----- EMOJI FONT INITIALIZATION ----- */
        fs.checkFont();
      } catch (e, s) {
        Logger.error("Failure during app initialization!", error: e, trace: s);
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
    },
    (dynamic error, StackTrace stackTrace) {
      Logger.error("Unhandled Exception", trace: stackTrace, error: error);
    }
  );
}

class BadCertOverride extends HttpOverrides {
  @override
  createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // If there is a bad certificate callback, override it if the host is part of
      // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        String serverUrl = sanitizeServerAddress() ?? "";
        if (host.startsWith("*")) {
          final regex = RegExp(
              "^((\\*|[\\w\\d]+(-[\\w\\d]+)*)\\.)*(${host.split(".").reversed.take(2).toList().reversed.join(".")})\$");
          hasBadCert = regex.hasMatch(serverUrl);
        } else {
          hasBadCert = serverUrl.endsWith(host);
        }
        return hasBadCert;
      };
  }
}

class DesktopWindowListener extends WindowListener {
  DesktopWindowListener._();

  static final DesktopWindowListener instance = DesktopWindowListener._();

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
    await ss.prefs.setDouble("window-width", size.width);
    await ss.prefs.setDouble("window-height", size.height);
  }

  @override
  void onWindowMoved() async {
    Offset offset = await windowManager.getPosition();
    await ss.prefs.setDouble("window-x", offset.dx);
    await ss.prefs.setDouble("window-y", offset.dy);
  }

  @override
  void onWindowEvent(String eventName) async {
    switch (eventName) {
      case "hide":
        await setSystemTrayContextMenu(windowHidden: true);
        break;
      case "show":
        await setSystemTrayContextMenu(windowHidden: false);
        break;
    }
  }
}

class DesktopTrayListener extends TrayListener {
  DesktopTrayListener._();

  static final DesktopTrayListener instance = DesktopTrayListener._();

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_app':
        await windowManager.show();
        break;
      case 'hide_app':
        await windowManager.hide();
        break;
      case 'close_app':
        await windowManager.close();
        break;
    }
  }
}

class Main extends StatelessWidget {
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  const Main({super.key, required this.lightTheme, required this.darkTheme});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme.copyWith(
          textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark:
          darkTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BlueBubbles',
        theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),
        darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),
        navigatorKey: ns.key,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          // Specifically for GNU/Linux & Android-x86 family, where touch isn't interpreted as a drag device by Flutter apparently.
          dragDevices: Platform.isLinux || Platform.isAndroid ? PointerDeviceKind.values.toSet() : null,
          // Prevent scrolling with multiple fingers accelerating the scrolling
          multitouchDragStrategy: MultitouchDragStrategy.latestPointer,
        ),
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
                return TitleBarWrapper(
                  child: SecureGate(
                    blurr: 5,
                    opacity: 0,
                    lockedBuilder: (context, controller) {
                      final localAuth = LocalAuthentication();
                      if (!isAuthing) {
                        isAuthing = true;
                        localAuth
                            .authenticate(
                                localizedReason: 'Please authenticate to unlock BlueBubbles',
                                options: const AuthenticationOptions(stickyAuth: true))
                            .then((result) {
                          isAuthing = false;
                          if (result) {
                            SecureApplicationProvider.of(context, listen: false)!.authSuccess(unlock: true);
                            if (kIsDesktop) {
                              Future.delayed(Duration.zero, () {
                                chats.init();
                                socket;
                              });
                            }
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
                                        width: 60,
                                        height: 60,
                                        child: Icon(Icons.lock_open, color: context.theme.colorScheme.onPrimary)),
                                    onTap: () async {
                                      final localAuth = LocalAuthentication();
                                      bool didAuthenticate = await localAuth.authenticate(
                                          localizedReason: 'Please authenticate to unlock BlueBubbles',
                                          options: const AuthenticationOptions(stickyAuth: true));
                                      if (didAuthenticate) {
                                        controller!.authSuccess(unlock: true);
                                        if (kIsDesktop) {
                                          Future.delayed(Duration.zero, () {
                                            chats.init();
                                            socket;
                                          });
                                        }
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
                  ),
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
  Home({super.key});

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
        Logger.error("An unexpected error occurred when rendering.", error: error.exception, trace: error.stack);
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

          /* ----- BADGE ICON LISTENER ----- */
          int count = 0;
          final unreadQuery = chatBox.query(Chat_.hasUnreadMessage.equals(true)).watch(triggerImmediately: true);
          unreadQuery.listen((Query<Chat> query) async {
            int c = query.count();
            if (count != c) {
              count = c;
              if (count == 0) {
                await WindowsTaskbar.resetOverlayIcon();
              } else if (count <= 9) {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-$count.ico'));
              } else {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-10.ico'));
              }
            }
          });

          /* ----- WINDOW EFFECT INITIALIZATION ----- */
          eventDispatcher.stream.listen((event) async {
            if (event.item1 == 'theme-update') {
              EasyDebounce.debounce('window-effect', const Duration(milliseconds: 500), () async {
                if (mounted) {
                  await WindowEffects.setEffect(color: context.theme.colorScheme.background);
                }
              });
            }
          });

          Future(() => eventDispatcher.emit("theme-update", null));
        }

        /* ----- SYSTEM TRAY INITIALIZATION ----- */
        await initSystemTray();
        trayManager.addListener(DesktopTrayListener.instance);

        /* ----- NOTIFICATIONS INITIALIZATION ----- */
        await localNotifier.setup(appName: "BlueBubbles");
      }

      if (!ss.settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      } else if ((fs.androidInfo?.version.sdkInt ?? 0) >= 33) {
        Permission.notification.request();
      }
    });
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(DesktopWindowListener.instance);
    trayManager.removeListener(DesktopTrayListener.instance);
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
          ? Colors.transparent
          : context.theme.colorScheme.background, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
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
                    return PopScope(
                      canPop: false,
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
  String path;
  if (Platform.isWindows) {
    path = 'assets/icon/icon.ico';
  } else if (isFlatpak) {
    path = 'app.bluebubbles.BlueBubbles';
  } else if (isSnap) {
    path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
  } else {
    path = 'assets/icon/icon.png';
  }

  // We first init the systray menu and then add the menu entries
  await trayManager.setIcon(path);
  if (Platform.isWindows) {
    await trayManager.setToolTip("BlueBubbles");
  }
  await setSystemTrayContextMenu(windowHidden: !appWindow.isVisible);
}

Future<void> setSystemTrayContextMenu({bool windowHidden = false}) async {
  await trayManager.setContextMenu(Menu(
    items: [
      MenuItem(label: windowHidden ? 'Show App' : 'Hide App', key: windowHidden ? 'show_app' : 'hide_app'),
      MenuItem.separator(),
      MenuItem(label: 'Close App', key: 'close_app'),
    ],
  ));
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
