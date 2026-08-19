import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/interfaces/app_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: non_constant_identifier_names
AppUpdateService get UpdateSvc => GetIt.I<AppUpdateService>();

/// Android-only GitHub-release auto-update checker.
///
/// Fetches through the same [AppInterface.checkForUpdate] / `getAppUpdateDict`
/// path the generic/desktop update check uses (see `SettingsService`), just
/// with an [AppUpdateChannel] so the match is track- and APK-asset-aware.
/// Only active when the app was not installed from the Play Store, which
/// `getAppUpdateDict` checks via `store_checker`.
class AppUpdateService {
  final RxBool checking = false.obs;
  final RxBool updateAvailable = false.obs;
  final Rx<AppUpdateInfo?> availableUpdate = Rx<AppUpdateInfo?>(null);

  /// Download progress in `[0, 1]`, or `null` when no download is in progress.
  final Rx<double?> downloadProgress = Rx<double?>(null);

  bool _intervalElapsed() {
    final last = SettingsSvc.settings.lastUpdateCheckMillis.value;
    if (last == 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= SettingsSvc.settings.updateCheckInterval.value.duration.inMilliseconds;
  }

  /// Checks GitHub for a newer release on the configured track.
  ///
  /// When [manual] is `false` (startup / app-resume checks), this respects
  /// [Settings.autoUpdateCheckEnabled] and the configured check interval, and
  /// prompts the user with a dialog if a newer release is found and they are
  /// not currently in a conversation. It also advances
  /// [Settings.lastUpdateCheckMillis] so the schedule moves forward.
  ///
  /// When [manual] is `true` (the "Check for Updates" button in Settings),
  /// none of that gating applies and the schedule is left untouched — only
  /// [updateAvailable]/[availableUpdate] are refreshed for the settings page
  /// to render.
  Future<void> checkForUpdate({bool manual = false}) async {
    if (!Platform.isAndroid) return;
    if (checking.value) return;
    if (!manual) {
      if (!SettingsSvc.settings.autoUpdateCheckEnabled.value) return;
      if (!_intervalElapsed()) return;
    }

    checking.value = true;
    try {
      final channel = SettingsSvc.settings.updateChannel.value;
      final info = await AppInterface.checkForUpdate(channel: channel);

      if (!manual) {
        SettingsSvc.settings.lastUpdateCheckMillis.value = DateTime.now().millisecondsSinceEpoch;
        unawaited(SettingsSvc.settings.saveOneAsync('lastUpdateCheckMillis'));
      }

      updateAvailable.value = info.available;
      availableUpdate.value = info.available ? info : null;

      if (info.available && !manual) {
        _maybeShowUpdateDialog(info);
      }
    } catch (ex, stack) {
      Logger.warn("Failed to check for app update", error: ex, trace: stack, tag: "AppUpdateService");
    } finally {
      checking.value = false;
    }
  }

  void _maybeShowUpdateDialog(AppUpdateInfo info) {
    if (ChatsSvc.activeChat != null) return;
    final context = Get.context;
    if (context == null) return;

    showBBDialog(
      context: context,
      title: "Update Available",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Version ${info.version}${info.channelSuffix} is available."),
          const SizedBox(height: 8),
          Text("You're currently on ${FilesystemSvc.packageInfo.version}."),
        ],
      ),
      actions: [
        BBDialogAction(
          text: "Not Now",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        if (info.latestRelease?.htmlUrl != null)
          BBDialogAction(
            text: "Changelog",
            onPressed: () async {
              await launchUrl(Uri.parse(info.latestRelease!.htmlUrl!), mode: LaunchMode.externalApplication);
            },
          ),
        BBDialogAction(
          text: "Update Now",
          isDefault: true,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            downloadAndInstall(info);
          },
        ),
      ],
    );
  }

  /// Downloads [info]'s APK asset and hands it to the system installer via
  /// `open_filex`, which launches the `ACTION_VIEW` install intent — the app
  /// acts as the install source for its own update.
  Future<void> downloadAndInstall(AppUpdateInfo info) async {
    if (!Platform.isAndroid) return;
    final apkUrl = info.apkDownloadUrl;
    if (apkUrl == null) {
      Logger.warn("No APK asset URL on update info, cannot install", tag: "AppUpdateService");
      return;
    }

    final dio = Dio();
    try {
      downloadProgress.value = 0;
      final dir = await getTemporaryDirectory();
      final path = join(dir.path, info.apkAssetName ?? "bluebubbles-update.apk");
      await dio.download(
        apkUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) downloadProgress.value = received / total;
        },
      );

      final result = await OpenFilex.open(path, type: "application/vnd.android.package-archive");
      if (result.type != ResultType.done) {
        Logger.warn("Could not open downloaded APK: ${result.message}", tag: "AppUpdateService");
        showToast("Unable to start the installer: ${result.message}", isError: true);
      }
    } catch (ex, stack) {
      Logger.error("Failed to download app update", error: ex, trace: stack, tag: "AppUpdateService");
      showToast("Failed to download the update", isError: true);
    } finally {
      downloadProgress.value = null;
      dio.close();
    }
  }
}
