import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:version/version.dart';

SettingsService ss = Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : Get.put(SettingsService());

class SettingsService extends GetxService {
  late Settings settings;
  late FCMData fcmData;
  bool canAuthenticate = false;
  late final SharedPreferences prefs;

  Future<void> init({bool headless = false}) async {
    prefs = await SharedPreferences.getInstance();
    settings = Settings.getSettings();
    if (!headless && !kIsWeb && !kIsDesktop) {
      // refresh rate
      if (!kIsWeb && !kIsDesktop) {
        try {
          canAuthenticate = !kIsWeb && !kIsDesktop && await LocalAuthentication().isDeviceSupported();
          final mode = await settings.getDisplayMode();
          if (mode != DisplayMode.auto) {
            FlutterDisplayMode.setPreferredMode(mode);
          }
        } catch (_) {}
      }
      // system appearance
      if (!kIsWeb && settings.immersiveMode.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        if (settings.allowUpsideDownRotation.value)
          DeviceOrientation.portraitDown,
      ]);
      // launch at startup
      if (kIsDesktop) {
        LaunchAtStartup.setup(fs.packageInfo.appName);
        if (settings.launchAtStartup.value) {
          await LaunchAtStartup.enable();
        } else {
          await LaunchAtStartup.disable();
        }
      }
    }
  }

  // this is a separate method because objectbox needs to be initialized
  void getFcmData() {
    fcmData = FCMData.getFCM();
  }

  Future<void> saveSettings([Settings? newSettings, bool updateDisplayMode = false]) async {
    // Set the new settings as the current settings in the manager
    settings = newSettings ?? settings;
    settings.save();
    if (updateDisplayMode && !kIsWeb && !kIsDesktop) {
      try {
        final mode = await settings.getDisplayMode();
        FlutterDisplayMode.setPreferredMode(mode);
      } catch (_) {}
    }
  }

  void saveFCMData(FCMData data) {
    fcmData = data;
    fcmData.save();
  }

  Future<Tuple4<int, int, String, int>> getServerDetails({bool refresh = false}) async {
    if (refresh) {
      final response = await http.serverInfo();
      if (response.statusCode == 200) {
        final version = int.tryParse(response.data['data']['os_version'].split(".")[0]);
        final minorVersion = int.tryParse(response.data['data']['os_version'].split(".")[1]);
        final serverVersion = response.data['data']['server_version'];
        final code = Version.parse(serverVersion ?? "0.0.0");
        final versionCode = code.major * 100 + code.minor * 21 + code.patch;
        if (version != null) prefs.setInt("macos-version", version);
        if (minorVersion != null) prefs.setInt("macos-minor-version", minorVersion);
        if (serverVersion != null) prefs.setString("server-version", serverVersion);
        prefs.setInt("server-version-code", versionCode);
        return Tuple4(version ?? 11, minorVersion ?? 0, serverVersion, versionCode);
      } else {
        return Tuple4(11, 0, "0.0.0", 0);
      }
    } else {
      return Tuple4(prefs.getInt("macos-version") ?? 11, prefs.getInt("macos-minor-version") ?? 0, prefs.getString("server-version") ?? "0.0.0", prefs.getInt("server-version-code") ?? 0);
    }
  }

  Future<bool> get isMinSierra async {
    final val = await getServerDetails();
    return val.item1 > 10 || (val.item1 == 10 && val.item2 > 11);
  }

  Future<bool> get isMinBigSur async {
    final val = await getServerDetails();
    return val.item1 >= 11;
  }

  bool get isMinBigSurSync {
    return (prefs.getInt("macos-version") ?? 11) >= 11;
  }

  int get compressionQuality => settings.highPerfMode.value ? 10 : settings.previewCompressionQuality.value;

  Future<void> checkServerUpdate({bool showDialog = true, BuildContext? context}) async {
    if (showDialog) assert(context != null);

    final response = await http.checkUpdate();
    if (response.statusCode == 200) {
      bool available = response.data['data']['available'] ?? false;
      Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};
      if (!available || prefs.getString("update-check") == metadata['version'] || !showDialog) return;
      Get.defaultDialog(
        title: "Server Update Check",
        titleStyle: context!.theme.textTheme.headlineMedium,
        textConfirm: "OK",
        cancel: Container(height: 0, width: 0),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              height: 15.0,
            ),
            Text("Updates available:", style: context.theme.textTheme.bodyMedium),
            SizedBox(
              height: 15.0,
            ),
            if (metadata.isNotEmpty)
              Text("Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ?? "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}")
          ]
        ),
        onConfirm: () {
          if (metadata['version'] != null) {
            prefs.setString("update-check", metadata['version']);
          }
          Navigator.of(context).pop();
        },
        backgroundColor: context.theme.colorScheme.properSurface,
      );
    }
  }
}