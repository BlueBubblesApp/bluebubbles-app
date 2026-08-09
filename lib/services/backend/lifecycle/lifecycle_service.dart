import 'dart:async';
import 'dart:isolate';
import 'dart:ui' hide window;

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';

import 'package:universal_html/html.dart' hide Platform;
import 'dart:io' show Platform;
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
LifecycleService get LifecycleSvc => GetIt.I<LifecycleService>();

class LifecycleService with WidgetsBindingObserver {
  bool isBubble = false;
  bool headless = false;
  bool windowFocused = true;
  bool? wasActiveAliveBefore;

  bool get isAlive {
    if (kIsWeb) return !(window.document.hidden ?? false);
    if (kIsDesktop) return windowFocused;
    // Headless isolates may not have a widgets binding (e.g. the GlobalIsolate),
    // where touching WidgetsBinding.instance throws — rely on the port marker only.
    if (headless) return IsolateNameServer.lookupPortByName('bg_isolate') != null;
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
        IsolateNameServer.lookupPortByName('bg_isolate') != null;
  }

  AppLifecycleState? get currentState => WidgetsBinding.instance.lifecycleState;

  List<AppLifecycleState> statesSinceLastResume = [];

  bool get wasPaused => statesSinceLastResume.contains(AppLifecycleState.paused);
  bool get wasHidden =>
      statesSinceLastResume.contains(AppLifecycleState.inactive) ||
      statesSinceLastResume.contains(AppLifecycleState.detached);
  bool get hasResumed => statesSinceLastResume.contains(AppLifecycleState.resumed);

  /// Whether the app was genuinely backgrounded since the last resume — sent to
  /// the app switcher or home screen (`paused`), or the activity was destroyed
  /// (`detached`). Deliberately does NOT count `hidden`: overlays launched from
  /// within the app (share sheet, file picker, etc.) hide the activity without
  /// the user ever leaving it, and resuming from those should not be treated as
  /// a return from the background.
  bool get wasBackgrounded =>
      statesSinceLastResume.contains(AppLifecycleState.paused) ||
      statesSinceLastResume.contains(AppLifecycleState.detached);

  Future<void> init({bool headless = false, bool isBubble = false}) async {
    Logger.debug("Initializing LifecycleService${headless ? " in headless mode" : ""}");

    if (!headless) {
      WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.addObserver(this);
    }

    this.headless = headless;
    this.isBubble = isBubble;

    unawaited(handleForegroundService(AppLifecycleState.resumed));
    Logger.debug("LifecycleService initialized");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (headless) return;
    Logger.debug("App State changed to $state");

    // If the current state is resume, and we've already had a resume, clear states from before the last resume
    if (state == AppLifecycleState.resumed && statesSinceLastResume.contains(AppLifecycleState.resumed)) {
      // Remove all states up to and including the last resume
      final lastResumeIndex = statesSinceLastResume.lastIndexOf(AppLifecycleState.resumed);
      statesSinceLastResume.removeRange(0, lastResumeIndex + 1);
    }

    // Add the new state
    statesSinceLastResume.add(state);

    if (state == AppLifecycleState.resumed) {
      // If we resumed before the pause-initiated isolate drain finished, cancel
      // it so foreground sends/receives aren't rejected (Android-only drain).
      if (Platform.isAndroid && GetIt.I.isRegistered<GlobalIsolate>()) {
        GetIt.I<GlobalIsolate>().cancelDrain();
      }

      // Restore active-chat liveness immediately to avoid a race where
      // incoming messages are processed while lifecycle is already resumed
      // but chat state is still marked dead from the previous close().
      // This also happens in the `open -> StartupTasks.onAppResume` flow.
      // We still want to do it here to avoid any race conditions.
      if (GetIt.I.isRegistered<ChatsService>()) {
        if (!kIsDesktop || wasActiveAliveBefore != false) {
          ChatsSvc.setActiveToAlive();
        }
      }

      await Database.waitForInit();

      if (GetIt.I.isRegistered<SocketService>()) {
        GetIt.I<SocketService>().resetScheduledRestartBackoff(cancelPendingTimer: true);
      }

      open();
    } else if (state != AppLifecycleState.inactive) {
      if (isBubble) {
        closeBubble();
      } else {
        unawaited(close(triggerState: state));
      }
    }

    unawaited(handleForegroundService(state));
  }

  Future<void> handleForegroundService(AppLifecycleState state) async {
    // If an isolate is invoking this, we don't want to start/stop the foreground service.
    // It should already be running. We don't need to stop it because the socket service
    // is not started when in headless mode.
    if (headless) return;

    // Don't handle foreground service for inactive/hidden states
    if ([AppLifecycleState.inactive, AppLifecycleState.hidden].contains(state)) return;

    // Read live from the reactive settings value so toggling the setting during
    // a session takes effect immediately without requiring an app restart.
    if (Platform.isAndroid && SettingsSvc.settings.keepAppAlive.value) {
      // We only want the foreground service to run when the app is not active
      if (state == AppLifecycleState.resumed) {
        Logger.info(tag: "LifecycleService", "Stopping foreground service");
        if (GetIt.I.isRegistered<MethodChannelService>()) {
          await GetIt.I.isReady<MethodChannelService>();
          unawaited(GetIt.I<MethodChannelService>().actions.stopForegroundService());
        }
      } else if ([AppLifecycleState.paused, AppLifecycleState.detached].contains(state)) {
        Logger.info(tag: "LifecycleService", "Starting foreground service");
        if (GetIt.I.isRegistered<MethodChannelService>()) {
          await GetIt.I.isReady<MethodChannelService>();
          unawaited(GetIt.I<MethodChannelService>().actions.startForegroundService());
        }
      }
    }
  }

  void open() {
    // If we haven't finished setup, don't do anything
    if (!SettingsSvc.settings.finishedSetup.value) return;
    StartupTasks.onAppResume();
  }

  // clever trick so we can see if the app is active in an isolate or not
  void createFakePort() {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping('bg_isolate');
    IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
  }

  /// [triggerState] is the lifecycle state that caused this close. Cleanup
  /// decisions must use it rather than the live [currentState]: by the time the
  /// awaits below complete, the state may have moved on (e.g. paused → detached
  /// when the activity is destroyed), which previously skipped cleanup entirely
  /// and left the app permanently reporting isAlive == true.
  Future<void> close({AppLifecycleState? triggerState}) async {
    // DO NOT remove observer here, it needs to stay registered to receive resumed events.
    // Leaving this commented out as a reminder.
    // WidgetsBinding.instance.removeObserver(this);

    // Flip liveness state FIRST and synchronously — everything below can await
    // (or fail), and isAlive must not report "alive" while we're backgrounded.
    if (kIsDesktop) {
      windowFocused = false;
    }

    // `hidden` is deliberately NOT treated as backgrounded: in-app overlays
    // (share sheet, file picker) hide the activity without the user leaving
    // the app, and we don't want liveness or sync behavior to change for those.
    final backgrounded = triggerState == AppLifecycleState.paused || triggerState == AppLifecycleState.detached;
    if (Platform.isAndroid && backgrounded) {
      IsolateNameServer.removePortNameMapping('bg_isolate');
    }

    if (kIsDesktop && GetIt.I.isRegistered<ChatsService>()) {
      wasActiveAliveBefore = ChatsSvc.activeChat?.isAlive.value;
    }

    if ((!kIsDesktop || wasActiveAliveBefore != false) && GetIt.I.isRegistered<ChatsService>()) {
      ChatsSvc.setActiveToDead();
    }

    // Stop any active typing indicators before draining the isolate so the
    // HTTP request completes and the recipient's typing indicator is cleared.
    // Never let a failed network call abort the rest of the teardown — this
    // previously leaked the alive-marker port and left the socket connected
    // in the background.
    if (GetIt.I.isRegistered<TypingIndicatorService>()) {
      try {
        await TypingIndicatorSvc.stopAllTyping();
      } catch (e, stack) {
        Logger.warn("Failed to stop typing indicators during close", error: e, trace: stack, tag: "LifecycleService");
      }
    }

    // Only stop the isolate and disconnect if the app is actually backgrounded
    // (paused, or detached when the activity is destroyed). If it's inactive or
    // hidden, the app may still technically be in the foreground, just obscured.
    if (Platform.isAndroid &&
        (triggerState == AppLifecycleState.paused || triggerState == AppLifecycleState.detached)) {
      if (GetIt.I.isRegistered<SocketService>()) {
        GetIt.I<SocketService>().disconnect();
      }

      // Request graceful isolate shutdown. Do not force-kill on timeout:
      // in-flight MethodChannel handlers may still need to post their reply,
      // and killing early can trigger a fatal platform reply-port abort.
      if (GetIt.I.isRegistered<GlobalIsolate>()) {
        unawaited(GetIt.I<GlobalIsolate>().drainAndStop());
      }
    }
  }

  void closeBubble() {
    if (GetIt.I.isRegistered<ChatsService>()) {
      GetIt.I<ChatsService>().setActiveToDead();
    }

    if (GetIt.I.isRegistered<SocketService>()) {
      GetIt.I<SocketService>().disconnect();
    }
  }
}
