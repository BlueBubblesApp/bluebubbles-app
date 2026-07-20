import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:get_it/get_it.dart';

/// Get an instance of our [CloudMessagingService]
// ignore: non_constant_identifier_names
CloudMessagingService get FirebaseSvc => GetIt.I<CloudMessagingService>();

/// Manager for registering the client with the server FCM client (used for notifications)
///
/// This pertains to Android only, Desktop and Web only subscribe to the Firebase
/// Database using the `firebase_dart` package
class CloudMessagingService {
  String? token;

  /// So we can track the progress of the device registration process
  Completer<void>? completer;

  /// Register this device with FCM
  Future<void> registerDevice() async {
    // Make sure setup is complete, and that we aren't currently registering with FCM
    // Users can also choose to disable FCM in settings
    if (!SettingsSvc.settings.finishedSetup.value || SettingsSvc.settings.keepAppAlive.value) return;

    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    // The completer must always resolve here, no matter which path _registerDevice()
    // takes (return, throw, or an exception type neither of its catch clauses expects).
    // Leaving it pending would hang every future caller of registerDevice() forever,
    // since they all await this same completer while one is in-flight (see above).
    try {
      await _registerDevice();
      if (!completer!.isCompleted) completer!.complete();
    } catch (e, s) {
      if (!completer!.isCompleted) completer!.completeError(e, s);
      rethrow;
    }
  }

  Future<void> _registerDevice() async {
    // Get a unique name for this device
    bool closeCompleter = false;

    // Make sure FCM data is available
    if (SettingsSvc.fcmData.isNull) {
      Logger.warn("No FCM Auth data found. Skipping FCM authentication", tag: 'FCM-Auth');
      closeCompleter = true;
    }

    // If we've already got a token, re-register with this token
    if (!isNullOrEmpty(token)) {
      Logger.debug("Already authorized FCM device! Token: $token", tag: 'FCM-Auth');
      Logger.info('Registering device with server...', tag: 'FCM-Auth');
      String deviceName = await getDeviceName();
      await HttpSvc.fcm.addDevice(deviceName.trim(), token!.trim()).then((_) {
        Logger.info('Device registration successful!', tag: 'FCM-Auth');
      }).catchError((ex) {
        throw Exception("Failed to add FCM device to the server! Token: $token, ${ex.toString()}");
      });
      closeCompleter = true;
    }

    // Don't do anything if on web or desktop
    if (kIsWeb || kIsDesktop) {
      await getOrCreateUniqueId();
      Logger.debug("Platform ${kIsWeb ? "web" : Platform.operatingSystem} detected, not authing with FCM!",
          tag: 'FCM-Auth');
      closeCompleter = true;
    }

    // Close out of the registration process when requested
    if (closeCompleter) {
      return;
    }

    String? result;

    try {
      // First, try to auth with FCM with the current data
      Logger.info('Authenticating with FCM', tag: 'FCM-Auth');
      result = await MethodChannelSvc.actions.firebaseAuth(fcmData: SettingsSvc.fcmData.toMap());
    } on PlatformException catch (ex, stack) {
      // Don't try to re-auth if device is de-Googled
      if (ex.toString().contains("Google Play Services is not available")) return;
      Logger.error('Failed to perform initial FCM authentication!', error: ex, trace: stack, tag: 'FCM-Auth');

      // If the first try fails, let's try again with new FCM data from the server
      Logger.info('Fetching FCM data from the server...', tag: 'FCM-Auth');
      final response = await HttpSvc.fcm.getServiceAccount().catchError((err) {
        if (err is Response) {
          return err;
        } else {
          return Response(requestOptions: RequestOptions(), statusCode: 500);
        }
      });

      // If we get valid FCM data, redo the FCM auth, otherwise error out
      if (response.statusCode == 200 && response.data['data'] is Map<String, dynamic>) {
        Map<String, dynamic> fcmMeta = response.data['data'];
        Logger.info('Received FCM data from the server. Attempting to re-authenticate', tag: 'FCM-Auth');

        try {
          // Parse and save new FCM data, then retry auth with FCM
          FCMData fcmData = FCMData.fromMap(fcmMeta);
          await SettingsSvc.saveFCMData(fcmData);
          result = await MethodChannelSvc.actions.firebaseAuth(fcmData: fcmData.toMap());
        } on PlatformException catch (e, stack) {
          // If we fail a second time, error out
          Logger.error("Failed to register with FCM", error: e, trace: stack, tag: 'FCM-Auth');
          rethrow;
        }
      } else {
        Logger.error('Failed to register with FCM - API error ${response.statusCode}: ${response.data}',
            tag: 'FCM-Auth');
        throw Exception("API Error ${response.statusCode}");
      }
    }

    // Make sure we got a valid response back from the FCM auth
    if (isNullOrEmpty(result)) {
      Logger.warn("Empty results, not registering device with the server.", tag: 'FCM-Auth');
      throw Exception(
          "Failed to get an FCM token from Firebase (empty result). This can happen if Firebase was "
          "already initialized with stale credentials in this app session. Try fully closing and "
          "reopening the app.");
    }

    // Register the FCM device to the server
    token = result;
    Logger.info('Registering device with server...', tag: 'FCM-Auth');
    String deviceName = await getDeviceName();
    await HttpSvc.fcm.addDevice(deviceName.trim(), token!.trim()).then((_) {
      Logger.info('Device registration successful!', tag: 'FCM-Auth');
    }).catchError((ex) {
      throw Exception("Failed to add FCM device to the server! Token: $token, ${ex.toString()}");
    });
  }
}
