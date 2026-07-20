import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:async_task/async_task_extension.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/components/custom/custom_error_box.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/media_kit_hot_restart_fix.dart'
    if (dart.library.html) 'package:bluebubbles/utils/media_kit_hot_restart_fix_web.dart';
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
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
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

    /* ----- DESKTOP NATIVE SPLASH STATUS ----- */
    // Pushes startup status to the native splash; detached once it's dismissed.
    void Function()? detachSplashStatus;
    if (kIsDesktop && !bubble && arguments.firstOrNull != "minimized") {
      const splashChannel = MethodChannel('bluebubbles/splash');
      bool titleBarApplied = false;
      void pushStatus() {
        splashChannel.invokeMethod('setStatus', StartupTasks.status.value).catchError((_) => null);

        final phase = StartupTasks.status.value;
        if (Platform.isLinux && !titleBarApplied && phase != "Starting..." && phase != "Loading settings...") {
          titleBarApplied = true;
          unawaited(() async {
            await windowManager.ensureInitialized();
            await windowManager.setTitleBarStyle(SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.native
                ? TitleBarStyle.normal
                : TitleBarStyle.hidden);
          }());
        }
      }

      StartupTasks.status.addListener(pushStatus);
      pushStatus();
      detachSplashStatus = () => StartupTasks.status.removeListener(pushStatus);
    }

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
      clearLeakedMpvWakeupCallbacks(); // must run first — see media_kit_hot_restart_fix.dart
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
          await windowManager.setTitleBarStyle(SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.native
              ? TitleBarStyle.normal
              : TitleBarStyle.hidden);
        }
        windowManager.addListener(DesktopWindowListener.instance);
        doWhenWindowReady(() async {
          await windowManager.setMinimumSize(const Size(300, 300));
          Display primary = await ScreenRetriever.instance.getPrimaryDisplay();

          double width = PrefsSvc.desktop.getWindowWidth() ?? 1280;
          double height = PrefsSvc.desktop.getWindowHeight() ?? 720;

          width = width.clamp(300, max(300, primary.size.width));
          height = height.clamp(300, max(300, primary.size.height));

          if (isWaylandSession) {
            // Wayland forbids a client from positioning itself, so only restore
            // the size and leave placement to the compositor.
            await windowManager.setSize(Size(width, height));
          } else {
            // Restore position otherwise
            final centered = await calcWindowPosition(Size(width, height), Alignment.center);
            double posX = PrefsSvc.desktop.getWindowX() ?? centered.dx;
            double posY = PrefsSvc.desktop.getWindowY() ?? centered.dy;
            posX = posX.clamp(0, max(0, primary.size.width - width));
            posY = posY.clamp(0, max(0, primary.size.height - height));
            await windowManager.setBounds(Rect.fromLTWH(posX, posY, width, height));
            await PrefsSvc.desktop.setWindowOffsets(x: posX, y: posY);
          }
          await PrefsSvc.desktop.setWindowDimensions(width: width, height: height);

          await windowManager.setTitle('BlueBubbles');
          if (arguments.firstOrNull != "minimized") {
            await windowManager.show();
          } else {
            await windowManager.hide();
          }
          try {
            await const MethodChannel('bluebubbles/splash').invokeMethod('closeSplash');
          } catch (_) {}
          detachSplashStatus?.call();
          unawaited(ThemeSvc.initDynamicColorsDeferred()); // Linux: deferred past splash
          bool shouldAuthenticate =
              !Platform.isLinux && SettingsSvc.canAuthenticate && SettingsSvc.settings.shouldSecure.value;
          if (!shouldAuthenticate) {
            ChatsSvc.init();
            SocketSvc.init();
          }
        });
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
        savedThemeMode: await AdaptiveTheme.getThemeMode(),
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

bool get isWaylandSession =>
    Platform.isLinux &&
    (Platform.environment['XDG_SESSION_TYPE'] == 'wayland' || Platform.environment.containsKey('WAYLAND_DISPLAY'));

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
    await PrefsSvc.desktop.setWindowDimensions(width: size.width, height: size.height);
  }

  @override
  void onWindowMoved() async {
    Offset offset = await windowManager.getPosition();
    await PrefsSvc.desktop.setWindowOffsets(x: offset.dx, y: offset.dy);
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
    } else if (Platform.isLinux) {
      exit(0);
    }
  }
}

class Main extends StatelessWidget {
  final ThemeData darkTheme;
  final ThemeData lightTheme;
  final AdaptiveThemeMode? savedThemeMode;

  const Main({super.key, required this.lightTheme, required this.darkTheme, this.savedThemeMode});

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme.copyWith(
          textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark:
          darkTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),
      initial: savedThemeMode ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BlueBubbles',
        theme: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0),
          dialogTheme: DialogThemeData(
            barrierColor: theme.colorScheme.shadow.withValues(alpha: 0.6),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        darkTheme: darkTheme.copyWith(
          appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0),
          dialogTheme: DialogThemeData(
            barrierColor: darkTheme.colorScheme.shadow.withValues(alpha: 0.6),
            backgroundColor: darkTheme.colorScheme.surfaceContainerHighest,
          ),
        ),
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
          // secure_application has no Linux implementation; mounting it (and the
          // SecureGate below) throws MissingPluginException on every lifecycle
          // event, which breaks window close/hide once the app is past setup.
          // Bypass the secure wrapper entirely on Linux.
          child: Platform.isLinux
              ? TitleBarWrapper(child: child ?? Container())
              : SecureApplication(
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
                                  if (!context.mounted) return;
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
        final serverDetails = SettingsSvc.getServerDetails();
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
          /* ----- CONTACT IMAGE CACHE DELETION ----- */
          Directory temp = FilesystemSvc.appTemp;
          if (await temp.exists()) await temp.delete(recursive: true);

          /* ----- BADGE ICON LISTENER ----- */
          Future<void> updateBadge(int count) async {
            try {
              if (count == 0 || !SettingsSvc.settings.windowsTaskbarBadge.value) {
                await WindowsTaskbar.resetOverlayIcon();
              } else if (count <= 9) {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-$count.ico'));
              } else {
                await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/badge-10.ico'));
              }
            } catch (_) {}
          }

          unawaited(updateBadge(ChatsSvc.unreadCount.value));
          ChatsSvc.unreadCount.listen(updateBadge);

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
    await showAndFocusWindow();
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
        await showAndFocusWindow();
        break;
      case 'hide_app':
        await windowManager.hide();
        break;
      case 'close_app':
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
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
    return Actions(
      actions: {
        OpenSettingsIntent: OpenSettingsAction(context),
        OpenNewChatCreatorIntent: OpenNewChatCreatorAction(context),
        OpenSearchIntent: OpenSearchAction(context),
        OpenNextChatIntent: OpenNextChatAction(context),
        OpenPreviousChatIntent: OpenPreviousChatAction(context),
        StartIncrementalSyncIntent: StartIncrementalSyncAction(),
        GoBackIntent: GoBackAction(context),
      },
      child: Obx(() => BBScaffold(
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
            await showAndFocusWindow();
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
