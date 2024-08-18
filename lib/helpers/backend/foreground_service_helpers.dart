import 'dart:io';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

Future<void> runForegroundService() async {
  try {
    if (Platform.isAndroid && ss.settings.keepAppAlive.value && !ls.isAlive) {
      await mcs.invokeMethod("start-foreground-service");
    } else if (Platform.isAndroid && !ss.settings.keepAppAlive.value) {
      await mcs.invokeMethod("stop-foreground-service");
    }
  } catch (e, stack) {
    Logger.error("Failed to start foreground service!", error: e, trace: stack);
  }
}

Future<void> restartForegroundService() async {
  try {
    if (Platform.isAndroid && ss.settings.keepAppAlive.value && !ls.isAlive) {
      await mcs.invokeMethod("stop-foreground-service");
      await mcs.invokeMethod("start-foreground-service");
    }
  } catch (e, stack) {
    Logger.error("Failed to restart foreground service!", error: e, trace: stack);
  }
}