import 'package:bluebubbles/helpers/backend/foreground_service_helpers.dart';
import 'package:bluebubbles/helpers/network/network_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';

Future<bool> saveNewServerUrl(
  String newServerUrl,
  {
    bool tryRestartForegroundService = true,
    bool restartSocket = true,
    bool force = false,
    List<String> saveAdditionalSettings = const []
  }
) async {
  String sanitized = sanitizeServerAddress(address: newServerUrl)!;
  if (force || sanitized != ss.settings.serverAddress.value) {
    ss.settings.serverAddress.value = sanitized;

    await ss.settings.saveMany(["serverAddress", ...saveAdditionalSettings]);

    // Don't await because we don't care about the result
    if (tryRestartForegroundService) {
      restartForegroundService().catchError((e) {
        Logger.error("Failed to restart foreground service: $e");
      });
    }
    
    try {
      if (restartSocket) {
        socket.restartSocket();
      }
    } catch (e) {
      Logger.error("Failed to restart socket: $e");
    }

    return true;
  }

  return false;
}

Future<void> clearServerUrl(
  {
    bool tryRestartForegroundService = true,
    List<String> saveAdditionalSettings = const []
  }
) async {
  ss.settings.serverAddress.value = "";
  await ss.settings.saveMany(["serverAddress", ...saveAdditionalSettings]);

  // Don't await because we don't care about the result
  if (tryRestartForegroundService) {
    restartForegroundService().catchError((e) {
      Logger.error("Failed to restart foreground service: $e");
    });
  }
}