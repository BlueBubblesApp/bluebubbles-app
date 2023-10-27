import 'dart:io';

import 'package:bluebubbles/core/abstractions/device_service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:store_checker/store_checker.dart';

class RxDeviceService extends DeviceService {
  @override
  final String name = "Rx Device Service";

  @override
  final int version = 1;

  bool _isAuthSupported = false;

  @override
  bool get supportsLocalAuth => _isAuthSupported && (Platform.isWindows || (fs.androidInfo?.version.sdkInt ?? 0) > 28);

  RxDeviceService() {
    StoreChecker.getSource.then((value) {
      installedFromStore = value != Source.IS_INSTALLED_FROM_LOCAL_SOURCE;
    });
  }

  @override
  Future<void> initMobile() async {
    if (headless) return Future.value();
    _isAuthSupported = await LocalAuthentication().isDeviceSupported();
  }

  @override
  Future<void> initDesktop() async {
    if (Platform.isWindows) {
      _isAuthSupported = await LocalAuthentication().isDeviceSupported();
    }
  }

  @override
  Future<void> setupLaunchAtStartup() async {
    // Can't use fs here because it hasn't been initialized yet
    LaunchAtStartup.setup((await PackageInfo.fromPlatform()).appName, settings.config.launchAtStartupMinimized.value);
    if (settings.config.launchAtStartup.value) {
      await LaunchAtStartup.enable();
    } else {
      await LaunchAtStartup.disable();
    }
  }

  setAppearance() {
    if (settings.config.immersiveMode.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      if (settings.config.allowUpsideDownRotation.value)
        DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> setDisplayMode() async {
    final mode = await settings.config.getDisplayMode();
    if (mode != DisplayMode.auto) {
      FlutterDisplayMode.setPreferredMode(mode);
    }
  }
}
  