import 'dart:async';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Get an instance of our [CloudMessagingService]
CloudMessagingService fcm = Get.isRegistered<CloudMessagingService>()
    ? Get.find<CloudMessagingService>() : Get.put(CloudMessagingService());

/// Manager for registering the client with the server FCM client (used for notifications)
///
/// This pertains to Android only, Desktop and Web only subscribe to the Firebase
/// Database using the `firebase_dart` package
class CloudMessagingService extends GetxService {
  String? token;

  /// So we can track the progress of the device registration process
  Completer<void>? completer;

  /// Register this device with FCM
  Future<void> registerDevice() async {
    // Make sure setup is complete, and that we aren't currently registering with FCM
    // Users can also choose to disable FCM in settings
    if (!ss.settings.finishedSetup.value || ss.settings.keepAppAlive.value) return;

    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    // Get a unique name for this device
    String deviceName = await getDeviceName();
    bool closeCompleter = false;

    // Make sure FCM data is available
    if (ss.fcmData.isNull) {
      Logger.warn("No FCM Auth data found. Skipping FCM authentication", tag: 'FCM-Auth');
      closeCompleter = true;
    }

    // If we've already got a token, re-register with this token
    if (!isNullOrEmpty(token)!) {
      Logger.debug("Already authorized FCM device! Token: $token", tag: 'FCM-Auth');
      Logger.info('Registering device with server...', tag: 'FCM-Auth');
      await http.addFcmDevice(deviceName.trim(), token!.trim()).then((_) {
        Logger.info('Device registration successful!', tag: 'FCM-Auth');
        completer?.complete();
      }).catchError((ex) {
        completer?.completeError(ex);
        throw Exception("Failed to add FCM device to the server! Token: $token, ${ex.toString()}");
      });
      closeCompleter = true;
    }

    // Don't do anything if on web or desktop
    if (kIsWeb || kIsDesktop) {
      Logger.debug("Platform ${kIsWeb ? "web" : Platform.operatingSystem} detected, not authing with FCM!",
          tag: 'FCM-Auth');
      closeCompleter = true;
    }

    // Close out of the registration process when requested
    if (closeCompleter) {
      if (!(completer?.isCompleted ?? false)) {
        completer?.complete();
      }
      return;
    }

    String? result;

    try {
      // First, try to auth with FCM with the current data
      Logger.info('Authenticating with FCM', tag: 'FCM-Auth');
      result = await mcs.invokeMethod('auth', ss.fcmData.toMap());
    } on PlatformException catch (ex) {
      Logger.error('Failed to perform initial FCM authentication: ${ex.toString()}', tag: 'FCM-Auth');

      // If the first try fails, let's try again with new FCM data from the server
      Logger.info('Fetching FCM data from the server...', tag: 'FCM-Auth');
      final response = await http.fcmClient();

      // If we get valid FCM data, redo the FCM auth, otherwise error out
      if (response.statusCode == 200 && response.data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> fcmMeta = response.data['data'];
        Logger.info('Received FCM data from the server. Attempting to re-authenticate', tag: 'FCM-Auth');

        try {
          // Parse and save new FCM data, then retry auth with FCM
          FCMData fcmData = FCMData.fromMap(fcmMeta);
          ss.saveFCMData(fcmData);
          result = await mcs.invokeMethod('auth', fcmData.toMap());
        } on PlatformException catch (e) {
          // If we fail a second time, error out
          Logger.error("Failed to register with FCM: $e", tag: 'FCM-Auth');
          completer?.completeError(e);
          return;
        }
      } else {
        Logger.error('Failed to register with FCM - API error ${response.statusCode}: ${response.data}', tag: 'FCM-Auth');
        completer?.completeError("API Error ${response.statusCode}");
        return;
      }
    }

    // Make sure we got a valid response back from the FCM auth
    if (isNullOrEmpty(result)!) {
      Logger.error("Empty results, not registering device with the server.", tag: 'FCM-Auth');
      completer?.complete();
      return;
    }

    // Register the FCM device to the server
    token = result;
    Logger.info('Registering device with server...', tag: 'FCM-Auth');
    await http.addFcmDevice(deviceName.trim(), token!.trim()).then((_) {
      Logger.info('Device registration successful!', tag: 'FCM-Auth');
      completer?.complete();
    }).catchError((ex) {
      completer?.completeError(ex);
      throw Exception("Failed to add FCM device to the server! Token: $token, ${ex.toString()}");
    });
  }
}
