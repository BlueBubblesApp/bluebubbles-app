import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/components/custom/custom_error_box.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/startup/failure_to_start.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/layouts/startup/splash_screen.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
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
import 'package:path/path.dart' show join;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:system_tray/system_tray.dart' as st;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tray_manager/tray_manager.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

bool isAuthing = false;
final systemTray = st.SystemTray();

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

//ignore: prefer_void_to_null
Future<Null> initApp(bool bubble, List<String> arguments) async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await StartupTasks.initStartupServices(isBubble: bubble);

      /* ----- RANDOM STUFF INITIALIZATION ----- */
      HttpOverrides.global = BadCertOverride();
      dynamic exception;
      StackTrace? stacktrace;

      FlutterError.onError = (details) {
        Logger.error("Rendering Error: ${details.exceptionAsString()}", error: details.exception, trace: details.stack);
      };

      try {
        // Once all the services are initialized, we need to perform some
        // startup tasks to ensure that the app has the information it needs.
        StartupTasks.onStartup().then((_) {
          Logger.info("Startup tasks completed");
        }).catchError((e, s) {
          Logger.error("Failed to complete startup tasks!", error: e, trace: s);
        });

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
          await windowManager.setPreventClose(ss.settings.closeToTray.value);
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
            if (arguments.firstOrNull != "minimized") {
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

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
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
                if (ss.canAuthenticate && (!ls.isAlive || !StartupTasks.uiReady.isCompleted)) {
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

class _HomeState extends OptimizedState<Home> with WidgetsBindingObserver, TrayListener {
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
      StartupTasks.uiReady.complete();

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
          GlobalChatService.unreadCount.listen((count) async {
            if (count == 0) {
                await WindowsTaskbar.resetOverlayIcon();
              } else if (count <= 9) {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-$count.ico'));
              } else {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-10.ico'));
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
        if (Platform.isWindows) {
          systemTray.registerSystemTrayEventHandler((eventName) {
            if (eventName == st.kSystemTrayEventClick) {
              onTrayIconMouseDown();
            } else if (eventName == st.kSystemTrayEventRightClick) {
              onTrayIconRightMouseDown();
            }
          });
        } else {
          trayManager.addListener(this);
        }

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
  void onTrayIconMouseDown() async {
    await windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() async {
    if (Platform.isWindows) {
      await systemTray.popUpContextMenu();
    } else {
      await trayManager.popUpContextMenu();
    }
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
        if (await windowManager.isPreventClose()) {
          await windowManager.setPreventClose(false);
        }
        await windowManager.close();
        break;
    }
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(DesktopWindowListener.instance);
    if (Platform.isLinux) {
      trayManager.removeListener(this);
    }
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

      eventDispatcher.emit("theme-update", null);
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
  if (Platform.isWindows) {
    await systemTray.initSystemTray(
      iconPath: 'assets/icon/icon.ico',
      toolTip: "BlueBubbles",
    );
  } else {
    String path;
    if (isFlatpak) {
      path = 'app.bluebubbles.BlueBubbles';
    } else if (isSnap) {
      path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
    } else {
      path = 'assets/icon/icon.png';
    }

    await trayManager.setIcon(path);
  }

  await setSystemTrayContextMenu(windowHidden: !appWindow.isVisible);
}

Future<void> setSystemTrayContextMenu({bool windowHidden = false}) async {
  if (Platform.isWindows) {
    st.Menu menu = st.Menu();
    menu.buildFrom([
      st.MenuItemLabel(
        label: windowHidden ? 'Show App' : 'Hide App',
        onClicked: (st.MenuItemBase menuItem) async {
          if (windowHidden) {
            await windowManager.show();
          } else {
            await windowManager.hide();
          }
        },
      ),
      st.MenuSeparator(),
      st.MenuItemLabel(
        label: 'Close App',
        onClicked: (_) async {
          if (await windowManager.isPreventClose()) {
            await windowManager.setPreventClose(false);
          }
          await windowManager.close();
        },
      ),
    ]);

    await systemTray.setContextMenu(menu);
  } else {
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(label: windowHidden ? 'Show App' : 'Hide App', key: windowHidden ? 'show_app' : 'hide_app'),
        MenuItem.separator(),
        MenuItem(label: 'Close App', key: 'close_app'),
      ],
    ));
  }
}
