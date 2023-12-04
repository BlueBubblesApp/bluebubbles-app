import 'dart:math';

import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:github/github.dart' hide Source;
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
        if (settings.allowUpsideDownRotation.value) DeviceOrientation.portraitDown,
      ]);
    }
    // launch at startup
    if (kIsDesktop) {
      if (Platform.isWindows) {
        _canAuthenticate = await LocalAuthentication().isDeviceSupported();
      }
      await setupLaunchAtStartup();
    }
  }

  Future<void> setupLaunchAtStartup() async {
    // Can't use fs here because it hasn't been initialized yet
    LaunchAtStartup.setup((await PackageInfo.fromPlatform()).appName, settings.launchAtStartupMinimized.value);
    if (settings.launchAtStartup.value) {
      await LaunchAtStartup.enable();
    } else {
      await LaunchAtStartup.disable();
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
        if (settings.iCloudAccount.isEmpty && response.data['data']['detected_icloud'] is String) {
          settings.iCloudAccount.value = response.data['data']['detected_icloud'];
          settings.save();
        }

        if (response.data['data']['private_api'] is bool) {
          settings.serverPrivateAPI.value = response.data['data']['private_api'];
          settings.save();
        }

        if (settings.finishedSetup.value) {
          if (settings.enablePrivateAPI.value) {
            await prefs.setBool('private-api-enable-tip', true);
          } else if (settings.serverPrivateAPI.value == true && prefs.getBool('private-api-enable-tip') != true) {
            final ScrollController controller = ScrollController();
            await showDialog(
              context: Get.context!,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Private API Features"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: min(context.height / 3, Get.context!.height - 300)),
                        child: ScrollbarWrapper(
                          controller: controller,
                          showScrollbar: true,
                          child: SingleChildScrollView(
                            controller: controller,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("You've enabled Private API Features on your server!"),
                                const SizedBox(height: 10),
                                const Text("Private API features give you the ability to:"),
                                const Text(" - Send & Receive typing indicators"),
                                const Text(" - Send tapbacks, effects, and mentions"),
                                const Text(" - Send messages with subject lines"),
                                if (isMinBigSurSync) const Text(" - Send replies"),
                                if (isMinVenturaSync) const Text(" - Edit & Unsend messages"),
                                const SizedBox(height: 10),
                                const Text(" - Mark chats read on the Mac server"),
                                if (isMinVenturaSync) const Text(" - Mark chats as unread on the Mac server"),
                                const SizedBox(height: 10),
                                const Text(" - Rename group chats"),
                                const Text(" - Add & remove people from group chats"),
                                if (isMinBigSurSync) const Text(" - Change the group chat photo"),
                                if (isMinBigSurSync) const SizedBox(height: 10),
                                if (isMinMontereySync) const Text(" - View Focus statuses"),
                                if (isMinBigSurSync) const Text(" - Use Find My Friends"),
                                if (isMinBigSurSync) const Text(" - Be notified of incoming FaceTime calls"),
                                if (isMinVenturaSync) const Text(" - Answer FaceTime calls (experimental)"),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                              onPressed: () async {
                                await prefs.setBool('private-api-enable-tip', true);
                                Navigator.of(context).pop();
                                ns.closeSettings(context);
                                ns.closeAllConversationView(context);
                                await cm.setAllInactive();
                                await Navigator.of(Get.context!).push(
                                  ThemeSwitcher.buildPageRoute(
                                    builder: (BuildContext context) {
                                      return SettingsPage(
                                        initialPage: PrivateAPIPanel(enablePrivateAPIonInit: true,),
                                      );
                                    },
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  "Enable Private API Features",
                                  textScaleFactor: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () async {
                                await prefs.setBool('private-api-enable-tip', true);
                                Navigator.of(context).pop();
                              },
                              child: const Text("Don't ask again"),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }
        }

        final version = int.tryParse(response.data['data']['os_version'].split(".")[0]);
        final minorVersion = int.tryParse(response.data['data']['os_version'].split(".")[1]);
        final serverVersion = response.data['data']['server_version'];
        final code = Version.parse(serverVersion ?? "0.0.0");
        final versionCode = code.major * 100 + code.minor * 21 + code.patch;
        if (version != null) await prefs.setInt("macos-version", version);
        if (minorVersion != null) await prefs.setInt("macos-minor-version", minorVersion);
        if (serverVersion != null) await prefs.setString("server-version", serverVersion);
        await prefs.setInt("server-version-code", versionCode);
        return Tuple4(version ?? 11, minorVersion ?? 0, serverVersion, versionCode);
      } else {
        return const Tuple4(11, 0, "0.0.0", 0);
      }
    } else {
      return serverDetailsSync();
    }
  }

  Tuple4<int, int, String, int> serverDetailsSync() => Tuple4(prefs.getInt("macos-version") ?? 11, prefs.getInt("macos-minor-version") ?? 0,
      prefs.getString("server-version") ?? "0.0.0", prefs.getInt("server-version-code") ?? 0);

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

  bool get isMinCatalinaSync {
    return (prefs.getInt("macos-minor-version") ?? 11) >= 15 || isMinBigSurSync;
  }

  /// Group chats can be created on macOS <= Catalina or
  /// if the Private API is enabled, and the server supports it (v1.8.0).
  Future<bool> canCreateGroupChat() async {
    int serverVersion = (await ss.getServerDetails()).item4;
    bool isMin_1_8_0 = serverVersion >= 268; // Server: v1.8.0 (1 * 100 + 8 * 21 + 0)
    bool papiEnabled = settings.enablePrivateAPI.value;
    return (isMin_1_8_0 && papiEnabled) || !isMinBigSurSync;
  }

  /// Group chats can be created on macOS <= Catalina or
  /// if the Private API is enabled, and the server supports it (v1.8.0).
  bool canCreateGroupChatSync() {
    int serverVersion = ss.serverDetailsSync().item4;
    bool isMin_1_8_0 = serverVersion >= 268; // Server: v1.8.0 (1 * 100 + 8 * 21 + 0)
    bool papiEnabled = settings.enablePrivateAPI.value;
    return (isMin_1_8_0 && papiEnabled) || !isMinBigSurSync;
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
                Text(
                    "Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ?? "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}\n\nWarning: Installing the update will briefly disconnect you.",
                    style: context.theme.textTheme.bodyLarge)
            ],
          ),
          actions: [
            TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await prefs.setString("server-update-check", metadata['version']);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Install", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () async {
                await prefs.setString("server-update-check", metadata['version']);
                http.installUpdate();
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
            Text("Version: $version\nRelease Date: ${buildDate(release.createdAt)}\nRelease Name: ${release.name}",
                style: context.theme.textTheme.bodyLarge)
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
            onPressed: () async {
              await prefs.setString("client-update-check", code);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
