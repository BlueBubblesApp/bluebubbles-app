import 'dart:ui';

import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    PrefsSvc.system.setBackgroundCallbackHandle(callbackHandle.toRawHandle());
  }
}

@pragma('vm:entry-point')
Future<void> backgroundIsolateEntrypoint() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  HttpOverrides.global = CustomHttpContext();

  await StartupTasks.initBackgroundIsolate();
}
