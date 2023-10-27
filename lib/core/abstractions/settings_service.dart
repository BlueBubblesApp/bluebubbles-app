import 'package:bluebubbles/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../abstractions/service.dart';


abstract class SettingsService extends Service {
  @override
  bool required = true;

  Settings get config;

  FCMData get fcmData;

  SharedPreferences get prefs;

  Future<void> saveConfig([Settings? newSettings, bool updateDisplayMode = false]);

  Future<void> loadConfig();

  Future<void> saveFCMData([FCMData? newData]);

  Future<void> loadFCMData();
}