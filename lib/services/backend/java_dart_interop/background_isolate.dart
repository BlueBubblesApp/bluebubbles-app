import 'dart:ui';

import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    mcs.invokeMethod("initialize-background-handle", {"handle": callbackHandle.toRawHandle()});
  }
}

@pragma('vm:entry-point')
backgroundIsolateEntrypoint() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = BadCertOverride();
  ls.isUiThread = false;
  await ss.init(headless: true);
  await fs.init(headless: true);
  await mcs.init(headless: true);
  await db.init();
}
