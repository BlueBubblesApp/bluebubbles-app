import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_service.dart';
import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

class SharedPreferencesAdminActions {
  final SharedPreferencesService service;

  SharedPreferencesAdminActions(this.service);

  Future<void> setBool(String key, bool value) => service.i.setBool(key, value);

  Future<void> setString(String key, String value) => service.i.setString(key, value);

  Future<void> setInt(String key, int value) => service.i.setInt(key, value);

  Future<void> setDouble(String key, double value) => service.i.setDouble(key, value);

  Future<void> remove(String key) => service.i.remove(key);

  Set<String> getKeys() => service.i.keys;

  Object? get(String key) => service.i.get(key);

  Future<void> clearAll() => service.i.clear();

  /// Waits for preference writes to reach disk. Await it before `exit(0)`: on Android the plugin writes with
  /// apply(), which a process exit can cut off. Desktop's store finishes each write before returning, so the
  /// method channel call is a no-op there. Best-effort: a failure is logged so the caller still exits.
  Future<void> flushToDisk() async {
    try {
      await MethodChannelSvc.actions.flushPreferences();
    } catch (e, s) {
      Logger.error("Failed to flush preferences to disk", tag: "SharedPreferencesAdminActions", error: e, trace: s);
    }
  }
}
