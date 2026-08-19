import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/server_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:github/github.dart' hide Source;
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:store_checker/store_checker.dart';
import 'package:bluebubbles/models/models.dart' show ServerDetails, AppUpdateInfo, ServerUpdateInfo;
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
SettingsService get SettingsSvc => GetIt.I<SettingsService>();

class SettingsService {
  late Settings settings;
  late FCMData fcmData;
  bool _canAuthenticate = false;
  bool _showingPapiPopup = false;
  Completer<void> initCompleted = Completer<void>();

  /// Cached server details. Populated from [PrefsSvc] on startup and refreshed
  /// in the background via [refreshServerDetails]. Access via the [serverDetails]
  /// getter; use [_serverDetails] within this class for reactive ([Obx]) access.
  final Rx<ServerDetails> _serverDetails = const ServerDetails.empty().obs;

  bool get canAuthenticate =>
      _canAuthenticate && (Platform.isWindows || (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) > 28);

  Future<void> init({bool headless = false}) async {
    settings = Settings.getSettings();
    // Populate server details from prefs so sync getters are usable immediately.
    _serverDetails.value = ServerDetails(
      macOSVersion: PrefsSvc.server.getMacOSVersion() ?? 11,
      macOSMinorVersion: PrefsSvc.server.getMacOSMinorVersion() ?? 0,
      serverVersion: PrefsSvc.server.getServerVersion() ?? "0.0.0",
      serverVersionCode: PrefsSvc.server.getServerVersionCode() ?? 0,
    );

    if (!headless && !kIsWeb && !kIsDesktop) {
      // Parallelize independent operations
      try {
        await Future.wait([
          LocalAuthentication().isDeviceSupported().then((value) => _canAuthenticate = value),
          settings.getDisplayMode().then((mode) {
            if (mode != DisplayMode.auto) {
              FlutterDisplayMode.setPreferredMode(mode);
            }
          }),
        ]);
      } catch (e, s) {
        Logger.warn("Failed to apply display mode or biometric check at startup",
            error: e, trace: s, tag: 'SettingsService');
      }
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
    // launch at startup - defer this so it doesn't block startup
    if (kIsDesktop) {
      Future.microtask(() async {
        if (Platform.isWindows) {
          try {
            _canAuthenticate = await LocalAuthentication().isDeviceSupported();
          } catch (_) {}
        }
        settings.launchAtStartup.value =
            await setupLaunchAtStartup(settings.launchAtStartup.value, settings.launchAtStartupMinimized.value);
      });
    }

    initCompleted.complete();
  }

  /// Returns true if LaunchAtStartup is enabled and false if it is disabled
  Future<bool> setupLaunchAtStartup(bool launchAtStartup, bool minimized) async {
    // Can't use fs here because it hasn't been initialized yet
    LaunchAtStartup.setup((await PackageInfo.fromPlatform()).appName, minimized);
    try {
      if (launchAtStartup) {
        return await LaunchAtStartup.enable();
      }
      await LaunchAtStartup.disable();
    } catch (e, s) {
      Logger.error('Failed to set launch at startup', error: e, trace: s, tag: 'SettingsService');
    }
    return false;
  }

  void loadFcmDataFromDatabase() {
    fcmData = FCMData.getFCM();
  }

  Future<void> updateDisplayMode() async {
    if (!kIsWeb && !kIsDesktop) {
      try {
        final mode = await settings.getDisplayMode();
        FlutterDisplayMode.setPreferredMode(mode);
      } catch (e, s) {
        Logger.warn("Failed to update display mode", error: e, trace: s, tag: 'SettingsService');
      }
    }
  }

  Future<void> saveFCMData(FCMData data) async {
    fcmData = data;
    await fcmData.save(wait: true);
  }

  Future<Map<String, dynamic>> getServerDetailsDict() async {
    final response = await HttpSvc.server.info();
    if (response.statusCode == 200) {
      final List<String> toSave = [];
      if (settings.iCloudAccount.isEmpty && response.data['data']['detected_icloud'] is String) {
        settings.iCloudAccount.value = response.data['data']['detected_icloud'];
        toSave.add('iCloudAccount');
      }

      if (response.data['data']['private_api'] is bool) {
        settings.serverPrivateAPI.value = response.data['data']['private_api'];
        toSave.add('serverPrivateAPI');
      }

      final version = int.tryParse(response.data['data']['os_version'].split(".")[0]);
      final minorVersion = int.tryParse(response.data['data']['os_version'].split(".")[1]);
      final serverVersion = response.data['data']['server_version'];
      final code = Version.parse(serverVersion ?? "0.0.0");
      final versionCode = code.major * 100 + code.minor * 21 + code.patch;
      await PrefsSvc.server.setServerDetails(
        macOSVersion: version,
        macOSMinorVersion: minorVersion,
        serverVersion: serverVersion,
        serverVersionCode: versionCode,
      );

      if (toSave.isNotEmpty) {
        await settings.saveManyAsync(toSave);
      }

      return {
        'macOSVersion': version ?? 11,
        'macOSMinorVersion': minorVersion ?? 0,
        'serverVersion': serverVersion ?? "0.0.0",
        'serverVersionCode': versionCode,
        'recommendPrivateApi': settings.finishedSetup.value &&
            settings.reachedConversationList.value &&
            !settings.enablePrivateAPI.value &&
            settings.serverPrivateAPI.value == true &&
            !PrefsSvc.server.hasSeenPrivateApiEnableTip(),
      };
    }

    return {
      'macOSVersion': 11,
      'macOSMinorVersion': 0,
      'serverVersion': "0.0.0",
      'serverVersionCode': 0,
      'recommendPrivateApi': false,
    };
  }

  /// Fetches server details via HTTP (main isolate), updates [serverDetails],
  /// and persists values to [PrefsSvc]. Also handles [iCloudAccount] and
  /// [serverPrivateAPI] side effects and shows the PAPI popup when applicable.
  /// Used during the first-time setup flow.
  Future<ServerDetails> fetchServerDetails() async {
    final detailsDict = await getServerDetailsDict();
    final details = ServerDetails(
      macOSVersion: detailsDict['macOSVersion'] as int,
      macOSMinorVersion: detailsDict['macOSMinorVersion'] as int,
      serverVersion: detailsDict['serverVersion'] as String,
      serverVersionCode: detailsDict['serverVersionCode'] as int,
    );
    _serverDetails.value = details;

    if (detailsDict['recommendPrivateApi'] as bool) {
      await _showPapiPopup();
    }

    return details;
  }

  /// Refreshes [serverDetails] in the background via [ServerInterface]
  /// (routes through the GlobalIsolate on all platforms). Updates [serverDetails]
  /// and persists the new values to [PrefsSvc]. Safe to call fire-and-forget.
  Future<void> refreshServerDetails() async {
    try {
      final details = await ServerInterface.getServerDetails();
      _serverDetails.value = details;

      await PrefsSvc.server.setServerDetails(
        macOSVersion: details.macOSVersion,
        macOSMinorVersion: details.macOSMinorVersion,
        serverVersion: details.serverVersion,
        serverVersionCode: details.serverVersionCode,
      );
    } catch (e, s) {
      Logger.warn("Failed to refresh server details", error: e, trace: s, tag: 'SettingsService');
    }
  }

  /// Returns the current cached [ServerDetails].
  ServerDetails getServerDetails() => _serverDetails.value;

  Future<void> _showPapiPopup() async {
    final ScrollController controller = ScrollController();
    if (_showingPapiPopup) Navigator.of(Get.context!).pop();
    _showingPapiPopup = true;
    await showBBDialog(
      context: Get.context!,
      barrierDismissible: false,
      title: "Private API Features",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: min(Get.context!.height / 3, Get.context!.height - 300)),
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
                    if (_serverDetails.value.isMinBigSur) const Text(" - Send replies"),
                    if (_serverDetails.value.isMinVentura) const Text(" - Edit & Unsend messages"),
                    const SizedBox(height: 10),
                    const Text(" - Mark chats read on the Mac server"),
                    if (_serverDetails.value.isMinVentura) const Text(" - Mark chats as unread on the Mac server"),
                    const SizedBox(height: 10),
                    const Text(" - Rename group chats"),
                    const Text(" - Add & remove people from group chats"),
                    if (_serverDetails.value.isMinBigSur) const Text(" - Change the group chat photo"),
                    if (_serverDetails.value.isMinBigSur) const SizedBox(height: 10),
                    if (_serverDetails.value.isMinMonterey) const Text(" - View Focus statuses"),
                    if (_serverDetails.value.isMinBigSur) const Text(" - Use Find My Friends"),
                    if (_serverDetails.value.isMinBigSur) const Text(" - Be notified of incoming FaceTime calls"),
                    if (_serverDetails.value.isMinVentura) const Text(" - Answer FaceTime calls (experimental)"),
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
                    await PrefsSvc.server.markPrivateApiEnableTipShown();
                    if (Get.context == null) return;
                    Navigator.of(Get.context!, rootNavigator: true).pop();
                    NavigationSvc.closeSettings(Get.context!);
                    NavigationSvc.closeAllConversationView(Get.context!);
                    await ChatsSvc.setAllInactive();
                    await Navigator.of(Get.context!).push(
                      ThemeSwitcher.buildPageRoute(
                        builder: (BuildContext context) {
                          return SettingsPage(
                            initialPage: PrivateAPIPanel(
                              enablePrivateAPIonInit: true,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Enable Private API Features",
                      textScaler: TextScaler.linear(1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () async {
                    await PrefsSvc.server.markPrivateApiEnableTipShown();
                    if (Get.context == null) return;
                    Navigator.of(Get.context!, rootNavigator: true).pop();
                  },
                  child: const Text("Don't ask again"),
                ),
              )
            ],
          ),
        ],
      ),
    );
    _showingPapiPopup = false;
  }

  /// Returns the current cached [ServerDetails].
  ServerDetails get serverDetails => _serverDetails.value;

  /// Group chats can be created on macOS <= Catalina or
  /// if the Private API is enabled, and the server supports it (v1.8.0).
  bool canCreateGroupChat() {
    return canCreateGroupChatSync();
  }

  /// Group chats can be created on macOS <= Catalina or
  /// if the Private API is enabled, and the server supports it (v1.8.0).
  bool canCreateGroupChatSync() {
    bool papiEnabled = settings.enablePrivateAPI.value;
    return (_serverDetails.value.supportsCreateGroupChat && papiEnabled) || !_serverDetails.value.isMinBigSur;
  }

  Future<Map<String, dynamic>> getServerUpdateDict() async {
    final response = await HttpSvc.server.checkUpdate();
    if (response.statusCode == 200) {
      bool available = response.data['data']['available'] ?? false;
      Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};

      return {
        'available': available,
        'metadata': metadata,
      };
    }

    return {
      'available': false,
      'metadata': <String, dynamic>{},
    };
  }

  Future<ServerUpdateInfo> checkForServerUpdate() async {
    final updateDict = await getServerUpdateDict();
    final metadata = updateDict['metadata'] as Map<String, dynamic>;

    return ServerUpdateInfo(
      available: updateDict['available'] as bool,
      version: metadata['version'] as String?,
      releaseDate: metadata['release_date'] as String?,
      releaseName: metadata['release_name'] as String?,
    );
  }

  Future<void> checkServerUpdate() async {
    late ServerUpdateInfo updateInfo;
    if (Platform.isAndroid) {
      updateInfo = await ServerInterface.checkForServerUpdate();
    } else {
      updateInfo = await checkForServerUpdate();
    }

    if (!updateInfo.available ||
        (updateInfo.version != null && PrefsSvc.server.getServerUpdateCheckVersion() == updateInfo.version)) {
      return;
    }

    showBBDialog(
      context: Get.context!,
      title: "Server Update Check",
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 15.0),
          Text(updateInfo.available ? "Updates available:" : "Your server is up-to-date!"),
          const SizedBox(height: 15.0),
          if (updateInfo.version != null)
            Text(
              "Version: ${updateInfo.version ?? "Unknown"}\nRelease Date: ${updateInfo.releaseDate ?? "Unknown"}\nRelease Name: ${updateInfo.releaseName ?? "Unknown"}\n\nWarning: Installing the update will briefly disconnect you.",
            )
        ],
      ),
      actions: [
        BBDialogAction(
          text: "OK",
          onPressed: () async {
            if (updateInfo.version != null) {
              await PrefsSvc.server.setServerUpdateCheckVersion(updateInfo.version!);
            }
            Navigator.of(Get.context!, rootNavigator: true).pop();
          },
        ),
        BBDialogAction(
          text: "Install",
          isDefault: true,
          onPressed: () async {
            if (updateInfo.version != null) {
              await PrefsSvc.server.setServerUpdateCheckVersion(updateInfo.version!);
            }
            HttpSvc.server.installUpdate();
            Navigator.of(Get.context!, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }

  /// Fetches the latest matching GitHub release for the app.
  ///
  /// With [channel] left `null`, this is the legacy/generic check (desktop):
  /// picks the newest non-draft, non-prerelease release, exactly as before
  /// this method learned about channels at all.
  ///
  /// With [channel] set, this is the Android GitHub-sideload auto-update
  /// flow: matches by the channel's tag marker (see [AppUpdateChannelInfo])
  /// and only considers releases that carry a `.apk` asset, since that's
  /// what gets installed.
  ///
  /// Both are thin wrappers over the shared fetch/parse helpers below — this
  /// just picks which one owns the request.
  Future<Map<String, dynamic>> getAppUpdateDict({AppUpdateChannel? channel}) async {
    return channel != null ? await _getChannelUpdateDict(channel) : await _getLegacyUpdateDict();
  }

  /// Newest non-draft, non-prerelease release — no channel awareness, no
  /// APK requirement. Availability requires being sideloaded specifically
  /// (stricter than [_getChannelUpdateDict]'s "just not the Play Store"),
  /// then narrows further per-platform: build-code comparison on Android,
  /// semver comparison everywhere else.
  Future<Map<String, dynamic>> _getLegacyUpdateDict() async {
    bool available = true;
    if (!kIsDesktop && (kIsWeb || (await StoreChecker.getSource) != Source.IS_INSTALLED_FROM_LOCAL_SOURCE)) {
      available = false;
    }
    if (kIsDesktop) {
      available = false;
    }

    final releases = await _fetchAppReleases();
    final release = releases.firstWhereOrNull(
        (element) => !(element.isDraft ?? false) && !(element.isPrerelease ?? false) && element.tagName != null);
    if (release?.tagName == null) {
      return _unavailableUpdateDict(release: release, channel: null);
    }

    final parsed = _parseReleaseTag(release!.tagName!);
    String buildNumber = "";
    if (Platform.isAndroid) {
      buildNumber =
          FilesystemSvc.packageInfo.buildNumber.lastChars(min(4, FilesystemSvc.packageInfo.buildNumber.length));
      if (!_isNewerBuild(parsed, buildNumber)) {
        available = false;
      }
    } else {
      final latest = _parseSemver(parsed.version);
      final current = _parseSemver(FilesystemSvc.packageInfo.version);
      if (current.compareTo(latest) < 0) {
        available = true;
      }
    }

    return _updateDict(
      available: available,
      release: release,
      parsed: parsed,
      buildNumber: buildNumber,
      channel: null,
    );
  }

  /// Matches a release on [channel]'s track that carries a `.apk` asset.
  /// Availability requires not being installed from the Play Store (any
  /// other source is eligible), then a genuinely newer build code.
  Future<Map<String, dynamic>> _getChannelUpdateDict(AppUpdateChannel channel) async {
    final available = Platform.isAndroid && (await StoreChecker.getSource) != Source.IS_INSTALLED_FROM_PLAY_STORE;

    final releases = await _fetchAppReleases();
    ReleaseAsset? apkAsset;
    final release = releases.firstWhereOrNull((element) {
      if (element.isDraft ?? false) return false;
      if (element.tagName == null) return false;
      if (!channel.matchesTag(element.tagName!)) return false;
      apkAsset = element.assets?.firstWhereOrNull((a) => (a.name ?? '').toLowerCase().endsWith('.apk'));
      return apkAsset != null;
    });
    if (release?.tagName == null) {
      return _unavailableUpdateDict(release: release, channel: channel);
    }

    final parsed = _parseReleaseTag(release!.tagName!);
    final buildNumber =
        FilesystemSvc.packageInfo.buildNumber.lastChars(min(4, FilesystemSvc.packageInfo.buildNumber.length));

    return _updateDict(
      available: available && _isNewerBuild(parsed, buildNumber),
      release: release,
      parsed: parsed,
      buildNumber: buildNumber,
      channel: channel,
      apkAsset: apkAsset,
    );
  }

  /// Fetches every release for the BlueBubbles app repo (newest first, per
  /// the GitHub API's default ordering) — the one network round-trip shared
  /// by both [_getLegacyUpdateDict] and [_getChannelUpdateDict].
  Future<List<Release>> _fetchAppReleases() async {
    final github = GitHub();
    try {
      return await github.repositories.listReleases(RepositorySlug('bluebubblesapp', 'bluebubbles-app')).toList();
    } finally {
      github.dispose();
    }
  }

  /// Splits a tag like `v1.2.3+400-desktop` into its numeric version, build
  /// code, and whether it's a desktop-flavored release.
  ({String version, String code, bool isDesktopRelease}) _parseReleaseTag(String tagName) {
    return (
      version: tagName.split("+").first.replaceAll("v", ""),
      code: tagName.split("+").last.split('-').first,
      isDesktopRelease: tagName.split('+').last.contains('desktop'),
    );
  }

  /// Whether [parsed]'s build code represents a real update over the running
  /// app: strictly newer, not already dismissed via [PrefsSvc], and not a
  /// desktop-flavored release (which would never apply on Android).
  bool _isNewerBuild(({String version, String code, bool isDesktopRelease}) parsed, String currentBuildNumber) {
    return int.parse(parsed.code) > int.parse(currentBuildNumber) &&
        PrefsSvc.server.getClientUpdateCheckCode() != parsed.code &&
        !parsed.isDesktopRelease;
  }

  Version _parseSemver(String version) {
    final parts = version.split(".");
    return Version(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  Map<String, dynamic> _unavailableUpdateDict({required Release? release, required AppUpdateChannel? channel}) {
    return {
      'available': false,
      'latestRelease': release,
      'isDesktopRelease': false,
      'channel': channel?.index,
      'parsedVersion': {'version': '', 'code': '', 'build': ''},
      'apkDownloadUrl': null,
      'apkAssetName': null,
      'apkSizeBytes': null,
    };
  }

  Map<String, dynamic> _updateDict({
    required bool available,
    required Release release,
    required ({String version, String code, bool isDesktopRelease}) parsed,
    required String buildNumber,
    required AppUpdateChannel? channel,
    ReleaseAsset? apkAsset,
  }) {
    return {
      'available': available,
      'latestRelease': release,
      'isDesktopRelease': parsed.isDesktopRelease,
      'channel': channel?.index,
      'parsedVersion': {
        'version': parsed.version,
        'code': parsed.code,
        'build': buildNumber,
      },
      'apkDownloadUrl': apkAsset?.browserDownloadUrl,
      'apkAssetName': apkAsset?.name,
      'apkSizeBytes': apkAsset?.size,
    };
  }

  Future<AppUpdateInfo> checkForUpdate({AppUpdateChannel? channel}) async {
    final updateDict = await getAppUpdateDict(channel: channel);
    final channelIndex = updateDict['channel'] as int?;
    return AppUpdateInfo(
      available: updateDict['available'] as bool,
      latestRelease: updateDict['latestRelease'] as Release?,
      isDesktopRelease: updateDict['isDesktopRelease'] as bool,
      channel: channelIndex != null ? AppUpdateChannel.values[channelIndex] : null,
      version: (updateDict['parsedVersion'] as Map<String, String>)['version']!,
      code: (updateDict['parsedVersion'] as Map<String, String>)['code']!,
      buildNumber: (updateDict['parsedVersion'] as Map<String, String>)['build']!,
      apkDownloadUrl: updateDict['apkDownloadUrl'] as String?,
      apkAssetName: updateDict['apkAssetName'] as String?,
      apkSizeBytes: updateDict['apkSizeBytes'] as int?,
    );
  }

  /// Generic/legacy update check — desktop only. Android uses
  /// `AppUpdateService` instead (see startup_tasks.dart), which calls through
  /// the same `AppInterface.checkForUpdate` / [getAppUpdateDict] but with an
  /// [AppUpdateChannel] so it gets track-matched, APK-asset-backed releases.
  Future<void> checkClientUpdate() async {
    final updateInfo = await checkForUpdate();
    if (!updateInfo.available || updateInfo.latestRelease == null) return;
    final latestRelease = updateInfo.latestRelease!;

    showBBDialog(
      context: Get.context!,
      title: "App Update Check",
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 15.0),
          const Text("Updates available:"),
          const SizedBox(height: 15.0),
          Text(
            "Version: ${updateInfo.version}\n"
            "Release Date: ${buildDate(latestRelease.createdAt)}\n"
            "Release Name: ${latestRelease.name}",
          ),
        ],
      ),
      actions: [
        if (latestRelease.htmlUrl != null)
          BBDialogAction(
            text: "Download",
            onPressed: () async {
              await launchUrl(Uri.parse(latestRelease.htmlUrl!), mode: LaunchMode.externalApplication);
            },
          ),
        BBDialogAction(
          text: "OK",
          isDefault: true,
          onPressed: () async {
            await PrefsSvc.server.setClientUpdateCheckCode(updateInfo.code);
            Navigator.of(Get.context!, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }
}
