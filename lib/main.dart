import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:async_task/async_task_extension.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/wrappers/bb_annotated_region.dart';
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
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await StartupTasks.initStartupServices(isBubble: bubble);

    /* ----- RANDOM STUFF INITIALIZATION ----- */
    HttpOverrides.global = CustomHttpContext();
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
      Future.microtask(() => initializeDateFormatting());

      /* ----- MEDIAKIT INITIALIZATION ----- */
      MediaKit.ensureInitialized();

      /* ----- SPLASH SCREEN INITIALIZATION ----- */
      if (!SettingsSvc.settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
        runApp(MaterialApp(
            home: const SplashScreen(shouldNavigate: false),
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
          tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
        } catch (_) {}

        /* ----- MLKIT INITIALIZATION ----- */
        // Defer MLKit model check - not critical for startup
        Future.microtask(() async {
          if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
            EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
          }
        });
      }

      /* ----- DESKTOP SPECIFIC INITIALIZATION ----- */
      if (kIsDesktop) {
        /* ----- WINDOW INITIALIZATION ----- */
        await windowManager.ensureInitialized();
        await windowManager.setPreventClose(SettingsSvc.settings.closeToTray.value);
        await windowManager.setTitle('BlueBubbles');
        await Window.initialize();
        if (Platform.isWindows) {
          await Window.hideWindowControls();
        } else if (Platform.isLinux) {
          await windowManager.setTitleBarStyle(
              SettingsSvc.settings.useCustomTitleBar.value ? TitleBarStyle.hidden : TitleBarStyle.normal);
        }
        windowManager.addListener(DesktopWindowListener.instance);
        doWhenWindowReady(() async {
          await windowManager.setMinimumSize(const Size(300, 300));
          final List<Display> allDisplays = await ScreenRetriever.instance.getAllDisplays();
          Display primary = await ScreenRetriever.instance.getPrimaryDisplay();

          Size size = await windowManager.getSize();
          double width = PrefsSvc.i.getDouble("window-width") ?? size.width;
          double height = PrefsSvc.i.getDouble("window-height") ?? size.height;

          width = width.clamp(300, max(300, primary.size.width));
          height = height.clamp(300, max(300, primary.size.height));
          await windowManager.setSize(Size(width, height));
          await PrefsSvc.i.setDouble("window-width", width);
          await PrefsSvc.i.setDouble("window-height", height);

          double? savedX = PrefsSvc.i.getDouble("window-x");
          double? savedY = PrefsSvc.i.getDouble("window-y");

          // Check if the saved position is visible on any connected display.
          // The window must overlap each candidate display by at least 100x50px
          // so the title bar remains reachable. This also handles secondary
          // monitors that were disconnected since the last run — those positions
          // will no longer match any display and will gracefully fall back to
          // centering on the primary display.
          double posX;
          double posY;
          if (savedX != null &&
              savedY != null &&
              allDisplays.any((display) {
                final dx = display.visiblePosition?.dx ?? 0;
                final dy = display.visiblePosition?.dy ?? 0;
                final dw = display.visibleSize?.width ?? display.size.width;
                final dh = display.visibleSize?.height ?? display.size.height;
                return savedX < dx + dw - 100 &&
                    savedX + 100 > dx &&
                    savedY < dy + dh - 50 &&
                    savedY + 50 > dy;
              })) {
            posX = savedX;
            posY = savedY;
            await windowManager.setPosition(Offset(posX, posY), animate: true);
          } else {
            await windowManager.setAlignment(Alignment.center);
            Offset offset = await windowManager.getPosition();
            posX = offset.dx;
            posY = offset.dy;
          }
          await PrefsSvc.i.setDouble("window-x", posX);
          await PrefsSvc.i.setDouble("window-y", posY);

          await windowManager.setTitle('BlueBubbles');
          if (arguments.firstOrNull != "minimized") {
            await windowManager.show();
          } else {
            await windowManager.hide();
          }
          bool shouldAuthenticate = SettingsSvc.canAuthenticate && SettingsSvc.settings.shouldSecure.value;
          if (!shouldAuthenticate) {
            ChatsSvc.init();
            SocketSvc.init();
          }
        });

        /* ----- GIPHY API KEY INITIALIZATION ----- */
        await dotenv.load(fileName: '.env', isOptional: true);
      }

      /* ----- EMOJI FONT INITIALIZATION ----- */
      Future.microtask(() => FilesystemSvc.checkFont());
    } catch (e, s) {
      print(s.toString());
      Logger.error("Failure during app initialization!", error: e, trace: s);
      exception = e;
      stacktrace = s;
    }

    if (exception == null) {
      /* ----- THEME INITIALIZATION ----- */
      ThemeData light = ThemeStruct.getLightTheme().data;
      ThemeData dark = ThemeStruct.getDarkTheme().data;

      final pair = ThemeSvc.getStructsFromData(light, dark);
      light = pair.light;
      dark = pair.dark;

      runApp(MaterialApp(
          home: Main(
        lightTheme: light,
        darkTheme: dark,
      )));
    } else {
      runApp(FailureToStart(e: exception, s: stacktrace));
      throw Exception("$exception $stacktrace");
    }
  }, (dynamic error, StackTrace stackTrace) {
    print("Failure during app initialization: $error");
    print(stackTrace);
    Logger.error("Unhandled Exception", trace: stackTrace, error: error);
  });
}

class DesktopWindowListener extends WindowListener {
  DesktopWindowListener._();

  static final DesktopWindowListener instance = DesktopWindowListener._();

  @override
  void onWindowFocus() {
    LifecycleSvc.open();
  }

  @override
  void onWindowBlur() {
    LifecycleSvc.close();
  }

  @override
  void onWindowResized() async {
    Size size = await windowManager.getSize();
    await PrefsSvc.i.setDouble("window-width", size.width);
    await PrefsSvc.i.setDouble("window-height", size.height);
  }

  @override
  void onWindowMoved() async {
    Offset offset = await windowManager.getPosition();
    await PrefsSvc.i.setDouble("window-x", offset.dx);
    await PrefsSvc.i.setDouble("window-y", offset.dy);
  }

  @override
  void onWindowEvent(String eventName) async {
    if (SettingsSvc.settings.disableTrayIcon.value) return;
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
        navigatorKey: NavigationSvc.key,
        navigatorObservers: [routeObserver],
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          // Specifically for GNU/Linux & Android-x86 family, where touch isn't interpreted as a drag device by Flutter apparently.
          dragDevices: Platform.isLinux || Platform.isAndroid ? PointerDeviceKind.values.toSet() : null,
          // Prevent scrolling with multiple fingers accelerating the scrolling
          multitouchDragStrategy: MultitouchDragStrategy.latestPointer,
        ),
        home: const Home(),
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
                if (SettingsSvc.canAuthenticate && (!LifecycleSvc.isAlive || !StartupTasks.uiReady.isCompleted)) {
                  if (SettingsSvc.settings.shouldSecure.value) {
                    SecureApplicationProvider.of(context, listen: false)!.lock();
                    if (SettingsSvc.settings.securityLevel.value == SecurityLevel.locked_and_secured) {
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
                          persistAcrossBackgrounding: true,
                        )
                            .then((result) {
                          isAuthing = false;
                          if (result) {
                            SecureApplicationProvider.of(context, listen: false)!.authSuccess(unlock: true);
                            if (kIsDesktop) {
                              Future.delayed(Duration.zero, () {
                                ChatsSvc.init();
                                SocketSvc.init();
                              });
                            }
                          }
                        });
                      }
                      return Container(
                        color: context.theme.colorScheme.surface,
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
                                        persistAcrossBackgrounding: true,
                                      );
                                      if (didAuthenticate) {
                                        controller!.authSuccess(unlock: true);
                                        if (kIsDesktop) {
                                          Future.delayed(Duration.zero, () {
                                            ChatsSvc.init();
                                            SocketSvc.init();
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
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver, TrayListener {
  final ReceivePort port = ReceivePort();
  bool serverCompatible = true;
  bool fullyLoaded = false;

  @override
  void initState() {
    super.initState();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);

    /* ----- APP REFRESH LISTENER INITIALIZATION ----- */
    EventDispatcherSvc.stream.listen((event) {
      if (event.type == 'refresh-all') {
        setState(() {});
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      StartupTasks.uiReady.complete();

      if (!LifecycleSvc.isBubble && !kIsWeb && !kIsDesktop) {
        LifecycleSvc.createFakePort();
      }

      ErrorWidget.builder = (FlutterErrorDetails error) {
        Logger.error("An unexpected error occurred when rendering.", error: error.exception, trace: error.stack);
        return CustomErrorWidget(
          "An unexpected error occurred when rendering.",
        );
      };
      /* ----- SERVER VERSION CHECK ----- */
      if (kIsWeb && SettingsSvc.settings.finishedSetup.value) {
        final serverDetails = await SettingsSvc.getServerDetails();
        if (!serverDetails.minimumWebSupportedVersion) {
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
          Future<void> updateTaskbarBadge(int count) async {
            if (SettingsSvc.settings.hideTaskbarBadge.value) {
              await WindowsTaskbar.resetOverlayIcon();
              return;
            }

            if (count == 0) {
              await WindowsTaskbar.resetOverlayIcon();
            } else if (count <= 9) {
              await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-$count.ico'));
            } else {
              await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-10.ico'));
            }
          }

          /* ----- CONTACT IMAGE CACHE DELETION ----- */
          Directory temp = FilesystemSvc.appTemp;
          if (await temp.exists()) await temp.delete(recursive: true);

          /* ----- BADGE ICON LISTENER ----- */
          ChatsSvc.unreadCount.listen((count) async {
            await updateTaskbarBadge(count);
          });

          SettingsSvc.settings.hideTaskbarBadge.listen((_) async {
            await updateTaskbarBadge(ChatsSvc.unreadCount.value);
          });

          /* ----- WINDOW EFFECT INITIALIZATION ----- */
          EventDispatcherSvc.stream.listen((event) async {
            if (event.type == 'theme-update') {
              EasyDebounce.debounce('window-effect', const Duration(milliseconds: 500), () async {
                if (mounted) {
                  await WindowEffects.setEffect(color: context.theme.colorScheme.surface);
                }
              });
            }
          });

          Future(() => EventDispatcherSvc.emit("theme-update", null));
        }

        /* ----- SYSTEM TRAY INITIALIZATION ----- */
        if (!SettingsSvc.settings.disableTrayIcon.value) {
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
        }

        /* ----- NOTIFICATIONS INITIALIZATION ----- */
        await localNotifier.setup(appName: "BlueBubbles");
      }

      if (!SettingsSvc.settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      } else {
        if ((FilesystemSvc.androidInfo?.version.sdkInt ?? 0) >= 33) {
          Permission.notification.request();
        }
      }
    });
  }

  @override
  void onTrayIconMouseDown() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
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
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
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

      EventDispatcherSvc.emit("theme-update", null);
    }
  }

  /// Render
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: SettingsSvc.settings.immersiveMode.value
          ? Colors.transparent
          : context.theme.colorScheme.surface, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    return BBAnnotatedRegion(
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
              backgroundColor: context.theme.colorScheme.surface.themeOpacity(context),
              body: Builder(
                builder: (BuildContext context) {
                  if (SettingsSvc.settings.finishedSetup.value) {
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
                          child: kIsWeb || kIsDesktop ? const SetupView() : SplashScreen(shouldNavigate: fullyLoaded)),
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
