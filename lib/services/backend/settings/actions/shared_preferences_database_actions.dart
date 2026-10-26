import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesDatabaseActions {
  static const String _finishedSetupKey = 'finishedSetup';
  static const String _dbVersionKey = 'dbVersion';
  static const String _themesVersionKey = 'themesVersion';
  static const String _useCustomPathKey = 'use-custom-path';
  static const String _customPathKey = 'custom-path';

  final SharedPreferencesService service;

  SharedPreferencesDatabaseActions(this.service);

  bool getFinishedSetup() => service.i.getBool(_finishedSetupKey) ?? false;

  int? getDbVersion() => service.i.getInt(_dbVersionKey);

  Future<void> setDbVersion(int version) => service.i.setInt(_dbVersionKey, version);

  int getThemesVersion() => service.i.getInt(_themesVersionKey) ?? 0;

  Future<void> setThemesVersion(int version) => service.i.setInt(_themesVersionKey, version);

  bool shouldUseCustomPath() => service.i.getBool(_useCustomPathKey) == true;

  String? getCustomPath() => service.i.getString(_customPathKey);

  Future<void> clearCustomPathConfig() async {
    await service.i.remove(_useCustomPathKey);
    await service.i.remove(_customPathKey);
  }
}
