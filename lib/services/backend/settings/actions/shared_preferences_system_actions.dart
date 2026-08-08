import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesSystemActions {
  static const String _backgroundCallbackHandleKey = 'backgroundCallbackHandle';
  static const String _lastContactPermissionCheckKey = 'lastContactPermissionCheck';

  final SharedPreferencesService service;

  SharedPreferencesSystemActions(this.service);

  int? getBackgroundCallbackHandle() => service.i.getInt(_backgroundCallbackHandleKey);

  Future<void> setBackgroundCallbackHandle(int handle) => service.i.setInt(_backgroundCallbackHandleKey, handle);

  int? getLastContactPermissionCheck() => service.i.getInt(_lastContactPermissionCheckKey);

  Future<void> setLastContactPermissionCheck(int epochMillis) =>
      service.i.setInt(_lastContactPermissionCheckKey, epochMillis);
}
