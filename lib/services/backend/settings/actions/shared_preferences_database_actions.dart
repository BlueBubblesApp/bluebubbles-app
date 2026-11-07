import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesDatabaseActions {
  static const String _finishedSetupKey = 'finishedSetup';
  static const String _dbVersionKey = 'dbVersion';
  static const String _themesVersionKey = 'themesVersion';
  static const String _useCustomPathKey = 'use-custom-path';
  static const String _customPathKey = 'custom-path';
  static const String _chatlessMessageRepairKey = 'chatlessMessageRepairDone';

  final SharedPreferencesService service;

  SharedPreferencesDatabaseActions(this.service);

  bool getFinishedSetup() => service.i.getBool(_finishedSetupKey) ?? false;

  int? getDbVersion() => service.i.getInt(_dbVersionKey);

  Future<void> setDbVersion(int version) => service.i.setInt(_dbVersionKey, version);

  int getThemesVersion() => service.i.getInt(_themesVersionKey) ?? 0;

  Future<void> setThemesVersion(int version) => service.i.setInt(_themesVersionKey, version);

  bool getChatlessMessageRepairDone() => service.i.getBool(_chatlessMessageRepairKey) ?? false;

  Future<void> setChatlessMessageRepairDone() => service.i.setBool(_chatlessMessageRepairKey, true);

  bool shouldUseCustomPath() => service.i.getBool(_useCustomPathKey) == true;

  String? getCustomPath() => service.i.getString(_customPathKey);

  Future<void> clearCustomPathConfig() async {
    await service.i.remove(_useCustomPathKey);
    await service.i.remove(_customPathKey);
  }

  static const String _serverV2MigrationsKey = 'serverV2MigrationsVersion';
  int getServerV2MigrationsVersion() => service.i.getInt(_serverV2MigrationsKey) ?? 0;

  Future<void> setServerV2MigrationsVersion(int version) => service.i.setInt(_serverV2MigrationsKey, version);
}
