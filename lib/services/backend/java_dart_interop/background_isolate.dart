import 'dart:ui';

import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/services/network/http_overrides.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    ss.prefs.setInt("backgroundCallbackHandle", callbackHandle.toRawHandle());
  }
}

@pragma('vm:entry-point')
backgroundIsolateEntrypoint() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = BadCertOverride();

  await StartupTasks.initIsolateServices();
}
