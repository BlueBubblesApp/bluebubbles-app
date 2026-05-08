import 'dart:async';
import 'dart:isolate';
import 'dart:ui' hide window;

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  bool get isAlive => kIsWeb
      ? !(window.document.hidden ?? false)
      : kIsDesktop
          ? windowFocused
          : (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
              IsolateNameServer.lookupPortByName('bg_isolate') != null);

  AppLifecycleState? get currentState => WidgetsBinding.instance.lifecycleState;

  List<AppLifecycleState> statesSinceLastResume = [];

  bool get wasPaused => statesSinceLastResume.contains(AppLifecycleState.paused);
  bool get wasHidden =>
      statesSinceLastResume.contains(AppLifecycleState.inactive) ||
      statesSinceLastResume.contains(AppLifecycleState.detached);
  bool get hasResumed => statesSinceLastResume.contains(AppLifecycleState.resumed);

  Future<void> init({bool headless = false, bool isBubble = false}) async {
    Logger.debug("Initializing LifecycleService${headless ? " in headless mode" : ""}");
    WidgetsBinding.instance.addObserver(this);

    this.headless = headless;
    this.isBubble = isBubble;

    handleForegroundService(AppLifecycleState.resumed);
    Logger.debug("LifecycleService initialized");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
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
      await Database.waitForInit();
      open();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // Eagerly mark the active chat as dead so that any message arriving during
      // the inactive → paused transition is not silently suppressed by the
      // "chat is active" notification guard. setActiveToDead() is idempotent
      // (equality-checked inside) and will run again in close() when paused fires.
      // Also handles Samsung One UI which emits `hidden` before `paused`.
      if (Platform.isAndroid && GetIt.I.isRegistered<ChatsService>()) {
        ChatsSvc.setActiveToDead();
      }
    } else {
      SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e, stack) {
        Logger.error("Error caught while hiding keyboard!", error: e, trace: stack);
      });
      if (isBubble) {
        closeBubble();
      } else {
        close();
      }
    }

    handleForegroundService(state);
  }

  void handleForegroundService(AppLifecycleState state) {
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
        MethodChannelSvc.invokeMethod("stop-foreground-service");
      } else if ([AppLifecycleState.paused, AppLifecycleState.detached].contains(state)) {
        Logger.info(tag: "LifecycleService", "Starting foreground service");
        MethodChannelSvc.invokeMethod("start-foreground-service");
      }
    }
  }

  void open() {
    // If we haven't finished setup, don't do anything
    if (!SettingsSvc.settings.finishedSetup.value) return;
    // Lifecycle events can fire before StartupTasks.init() has registered
    // ChatsService (e.g. window-focus on cold start). Skip until services exist;
    // startup_tasks will set the active state itself when it finishes.
    if (!GetIt.I.isRegistered<ChatsService>()) return;
    StartupTasks.onAppResume();
  }

  // clever trick so we can see if the app is active in an isolate or not
  void createFakePort() {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping('bg_isolate');
    IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
  }

  void close() {
    // DO NOT remove observer here - it needs to stay registered to receive resumed events.
    // Leaving this commented out as a reminder.
    // WidgetsBinding.instance.removeObserver(this);

    // Pause/hide can fire before ChatsService is registered on cold start.
    final chatsReady = GetIt.I.isRegistered<ChatsService>();
    if (kIsDesktop && chatsReady) {
      wasActiveAliveBefore = ChatsSvc.activeChat?.isAlive.value;
    }
    if (chatsReady && (!kIsDesktop || wasActiveAliveBefore != false)) {
      ChatsSvc.setActiveToDead();
    }
    if (!kIsDesktop && !kIsWeb) {
      IsolateNameServer.removePortNameMapping('bg_isolate');
      SocketSvc.disconnect();

      // Stop the background isolate so its idle-poll timer does not keep the
      // Dart event loop alive while the app is in the background. It will be
      // restarted lazily on the next request via _ensureStarted().
      if (GetIt.I.isRegistered<GlobalIsolate>()) {
        unawaited(GetIt.I<GlobalIsolate>().drainAndStop(timeout: const Duration(seconds: 30)));
      }
    }
    if (chatsReady) {
      final activeChat = ChatsSvc.activeChat;
      if (activeChat != null) {
        ConversationViewController _cvc = cvc(activeChat.chat);
        _cvc.lastFocusedNode.unfocus();
      }
    }
    if (kIsDesktop) {
      windowFocused = false;
    }
  }

  void closeBubble() {
    ChatsSvc.setActiveToDead();
    SocketSvc.disconnect();
  }
}
