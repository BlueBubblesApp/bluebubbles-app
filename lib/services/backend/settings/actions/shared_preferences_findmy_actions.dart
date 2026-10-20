import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesFindMyActions {
  static const String _locationCacheKey = 'findmy-location-cache';

  final SharedPreferencesService service;

  SharedPreferencesFindMyActions(this.service);

  String? getLocationCache() => service.i.getString(_locationCacheKey);

  Future<void> setLocationCache(String json) async {
    await service.i.setString(_locationCacheKey, json);
  }
}
