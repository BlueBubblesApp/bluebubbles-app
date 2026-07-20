import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/isolates/incremental_sync_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:on_exit/init.dart';
import 'package:app_install_date/app_install_date.dart';
import 'package:path/path.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get_it/get_it.dart';

class WindowEntry {
  final String id;
  final String name;

  const WindowEntry(this.id, this.name);
}

class StartupTasks {
  static final Completer<void> uiReady = Completer<void>();

  /// User-facing description of the current startup phase, surfaced by the
  /// desktop splash screen while services initialize. Updated by
  /// [initStartupServices] (main isolate only — isolate init paths don't drive UI).
  static final ValueNotifier<String> status = ValueNotifier<String>("Starting...");

  static Future<void> waitForUI() async {
    await uiReady.future;
  }

  static Future<void> setSplashStatus(String value) async {
    status.value = value;
    if (kIsDesktop) await Future.delayed(Duration.zero);
  }

  static Completer<void> _preRegisterInteropServices({
    required bool headless,
    required bool isBubble,
    BinaryMessenger? binaryMessenger,
  }) {
    final interopReady = Completer<void>();
    Logger.info("Pre-registering LifecycleService, NotificationsService, and MethodChannelService...");

    GetIt.I.registerSingletonAsync<LifecycleService>(() async {
      await interopReady.future;
      final lifecycleService = LifecycleService();
      await lifecycleService.init(headless: headless, isBubble: isBubble);
      return lifecycleService;
    });
    GetIt.I.registerSingletonAsync<NotificationsService>(() async {
      await interopReady.future;
      final notificationsService = NotificationsService();
      await notificationsService.init(headless: headless);
      return notificationsService;
    });
    GetIt.I.registerSingletonAsync<MethodChannelService>(() async {
      await interopReady.future;
      final channelService = MethodChannelService();
      await channelService.init(headless: headless, isBubble: isBubble, binaryMessenger: binaryMessenger);
      return channelService;
    });

    return interopReady;
  }

  static Future<void> _initCoreServices({required bool headless}) async {
    debugPrint("Registering FilesystemService...");
    GetIt.I.registerSingletonAsync<FilesystemService>(() async {
      final fsService = FilesystemService();
      await fsService.init(headless: headless);
      return fsService;
    });
    await GetIt.I.isReady<FilesystemService>();
    debugPrint("FilesystemService ready");

    debugPrint("Registering SharedPreferencesService...");
    GetIt.I.registerSingletonAsync<SharedPreferencesService>(() async {
      final prefsService = SharedPreferencesService();
      await prefsService.init();
      return prefsService;
    });
    await GetIt.I.isReady<SharedPreferencesService>();
    debugPrint("SharedPreferencesService ready");

    debugPrint("Registering SettingsService...");
    GetIt.I.registerSingletonAsync<SettingsService>(() async {
      final settingsService = SettingsService();
      await settingsService.init(headless: headless);
      return settingsService;
    });
    await GetIt.I.isReady<SettingsService>();
    debugPrint("SettingsService ready");

    debugPrint("Registering BaseLogger...");
    GetIt.I.registerSingletonAsync<BaseLogger>(() async {
      final logService = BaseLogger();
      await logService.init();
      return logService;
    });
    await GetIt.I.isReady<BaseLogger>();
    Logger.info("BaseLogger ready - switching to Logger for remaining logs");
  }

  static Future<void> _initContactHandleChats({required bool headless}) async {
    Logger.info("Registering ContactServiceV2...");
    GetIt.I.registerSingletonAsync<ContactServiceV2>(() async {
      final contactServiceV2 = ContactServiceV2();
      await contactServiceV2.init(headless: headless);
      return contactServiceV2;
    });
    await GetIt.I.isReady<ContactServiceV2>();
    Logger.info("ContactServiceV2 ready");

    Logger.info("Registering HandleService...");
    GetIt.I.registerSingleton<HandleService>(HandleService());
    HandleSvc.init();

    Logger.info("Registering ChatsService...");
    GetIt.I.registerSingleton<ChatsService>(ChatsService());
    await ChatsSvc.init(headless: headless);
    Logger.info("ChatsService ready");
  }

  static Future<void> _initHttpService() async {
    Logger.info("Registering HttpService...");
    GetIt.I.registerSingleton<HttpService>(HttpService());
    await HttpSvc.init();
  }

  static Future<void> _waitForInterop({
    bool lifecycle = false,
    bool notifications = false,
    bool methodChannel = false,
  }) async {
    if (lifecycle) {
      Logger.info("Waiting for LifecycleService...");
      await GetIt.I.isReady<LifecycleService>();
    }
    if (notifications) {
      Logger.info("Waiting for NotificationsService...");
      await GetIt.I.isReady<NotificationsService>();
      Logger.info("NotificationsService ready");
    }
    if (methodChannel) {
      Logger.info("Waiting for MethodChannelService...");
      await GetIt.I.isReady<MethodChannelService>();
      Logger.info("MethodChannelService ready");
    }
  }

  static Future<void> initStartupServices({bool isBubble = false}) async {
    debugPrint("Initializing startup services...");
    await setSplashStatus("Loading settings...");
    await _initCoreServices(headless: false);

    final startupInteropReady = _preRegisterInteropServices(
      headless: false,
      isBubble: isBubble,
    );

    // Check if another instance is running (Linux Only).
    // Automatically handled on Windows (I think)
    Logger.info("Checking instance lock...");
    await StartupTasks.checkInstanceLock();

    // The next thing we need to do is initialize the database.
    // If the database is not initialized, we cannot do anything.
    Logger.info("Initializing database...");
    await setSplashStatus("Opening database...");
    await Database.init();
    Logger.info("Database initialized");
    startupInteropReady.complete();

    await setSplashStatus("Starting services...");

    // Register the global isolate
    Logger.info("Registering isolates...");
    GetIt.I.registerSingleton<GlobalIsolate>(GlobalIsolate());
    NetworkTasks.registerIsolate(GetIt.I<GlobalIsolate>());
    GetIt.I.registerSingleton<IncrementalSyncIsolate>(IncrementalSyncIsolate());
    NetworkTasks.registerIsolate(GetIt.I<IncrementalSyncIsolate>());

    // Load FCM data into settings from the database
    // We only need to do this for the main startup
    Logger.info("Loading FCM data...");
    SettingsSvc.loadFcmDataFromDatabase();

    await _initHttpService();
    await _waitForInterop(lifecycle: true);

    Logger.info("Registering IncomingMessageHandler...");
    GetIt.I.registerSingleton<IncomingMessageHandler>(
      IncomingMessageHandler(),
      dispose: (svc) => svc.dispose(),
    );

    // We then have to initialize all the services that the app will use.
    // Order matters here as some services may rely on others. For instance,
    // The MethodChannel service needs the database to be initialized to handle events.
    // The Lifecycle service needs the MethodChannel service to be initialized to send events.

    await _waitForInterop(methodChannel: true);

    Logger.info("Registering CloudMessagingService...");
    GetIt.I.registerSingleton<CloudMessagingService>(CloudMessagingService());

    Logger.info("Registering ContactServiceV2...");
    GetIt.I.registerSingletonAsync<ContactServiceV2>(() async {
      final contactServiceV2 = ContactServiceV2();
      await contactServiceV2.init();
      return contactServiceV2;
    });

    Logger.info("Registering IntentsService, SyncService, and ThemesService...");
    GetIt.I.registerSingleton<IntentsService>(IntentsService());
    GetIt.I.registerSingleton<SyncService>(SyncService());
    GetIt.I.registerSingleton<ThemesService>(ThemesService());

    // Parallelize independent services for faster startup
    Logger.info("Waiting for services to be ready...");
    await setSplashStatus("Loading contacts...");
    await Future.wait([
      ThemeSvc.init(),
      IntentsSvc.init(),
      GetIt.I.isReady<ContactServiceV2>(),
    ]);
    Logger.info("All parallel services ready");

    Logger.info("Registering NavigatorService...");
    GetIt.I.registerSingleton<NavigatorService>(NavigatorService());

    // Do not init here. We will init after authentication
    Logger.info("Registering HandleService...");
    GetIt.I.registerSingleton<HandleService>(HandleService());
    HandleSvc.init();

    Logger.info("Registering ChatsService, SocketService, and NotificationsService...");
    await setSplashStatus("Loading chats...");
    GetIt.I.registerSingleton<ChatsService>(ChatsService());
    GetIt.I.registerSingleton<TypingIndicatorService>(TypingIndicatorService());
    GetIt.I.registerSingleton<SocketService>(SocketService());
    await _waitForInterop(notifications: true);

    GetIt.I.registerSingleton<EventDispatcher>(EventDispatcher());

    Logger.info("Registering OutgoingMessageHandler...");
    GetIt.I.registerSingleton<OutgoingMessageHandler>(
      OutgoingMessageHandler(),
      dispose: (svc) => svc.dispose(),
    );

    await setSplashStatus("Finishing up...");
    Logger.info(
        "Startup services initialization complete! Running localhost detection then starting incremental sync...");

    // Don't use the global isolate on startup as it'll likely cause a crash
    // if there is no network connection. The cause is not 100% known, but it likely
    // has to do with processing pressure, stale ports, or port binding exhaustion.
    unawaited(NetworkTasks.detectLocalhost().then((_) => SyncSvc.startIncrementalSync()));
  }

  static Future<void> initGlobalIsolateServices(RootIsolateToken? rootIsolateToken) async {
    debugPrint("Initializing isolate services...");

    BinaryMessenger? messenger;
    if (rootIsolateToken != null) {
      debugPrint("Initializing Background Isolate Binary Messenger");
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      messenger = BackgroundIsolateBinaryMessenger.instance;
    }

    await _initCoreServices(headless: true);

    final globalInteropReady = _preRegisterInteropServices(
      headless: true,
      isBubble: false,
      binaryMessenger: messenger,
    );

    Logger.info("Initializing database...");
    await Database.init();
    Logger.info("Database initialized");
    globalInteropReady.complete();

    await _initContactHandleChats(headless: true);
    await _initHttpService();
    await _waitForInterop(methodChannel: true);

    Logger.info("Global isolate services initialization complete");
  }

  /// Initialize only the services required for sync operations (lighter than full global isolate)
  static Future<void> initSyncIsolateServices(RootIsolateToken? rootIsolateToken) async {
    debugPrint("Initializing sync isolate services...");

    BinaryMessenger? messenger;
    if (rootIsolateToken != null) {
      debugPrint("Initializing Background Isolate Binary Messenger");
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      messenger = BackgroundIsolateBinaryMessenger.instance;
    }

    await _initCoreServices(headless: true);

    final syncInteropReady = _preRegisterInteropServices(
      headless: true,
      isBubble: false,
      binaryMessenger: messenger,
    );

    Logger.info("Initializing database...");
    await Database.init();
    Logger.info("Database initialized");
    syncInteropReady.complete();

    await _initContactHandleChats(headless: true);
    await _initHttpService();
    Logger.info("HttpService ready");

    Logger.info("Sync isolate services initialization complete");
  }

  static Future<void> initBackgroundIsolate() async {
    debugPrint("Initializing background isolate services...");

    // When the DartWorker spins up the isolate, the Isolate.current.debugName == "main".
    // While this might be the only flutter engine/instance running, it's still not technically the "main" isolate.
    // So we set isIsolateOverride to true to force isIsolate to return true.
    isIsolateOverride = true;
    // Override the log label so entries are identifiable as coming from the DartWorker.
    isolateNameOverride = 'DartWorker';

    await _initCoreServices(headless: true);

    final backgroundInteropReady = _preRegisterInteropServices(
      headless: true,
      isBubble: false,
    );

    Logger.info("Initializing database...");
    await Database.init();
    Logger.info("Database initialized");
    backgroundInteropReady.complete();

    await _initContactHandleChats(headless: true);
    await _waitForInterop(lifecycle: true);
    await _initHttpService();
    await _waitForInterop(notifications: true);

    Logger.info("Registering IncomingMessageHandler...");
    GetIt.I.registerSingleton<IncomingMessageHandler>(
      IncomingMessageHandler(),
      dispose: (svc) => svc.dispose(),
    );

    await _waitForInterop(methodChannel: true);

    Logger.info("Background isolate services initialization complete");
  }

  static Future<void> onStartup() async {
    Logger.info("Running onStartup tasks...");

    if (!SettingsSvc.settings.finishedSetup.value) {
      Logger.info("Setup not finished, skipping onStartup tasks");
      return;
    }

    if (!kIsDesktop) {
      Logger.info("Initializing ChatsService and SocketService...");
      ChatsSvc.init(headless: false);
      SocketSvc.init();
    }

    // Refresh server details in the background via the GlobalIsolate.
    // Error handling is inside refreshServerDetails(); no need to catch here.
    Logger.info("Refreshing server details in background...");
    unawaited(SettingsSvc.refreshServerDetails());

    // Only register FCM device on startup
    // Don't await. Let this happen in background
    Logger.info("Registering FCM device in background...");
    FirebaseSvc.registerDevice().catchError((e, s) {
      Logger.warn("Failed to register FCM device on startup!", error: e, trace: s);
      showToast("Failed to register FCM device!", isError: true);
      return null; // Return null on error
    });

    // We don't need to check for updates immediately, so delay it so other
    // code has a chance to run and we don't block the UI thread.
    Logger.info("Scheduling update checks for 30 seconds from now...");
    Future.delayed(const Duration(seconds: 30), () {
      Logger.info("Running scheduled update checks...");
      try {
        SettingsSvc.checkServerUpdate();
      } catch (ex, stack) {
        Logger.warn("Failed to check for server update!", error: ex, trace: stack);
      }

      try {
        SettingsSvc.checkClientUpdate();
      } catch (ex, stack) {
        Logger.warn("Failed to check for client update!", error: ex, trace: stack);
      }
    });

    Logger.info("Updating share targets...");
    await ChatsSvc.updateShareTargets();
    Logger.info("Share targets updated");

    // Check if we need to request a review
    if (Platform.isAndroid) {
      Logger.info("Scheduling review flow check for 1 minute from now...");
      Future.delayed(const Duration(minutes: 1), () async {
        await reviewFlow();
      });
    }

    Logger.info("onStartup tasks complete");
  }

  static Future<void> onAppResume() async {
    final LifecycleService? lifecycle =
        (GetIt.I.isRegistered<LifecycleService>() && GetIt.I.isReadySync<LifecycleService>())
            ? GetIt.I<LifecycleService>()
            : null;

    if (GetIt.I.isRegistered<ChatsService>()) {
      // Observer is permanently registered in init() and should never be removed
      if (!kIsDesktop || lifecycle?.wasActiveAliveBefore != false) {
        ChatsSvc.setActiveToAlive();
      }

      final activeChat = ChatsSvc.activeChat;
      if (activeChat != null) {
        // Skip marking the active chat as read when we know a notification-tap
        // is about to redirect us to a *different* chat.  pendingOpenChatGuid is
        // set synchronously in IntentsService.openChat before the first await, so
        // it is always visible here even though we are inside an async callback.
        final pendingGuid = (!kIsWeb && !kIsDesktop && GetIt.I.isRegistered<IntentsService>())
            ? GetIt.I<IntentsService>().pendingOpenChatGuid
            : null;
        final redirectingAway = pendingGuid != null && pendingGuid != activeChat.chat.guid;
        if (!redirectingAway) {
          ChatsSvc.setChatHasUnread(activeChat.chat, false);
        }

        // On desktop, always restore focus when the app is resumed (window regains focus).
        // On mobile, only refocus if the user has auto-open keyboard enabled AND the
        // conversation view is the active route (not obscured by ConversationDetails etc.).
        ConversationViewController _cvc = cvc(activeChat.chat);
        if (!_cvc.showingOverlays && !_cvc.showingSubRoute && _cvc.editing.isEmpty) {
          if (kIsDesktop || SettingsSvc.settings.autoOpenKeyboard.value) {
            _cvc.lastFocusedNode.requestFocus();
          } else if (_cvc.lastFocusedNode.hasFocus) {
            // The field keeps its focus across a background/resume cycle, but
            // the Android engine fails to restore the keyboard on resume: the
            // OS shows it briefly, then the engine's input-connection restart
            // dismisses it without notifying the framework, so focus and
            // viewInsets are left as if the keyboard were still open (blank
            // reserved space). Re-show it once the restart settles so the
            // keyboard comes back exactly as the user left it.
            //
            // Workaround for https://github.com/flutter/flutter/issues/52599 —
            // once the engine fix (https://github.com/flutter/flutter/pull/187778)
            // ships in the Flutter version we build with, this block becomes a
            // no-op and can be removed.
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_cvc.lastFocusedNode.hasFocus && !_cvc.showingOverlays && !_cvc.showingSubRoute) {
                SystemChannels.textInput.invokeMethod('TextInput.show');
              }
            });
          }
        }
      }
    }

    if (HttpSvc.originOverride == null && SettingsSvc.settings.localhostPort.value != null) {
      await NetworkTasks.detectLocalhost();
    }

    // Flush any contact sync deferred while the app was backgrounded
    // (contact change events are queued instead of synced while cached).
    if (GetIt.I.isRegistered<ContactServiceV2>() && GetIt.I.isReadySync<ContactServiceV2>()) {
      unawaited(ContactsSvcV2.runPendingContactSync());
    }

    // On app resume, use the global isolate so it's ready for other tasks.
    if (GetIt.I.isRegistered<SyncService>()) {
      if (!Platform.isAndroid) {
        unawaited(SyncSvc.startIncrementalSync(useGlobalIsolate: true));
      } else if (lifecycle == null ||
          !lifecycle.hasResumed ||
          // wasBackgrounded (paused/detached, NOT hidden): sync only when the user
          // actually left the app — not when resuming from an in-app overlay like
          // the share sheet, which hides the activity without leaving the app.
          (lifecycle.currentState == AppLifecycleState.resumed && lifecycle.wasBackgrounded)) {
        unawaited(SyncSvc.startIncrementalSync(useGlobalIsolate: true));
      }
    }

    if (Platform.isAndroid) {
      if (!(lifecycle?.isBubble ?? false)) {
        lifecycle?.createFakePort();
      }

      // On Android, always restart the socket rather than just reconnecting.
      // Some OEMs (e.g. Samsung One UI) fire lifecycle events that skip `paused`,
      // meaning `disconnect()` is never called and `state` stays `connected` even
      // though the underlying TCP connection may be stale after a network change.
      // `restartSocket()` disposes the old socket and builds a fresh one, which is
      // reliable regardless of what lifecycle sequence the device sent.
      SocketSvc.restartSocket();
    }

    if (kIsDesktop && lifecycle != null) {
      lifecycle.windowFocused = true;
    }
  }

  static Future<void> checkInstanceLock() async {
    if (!kIsDesktop || !Platform.isLinux) return;
    Logger.debug("Starting process with PID $pid");

    final lockFile = File(join(FilesystemSvc.appDocDir.path, 'bluebubbles.lck'));
    final instanceFile = File(join(FilesystemSvc.appDocDir.path, '.instance'));
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
        List<WindowEntry?> widAndNames = await (await Process.start('wmctrl', ['-pl']))
            .stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map((line) => line.replaceAll(RegExp(r"\s+"), " ").split(" "))
            .map((split) => split[2] == "$pid" ? WindowEntry(split.first, split.last) : null)
            .where((entry) => entry != null)
            .toList();

        for (WindowEntry? window in widAndNames) {
          if (window?.name == "BlueBubbles") {
            Process.runSync('wmctrl', ['-iR', window!.id]);
            break;
          }
        }
      });
    });
  }
}

Future<void> reviewFlow() async {
  if (!LifecycleSvc.isAlive) return;
  Logger.info('Checking if we should request a review');

  try {
    DateTime sinceDate = await AppInstallDate().installDate;
    int lastReviewRequest = SettingsSvc.settings.lastReviewRequestTimestamp.value;
    if (lastReviewRequest > 0) {
      sinceDate = DateTime.fromMillisecondsSinceEpoch(lastReviewRequest);
    }

    final DateTime now = DateTime.now();
    final int days = now.difference(sinceDate).inDays;

    // If the app has been installed for 30 days, request a review
    // And if the user has not been asked for a review ever.
    // If the user has already been asked, ask again after 90 days
    if ((lastReviewRequest == 0 && days >= 30) || (lastReviewRequest > 0 && days >= 90)) {
      SettingsSvc.settings.lastReviewRequestTimestamp.value = now.millisecondsSinceEpoch;
      await SettingsSvc.settings.saveOneAsync("lastReviewRequestTimestamp");
      await requestReview();
    } else {
      Logger.info('Not requesting review, days since install/last request: $days');
    }
  } catch (e, st) {
    Logger.warn("Failed to request app review", error: e, trace: st);
  }
}

Future<void> requestReview() async {
  Logger.info('Requesting in app review!');
  final InAppReview inAppReview = InAppReview.instance;
  if (await inAppReview.isAvailable()) {
    await inAppReview.requestReview();
  }
}
