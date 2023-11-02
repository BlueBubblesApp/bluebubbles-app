import 'dart:io';

import 'package:bluebubbles/core/abstractions/storage/settings_service.dart';
import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:local_auth/local_auth.dart';

class DefaultSettingsService extends SettingsService {
  @override
  final String name = "Default Settings Service";

  @override
  final int version = 1;

  @override
  late Settings config;

  bool _isAuthSupported = false;

  bool get canAuthenticate => _isAuthSupported && (Platform.isWindows || (fs.androidInfo?.version.sdkInt ?? 0) > 28);

  @override
  Future<void> initMobile() async {
    if (headless) return Future.value();

    _isAuthSupported = await LocalAuthentication().isDeviceSupported();
  }

  @override
  Future<void> loadConfig() {
    config = Settings.getSettings();
    return Future.value();
  }

  @override
  Future<void> saveConfig([Settings? newSettings, bool updateDisplayMode = false]) async {
    // Set the new settings as the current settings in the manager
    config = newSettings ?? config;
    config.save();

    if (updateDisplayMode && !kIsWeb && !kIsDesktop) {
      try {
        final mode = await config.getDisplayMode();
        FlutterDisplayMode.setPreferredMode(mode);
      } catch (_) {}
    }
  }
}
  