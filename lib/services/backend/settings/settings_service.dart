import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:github/github.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_checker/store_checker.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

SettingsService ss = Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : Get.put(SettingsService());

class SettingsService extends GetxService {
  late Settings settings;
  late FCMData fcmData;
  bool _canAuthenticate = false;
  late final SharedPreferences prefs;

  bool get canAuthenticate => _canAuthenticate && (Platform.isWindows || (fs.androidInfo?.version.sdkInt ?? 0) > 28);

  Future<void> init({bool headless = false}) async {
    prefs = await SharedPreferences.getInstance();
    settings = Settings.getSettings();
    if (!headless && !kIsWeb && !kIsDesktop) {
      // refresh rate
      try {
        _canAuthenticate = await LocalAuthentication().isDeviceSupported();
        final mode = await settings.getDisplayMode();
        if (mode != DisplayMode.auto) {
          FlutterDisplayMode.setPreferredMode(mode);
        }
      } catch (_) {}
      // system appearance
      if (settings.immersiveMode.value) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        if (settings.allowUpsideDownRotation.value)
          DeviceOrientation.portraitDown,
      ]);
    }
    // launch at startup
    if (kIsDesktop) {
      if (Platform.isWindows) {
        _canAuthenticate = await LocalAuthentication().isDeviceSupported();
      }
      LaunchAtStartup.setup((await PackageInfo.fromPlatform()).appName); // Can't use fs here because it hasn't been initialized yet
      if (settings.launchAtStartup.value) {
        await LaunchAtStartup.enable();
      } else {
        await LaunchAtStartup.disable();
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
        return const Tuple4(11, 0, "0.0.0", 0);
      }
    } else {
      return Tuple4(prefs.getInt("macos-version") ?? 11, prefs.getInt("macos-minor-version") ?? 0, prefs.getString("server-version") ?? "0.0.0", prefs.getInt("server-version-code") ?? 0);
    }
  }

  Tuple4<int, int, String, int> serverDetailsSync() =>
      Tuple4(prefs.getInt("macos-version") ?? 11, prefs.getInt("macos-minor-version") ?? 0, prefs.getString("server-version") ?? "0.0.0", prefs.getInt("server-version-code") ?? 0);

  Future<bool> get isMinSierra async {
    final val = await getServerDetails();
    return val.item1 > 10 || (val.item1 == 10 && val.item2 > 11);
  }

  Future<bool> get isMinBigSur async {
    final val = await getServerDetails();
    return val.item1 >= 11;
  }

  Future<bool> get isMinMonterey async {
    final val = await getServerDetails();
    return val.item1 >= 12;
  }

  bool get isMinMontereySync {
    return (prefs.getInt("macos-version") ?? 11) >= 12;
  }

  bool get isMinBigSurSync {
    return (prefs.getInt("macos-version") ?? 11) >= 11;
  }

  bool get isMinVenturaSync {
    return (prefs.getInt("macos-version") ?? 11) >= 13;
  }

  Future<void> checkServerUpdate() async {
    final response = await http.checkUpdate();
    if (response.statusCode == 200) {
      bool available = response.data['data']['available'] ?? false;
      Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};
      if (!available || prefs.getString("server-update-check") == metadata['version']) return;
      showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          backgroundColor: context.theme.colorScheme.properSurface,
          title: Text("Server Update Check", style: context.theme.textTheme.titleLarge),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: 15.0,
              ),
              Text(available ? "Updates available:" : "Your server is up-to-date!", style: context.theme.textTheme.bodyLarge),
              const SizedBox(
                height: 15.0,
              ),
              if (metadata.isNotEmpty)
                Text("Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ?? "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}", style: context.theme.textTheme.bodyLarge)
            ],
          ),
          actions: [
            TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () {
                prefs.setString("server-update-check", metadata['version']);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> checkClientUpdate() async {
    if (!kIsDesktop && (kIsWeb || (await StoreChecker.getSource) != Source.IS_INSTALLED_FROM_LOCAL_SOURCE)) return;
    if (kIsDesktop) return; // todo
    final github = GitHub();
    final stream = github.repositories.listReleases(RepositorySlug('bluebubblesapp', 'bluebubbles-app'));
    final release = await stream.firstWhere((element) => !(element.isDraft ?? false) && !(element.isPrerelease ?? false) && element.tagName != null);
    final version = release.tagName!.split("+").first.replaceAll("v", "");
    final code = release.tagName!.split("+").last;
    final buildNumber = fs.packageInfo.buildNumber.lastChars(min(4, fs.packageInfo.buildNumber.length));
    if (int.parse(code) <= int.parse(buildNumber) || prefs.getString("client-update-check") == code) return;
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("App Update Check", style: context.theme.textTheme.titleLarge),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              height: 15.0,
            ),
            Text("Updates available:", style: context.theme.textTheme.bodyLarge),
            const SizedBox(
              height: 15.0,
            ),
            Text("Version: $version\nRelease Date: ${buildDate(release.createdAt)}\nRelease Name: ${release.name}", style: context.theme.textTheme.bodyLarge)
          ],
        ),
        actions: [
          if (release.htmlUrl != null)
            TextButton(
              child: Text("Download", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await launchUrl(Uri.parse(release.htmlUrl!), mode: LaunchMode.externalApplication);
              },
            ),
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              prefs.setString("client-update-check", code);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}