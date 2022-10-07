import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

DatabaseService fdb = Get.isRegistered<DatabaseService>() ? Get.find<DatabaseService>() : Get.put(DatabaseService());

class DatabaseService extends GetxService {
  /// Fetch the new server URL from the Firebase Database
  Future<String?> fetchNewUrl() async {
    // Make sure setup is complete and we have valid data
    if (!SettingsManager().settings.finishedSetup.value) return null;
    if (SettingsManager().fcmData?.isNull ?? true) {
      Logger.error("Firebase Data was null!");
      return null;
    }

    try {
      String? url;
      Logger.info("Fetching new server URL from Firebase");
      // Use firebase_dart on web and desktop
      if (kIsWeb || kIsDesktop) {
        // Instantiate the FirebaseDatabase, and try to access the serverUrl field
        final db = FirebaseDatabase(databaseURL: SettingsManager().fcmData?.firebaseURL);
        final ref = db.reference().child('config').child('serverUrl');

        ref.onValue.listen((event) {
          url = sanitizeServerAddress(address: event.snapshot.value);
        });
      } else {
        url = sanitizeServerAddress(address: await MethodChannelInterface().invokeMethod("get-server-url"));
      }
      // Update the address of the copied settings
      SettingsManager().settings.serverAddress.value = url ?? SettingsManager().settings.serverAddress.value;
      await SettingsManager().saveSettings();
      return url;
    } catch (e, s) {
      Logger.error("Failed to fetch URL: $e\n${s.toString()}");
      return null;
    }
  }
}