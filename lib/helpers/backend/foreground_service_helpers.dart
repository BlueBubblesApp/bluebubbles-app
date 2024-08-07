import 'dart:io';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';

Future<void> runForegroundService() async {
  try {
    if (Platform.isAndroid && ss.settings.keepAppAlive.value && !ls.isAlive) {
      await mcs.invokeMethod("start-foreground-service");
    } else if (Platform.isAndroid && !ss.settings.keepAppAlive.value) {
      await mcs.invokeMethod("stop-foreground-service");
    }
  } catch (e) {
    Logger.error("Failed to start foreground service: $e");
  }
}

Future<void> restartForegroundService() async {
  try {
    if (Platform.isAndroid && ss.settings.keepAppAlive.value && !ls.isAlive) {
      await mcs.invokeMethod("stop-foreground-service");
      await mcs.invokeMethod("start-foreground-service");
    }
  } catch (e) {
    Logger.error("Failed to restart foreground service: $e");
  }
}