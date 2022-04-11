import 'dart:async';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Get an instance of our [DatabaseManager]
DatabaseManager fdb = Get.isRegistered<DatabaseManager>() ? Get.find<DatabaseManager>() : Get.put(DatabaseManager());

/// Manager for registering the client with the server FCM client (used for notifications)
///
/// This pertains to Android only, Desktop and Web only subscribe to the Firebase
/// Database using the `firebase_dart` package
class DatabaseManager extends GetxService {
  /// So we can track the progress of the device registration process
  Completer<void>? completer;

  /// Updates and saves a new server address and then forces a new reconnection
  /// to the socket with this address
  Future<void> connectNewAddress(String? serverAddress, {bool shouldReconnect = true}) async {
    if (SettingsManager().settings.serverAddress.value == serverAddress || serverAddress == null) {
      Logger.debug("Server address didn't actually change. Ignoring...");
      return;
    }

    // Update the address of the copied settings
    SettingsManager().settings.serverAddress.value = sanitizeServerAddress(address: serverAddress)
        ?? SettingsManager().settings.serverAddress.value;

    // And then save to disk
    // NOTE: we do not automatically connect to the socket or authorize fcm,
    //       because we need to do that manually with a forced connection
    await SettingsManager().saveSettings();

    // Then we connect to the socket.
    // We force a connection because the socket may still be attempting to connect to the socket,
    // in which case it won't attempt to connect again.
    // We need to override this behavior.
    if (shouldReconnect) {
      if (serverAddress.contains("trycloudflare.com")) {
        Logger.info("Detected Cloudflare URL, waiting 10 seconds before connecting to socket at: $serverAddress");
        Future.delayed(Duration(seconds: 10), () {
          SocketManager().startSocketIO(forceNewConnection: true);
        });
      } else {
        SocketManager().startSocketIO(forceNewConnection: true);
      }
    }
  }

  /// Fetch the new server URL from the Firebase Database
  Future<void> fetchNewUrl({bool connectToSocket = true}) async {
    // Make sure setup is complete, and that we aren't currently refreshing connection
    if (!SettingsManager().settings.finishedSetup.value) return;

    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    try {
      String? url;
      Logger.info("Fetching new server URL from Firebase");

      // Use firebase_dart on web and desktop
      if (kIsWeb || kIsDesktop) {
        // Make suer we have valid FCM data
        if (SettingsManager().fcmData?.isNull ?? true) {
          Logger.error("Firebase Data was null!");
          completer?.completeError("Null Firebase Data");
          return;
        }

        // Instantiate the FirebaseDatabase, and try to access the serverUrl field
        final db = FirebaseDatabase(databaseURL: SettingsManager().fcmData?.firebaseURL);
        final ref = db.reference().child('config').child('serverUrl');

        ref.onValue.listen((event) {
          url = sanitizeServerAddress(address: event.snapshot.value);
        });
      } else {
        url = sanitizeServerAddress(address: await MethodChannelInterface().invokeMethod("get-server-url"));
      }

      connectNewAddress(url, shouldReconnect: connectToSocket);
    } catch (e, s) {
      Logger.error("Failed to fetch URL: $e\n${s.toString()}");
      completer?.completeError(e);
      return;
    }
    completer?.complete();
  }
}
