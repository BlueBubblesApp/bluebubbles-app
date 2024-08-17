import 'dart:isolate';
import 'dart:ui' hide window;

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' hide Platform;
import 'dart:io' show Platform;

LifecycleService ls = Get.isRegistered<LifecycleService>() ? Get.find<LifecycleService>() : Get.put(LifecycleService());

class LifecycleService extends GetxService with WidgetsBindingObserver {
  bool isBubble = false;
  bool isUiThread = true;
  bool windowFocused = true;
  bool? wasActiveAliveBefore;
  bool get isAlive => kIsWeb ? !(window.document.hidden ?? false)
      : kIsDesktop ? windowFocused : (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed
        || IsolateNameServer.lookupPortByName('bg_isolate') != null);

  AppLifecycleState? get currentState => WidgetsBinding.instance.lifecycleState;
  bool wasPaused = false;
  bool? resumeFromPause;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> init({bool headless = false, bool isBubble = false}) async {
    Logger.debug("Initializing LifecycleService${headless ? " in headless mode" : ""}");

    isUiThread = !headless;
    this.isBubble = isBubble;

    handleForegroundService(AppLifecycleState.resumed);

    Logger.debug("LifecycleService initialized");
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    Logger.debug("App State changed to $state");

    if (state == AppLifecycleState.paused) {
      wasPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      if (wasPaused) {
        wasPaused = false;
        resumeFromPause = true;
      } else {
        resumeFromPause = false;
      }
    }

    if (state == AppLifecycleState.resumed) {
      await Database.waitForInit();
      open();
    } else if (state != AppLifecycleState.inactive) {
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

  void handleForegroundService(AppLifecycleState state) async {
    // If an isolate is invoking this, we don't want to start/stop the foreground service.
    // It should already be running. We don't need to stop it because the socket service
    // is not started when in headless mode.
    if (!isUiThread) return;

    // This may get called before the settings service is initialized
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool keepAlive = prefs.getBool("keepAppAlive") ?? false;

    if (Platform.isAndroid && keepAlive) {
      // We only want the foreground service to run when the app is not active
      if (state == AppLifecycleState.resumed) {
        Logger.info(tag: "LifecycleService", "Stopping foreground service");
        mcs.invokeMethod("stop-foreground-service");
      } else if ([AppLifecycleState.paused, AppLifecycleState.detached].contains(state)) {
        Logger.info(tag: "LifecycleService", "Starting foreground service");
        mcs.invokeMethod("start-foreground-service");
      }
    }
  }

  void open() {
    if (!kIsDesktop || wasActiveAliveBefore != false) {
      cm.setActiveToAlive();
    }
    if (cm.activeChat != null) {
      cm.activeChat!.chat.toggleHasUnread(false);
      ConversationViewController _cvc = cvc(cm.activeChat!.chat);
      if (!_cvc.showingOverlays && _cvc.editing.isEmpty) {
        _cvc.lastFocusedNode.requestFocus();
      }
    }

    if (http.originOverride == null) {
      NetworkTasks.detectLocalhost();
    }
    if (!kIsDesktop && !kIsWeb) {
      if (!isBubble) {
        createFakePort();
      }
      
      socket.reconnect();
    }

    if (kIsDesktop) {
      windowFocused = true;
    }
  }

  // clever trick so we can see if the app is active in an isolate or not
  void createFakePort() {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping('bg_isolate');
    IsolateNameServer.registerPortWithName(port.sendPort, 'bg_isolate');
  }

  void close() {
    if (kIsDesktop) {
      wasActiveAliveBefore = cm.activeChat?.isAlive;
    }
    if (!kIsDesktop || wasActiveAliveBefore != false) {
      cm.setActiveToDead();
    }
    if (!kIsDesktop && !kIsWeb) {
      IsolateNameServer.removePortNameMapping('bg_isolate');
      socket.disconnect();
    }
    if (cm.activeChat != null) {
      ConversationViewController _cvc = cvc(cm.activeChat!.chat);
      _cvc.lastFocusedNode.unfocus();
    }
    if (kIsDesktop) {
      windowFocused = false;
    }
  }

  void closeBubble() {
    cm.setActiveToDead();
    socket.disconnect();
  }
}