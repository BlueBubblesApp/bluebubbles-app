import 'package:bluebubbles/helpers/backend/foreground_service_helpers.dart';
import 'package:bluebubbles/helpers/network/network_helpers.dart';
import 'package:bluebubbles/helpers/network/network_tasks.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';

Future<bool> saveNewServerUrl(String newServerUrl,
    {bool tryRestartForegroundService = true,
    bool restartSocket = true,
    bool force = false,
    List<String> saveAdditionalSettings = const []}) async {
  String sanitized = sanitizeServerAddress(address: newServerUrl)!;
  final bool addressChanged = sanitized != SettingsSvc.settings.serverAddress.value;
  if (force || addressChanged) {
    SettingsSvc.settings.serverAddress.value = sanitized;

    // The origin override (if any) was resolved against the previous server's
    // local network — it's meaningless for the newly configured server, so it
    // must be cleared or the app will keep silently connecting to the old
    // address until the next app start or manual re-probe.
    //
    // Only on a real change, though. `force` means "run the side effects even if
    // the address is identical" (re-persisting guidAuthKey, cycling the socket),
    // and an unchanged address means the override is probably still valid —
    // dropping it here would silently move the app off localhost onto the remote
    // URL. SocketService's URL rediscovery calls this on a timer while the
    // connection is failing, so that would happen routinely.
    //
    // A stale override still has to be caught somewhere, and this is the wrong
    // place for it: blanket-clearing can't tell "wrong network" from "unchanged
    // address". That case belongs to _runUrlDiscovery(), which re-probes via
    // NetworkTasks.detectLocalhost() when the address hasn't moved and an override
    // is set — and falls back to the remote URL when the probe fails.
    if (addressChanged) {
      NetworkTasks.setOriginOverride(null);
    }

    await SettingsSvc.settings.saveManyAsync(["serverAddress", ...saveAdditionalSettings]);

    // Don't await because we don't care about the result
    if (tryRestartForegroundService) {
      restartForegroundService();
    }

    try {
      if (restartSocket) {
        SocketSvc.restartSocket();
      }
    } catch (e, stack) {
      Logger.error("Failed to restart socket!", error: e, trace: stack);
    }

    return true;
  }

  return false;
}

Future<void> clearServerUrl(
    {bool tryRestartForegroundService = true, List<String> saveAdditionalSettings = const []}) async {
  SettingsSvc.settings.serverAddress.value = "";
  NetworkTasks.setOriginOverride(null);
  await SettingsSvc.settings.saveManyAsync(["serverAddress", ...saveAdditionalSettings]);

  // Don't await because we don't care about the result
  if (tryRestartForegroundService) {
    restartForegroundService();
  }
}

/// Prompts the user to disable battery optimizations for the app
///
/// Returns true if the user has disabled battery optimizations
Future<bool> disableBatteryOptimizations() async {
  bool? isDisabled = await DisableBatteryOptimization.isAllBatteryOptimizationDisabled;

  // If battery optomizations are already disabled, return true
  if (isDisabled == true) return true;

  // If optimizations are not disabled, prompt the user to disable them
  isDisabled = await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
  return isDisabled ?? false;
}
