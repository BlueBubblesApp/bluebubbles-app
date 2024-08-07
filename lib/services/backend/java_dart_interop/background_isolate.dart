import 'dart:ui';

import 'package:bluebubbles/main.dart';
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

  await fs.init(headless: true);
  await ss.init(headless: true);

  await initDatabase();
  
  await mcs.init(headless: true);
  await ls.init(headless: true);
}
