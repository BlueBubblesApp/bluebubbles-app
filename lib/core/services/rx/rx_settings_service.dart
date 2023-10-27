import 'dart:io';

import 'package:bluebubbles/core/abstractions/settings_service.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RxSettingsService extends SettingsService {
  @override
  final String name = "Rx Settings Service";

  @override
  final int version = 1;

  @override
  late SharedPreferences prefs;

  @override
  late Settings config;

  bool _isAuthSupported = false;

  bool get canAuthenticate => _isAuthSupported && (Platform.isWindows || (fs.androidInfo?.version.sdkInt ?? 0) > 28);

  @override
  FCMData get fcmData => throw UnimplementedError();

  @override
  Future<void> initAllPlatforms() async {
    prefs = await SharedPreferences.getInstance();
    config = Settings.getSettings();
  }

  @override
  Future<void> initMobile() async {
    if (headless) return Future.value();

    _isAuthSupported = await LocalAuthentication().isDeviceSupported();
  }

  @override
  Future<void> loadConfig() {
    throw UnimplementedError();
  }

  @override
  Future<void> loadFCMData() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveConfig([Settings? newSettings, bool updateDisplayMode = false]) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveFCMData([FCMData? newData]) {
    throw UnimplementedError();
  }
}
  