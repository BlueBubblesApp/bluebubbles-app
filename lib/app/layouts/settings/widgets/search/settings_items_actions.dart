import 'package:bluebubbles/app/layouts/settings/widgets/tiles/contact_upload_progress.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/global/settings.dart';
import 'package:bluebubbles/database/io/fcm_data.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:in_app_review/in_app_review.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsItemsActions {
  static const String donateHost = "bluebubbles.app";
  static const String donatePath = "donate";
  static const String discordHost = "discord.gg";
  static const String discordPath = "hbx7EhNFjp";

  static Future<void> exportContacts({
    required BuildContext context,
    required RxnDouble progress,
    required RxnInt totalSize,
    required RxBool uploadingContacts,
  }) async {
    BuildContext? dialogCtx;

    void closeDialog() {
      Get.closeAllSnackbars();
      if (dialogCtx != null) {
        Navigator.of(dialogCtx!).pop();
      }
      Future.delayed(const Duration(milliseconds: 400), () {
        progress.value = null;
        totalSize.value = null;
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        dialogCtx = dialogContext;
        return ContactUploadProgress(
          progress: progress,
          totalSize: totalSize,
          uploadingContacts: uploadingContacts,
          onClose: closeDialog,
        );
      },
    );

    final contacts = <Map<String, dynamic>>[];
    final allContacts = await ContactsSvcV2.getAllContacts();
    for (final contact in allContacts) {
      contacts.add(contact.toMap());
    }

    HttpSvc.contact.create(
      contacts,
      onSendProgress: (count, total) {
        uploadingContacts.value = true;
        progress.value = count / total;
        totalSize.value = total;
        if (progress.value == 1.0) {
          uploadingContacts.value = false;
          showSnackbar("Notice", "Successfully exported contacts to server");
        }
      },
    ).catchError((err, stack) {
      if (err is Response) {
        Logger.error(err.data["error"]["message"].toString(), error: err, trace: stack);
      } else {
        Logger.error("Failed to create contact!", error: err, trace: stack);
      }

      closeDialog();
      showSnackbar("Error", "Failed to export contacts to server");
      return Response(requestOptions: RequestOptions(path: ''));
    });
  }

  static Future<void> openStoreReview() async {
    final inAppReview = InAppReview.instance;
    await inAppReview.openStoreListing(microsoftStoreId: '9P3XF8KJ0LSM');
  }

  static Future<void> openDonationPage() async {
    await launchUrl(
      Uri(scheme: "https", host: donateHost, path: donatePath),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> openDiscord() async {
    await launchUrl(
      Uri(scheme: "https", host: discordHost, path: discordPath),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Wipes the app back to a fresh-install state: every ObjectBox box (including
  /// theme entries), every on-disk cache directory (attachments, custom avatars,
  /// custom wallpapers, URL previews, contact avatars), all SharedPreferences-backed
  /// settings, and FCM/Firebase data. Scheduled messages live server-side and aren't
  /// stored locally, so there's nothing to clear for them here.
  ///
  /// `PrefsSvc.admin.clearAll()` must run BEFORE the fresh `Settings()` is saved —
  /// it's an unscoped wipe of the single shared preferences store behind every
  /// `PrefsSvc.*` category, so running it after would silently discard the
  /// freshly-written defaults (including `finishedSetup`).
  static Future<void> resetApp() async {
    Database.reset();
    await FilesystemSvc.deleteCacheDirectories();
    SocketSvc.forgetConnection();

    await PrefsSvc.admin.clearAll();

    SettingsSvc.settings = Settings();
    await SettingsSvc.settings.saveAsync();

    await PrefsSvc.theme.setSelectedThemes(darkTheme: "OLED Dark", lightTheme: "Bright White");
    Database.themes.putMany(ThemesService.defaultThemes);

    await FCMData.deleteFcmData();

    try {
      if (FirebaseSvc.token != null) {
        await MethodChannelSvc.actions.firebaseDeleteToken();
      }
    } catch (e, s) {
      Logger.error("Failed to delete Firebase FCM token", error: e, trace: s);
    }

    exit(0);
  }
}
