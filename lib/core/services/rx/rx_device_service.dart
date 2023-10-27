import 'dart:convert';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/core/abstractions/device_service.dart';
import 'package:bluebubbles/core/abstractions/service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/core/utilities/filesystem_utils.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/filesystem/filesystem_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:local_auth/local_auth.dart';
import 'package:on_exit/init.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:store_checker/store_checker.dart';
import 'package:tuple/tuple.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;

class RxDeviceService extends DeviceService {
  @override
  final String name = "Rx Device Service";

  @override
  final int version = 1;

  @override
  List<Service> dependencies = [settings];

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
  Future<void> startDesktop() async {
    if (!Platform.isLinux || !kIsDesktop) return;
    log.debug("Starting process with PID $pid");

    final lockFile = File(join(fs.appDocDir.path, 'bluebubbles.lck'));
    final instanceFile = File(join(fs.appDocDir.path, '.instance'));
    onExit(() {
      if (lockFile.existsSync()) lockFile.deleteSync();
    });

    if (!lockFile.existsSync()) {
      lockFile.createSync();
    }
    if (!instanceFile.existsSync()) {
      instanceFile.createSync();
    }

    log.debug("Lockfile at ${lockFile.path}");

    String _pid = lockFile.readAsStringSync();

    String ps = Process.runSync('ps', ['-p', _pid]).stdout;
    if (kReleaseMode && "$pid" != _pid && ps.endsWith('bluebubbles\n')) {
      log.debug("Another instance is running. Sending foreground signal");
      instanceFile.openSync(mode: FileMode.write).closeSync();
      exit(0);
    }

    lockFile.writeAsStringSync("$pid");

    instanceFile.watch(events: FileSystemEvent.modify).listen((event) async {
      log.debug("Got Signal to go to foreground");
      doWhenWindowReady(() async {
        await windowManager.show();
        List<Tuple2<String, String>?> widAndNames = await (await Process.start('wmctrl', ['-pl']))
            .stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map((line) => line.replaceAll(RegExp(r"\s+"), " ").split(" "))
            .map((split) => split[2] == "$pid" ? Tuple2(split.first, split.last) : null)
            .where((tuple) => tuple != null)
            .toList();
        for (Tuple2<String, String>? window in widAndNames) {
          if (window?.item2 == "BlueBubbles") {
            Process.runSync('wmctrl', ['-iR', window!.item1]);
            break;
          }
        }
      });
    });
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

  @override
  Future<void> migrate() async {
    if (kIsDesktop && (Platform.isLinux || Platform.isWindows)) {
      //ignore: unnecessary_cast, we need this as a workaround
      Directory appData = fs.appDocDir as Directory;
      if (!await Directory(join(appData.path, "objectbox")).exists()) {
        // Migrate to new appdata location if this function returns the new place and we still have the old place
        if (basename(appData.absolute.path) == "bluebubbles") {
          Directory oldAppData = Platform.isWindows
              ? Directory(join(dirname(dirname(appData.absolute.path)), "com.bluebubbles\\bluebubbles_app"))
              : Directory(join(dirname(appData.absolute.path), "bluebubbles_app"));
          bool storeApp = basename(dirname(dirname(appData.absolute.path))) != "Roaming";
          if (await oldAppData.exists()) {
            log.info("Copying appData to new directory");
            copyDirectory(oldAppData, appData);
            log.info("Finished migrating appData");
          } else if (Platform.isWindows) {
            // Find the other appdata.
            String appDataRoot = p.joinAll(p.split(appData.absolute.path).slice(0, 4));
            if (storeApp) {
              // If current app is store, we first look for new location nonstore appdata in case people are installing
              // diff versions
              oldAppData = Directory(join(appDataRoot, "Roaming", "BlueBubbles", "bluebubbles"));
              // If that doesn't exist, we look in the old non-store location
              if (!await oldAppData.exists()) {
                oldAppData = Directory(join(appDataRoot, "Roaming", "com.bluebubbles", "bluebubbles_app"));
              }
              if (await oldAppData.exists()) {
                log.info("Copying appData from NONSTORE location to new directory");
                copyDirectory(oldAppData, appData);
                log.info("Finished migrating appData");
              }
            } else {
              oldAppData = Directory(join(appDataRoot, "Local", "Packages", "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw", "LocalCache", "Roaming",
                  "BlueBubbles", "bluebubbles"));
              if (!await oldAppData.exists()) {
                oldAppData = Directory(join(appDataRoot, "Local", "Packages", "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw", "LocalCache", "Roaming",
                    "com.bluebubbles", "bluebubbles_app"));
              }
              if (await oldAppData.exists()) {
                log.info("Copying appData from STORE location to new directory");
                copyDirectory(oldAppData, appData);
                log.info("Finished migrating appData");
              }
            }
          }
        }
      }
    }
  }
}
  