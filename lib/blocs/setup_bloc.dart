import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/sync/full_sync_manager.dart';
import 'package:bluebubbles/managers/sync/incremental_sync_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SetupBloc {
  // Setup as a Singleton
  static final SetupBloc _setupBloc = SetupBloc._internal();
  SetupBloc._internal();
  factory SetupBloc() {
    _setupBloc.syncManager ??= FullSyncManager(
        messageCount: _setupBloc.numberOfMessagesPerPage.toInt(), skipEmptyChats: _setupBloc.skipEmptyChats);
    return _setupBloc;
  }

  FullSyncManager? syncManager;
  IncrementalSyncManager? incrementalSyncManager;

  final RxBool isIncrementalSyncing = false.obs;
  double numberOfMessagesPerPage = 25;
  bool skipEmptyChats = true;

  Future<void> startFullSync(Settings settings) async {
    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await SettingsManager().saveSettings(_settingsCopy);

    syncManager = FullSyncManager(messageCount: numberOfMessagesPerPage.toInt(), skipEmptyChats: skipEmptyChats);
    await syncManager!.start();
    await finishSetup();

    await startIncrementalSync(SettingsManager().settings);
  }

  Future<void> finishSetup() async {
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup.value = true;
    await SettingsManager().saveSettings(_settingsCopy);
    await registerFcmDevice(force: true);
  }

  Future<void> registerFcmDevice({bool catchException = true, bool force = false}) async {
    if (!SettingsManager().settings.finishedSetup.value) return;

    if (SettingsManager().fcmData!.isNull) {
      Logger.warn("No FCM Auth data found. Skipping FCM authentication", tag: 'FCM-Auth');
      return;
    }

    String deviceName = await getDeviceName();
    String? token = SocketManager().token;
    if (token != null && !force) {
      Logger.debug("Already authorized FCM device! Token: $token", tag: 'FCM-Auth');
      await api.addFcmDevice(deviceName, token);
      return;
    }

    String? result;

    if (kIsWeb || kIsDesktop) {
      Logger.debug("Platform ${kIsWeb ? "web" : Platform.operatingSystem} detected, not authing with FCM!",
          tag: 'FCM-Auth');
      return;
    }

    try {
      // First, try to send what we currently have
      Logger.info('Authenticating with FCM', tag: 'FCM-Auth');
      result = await MethodChannelInterface().invokeMethod('auth', SettingsManager().fcmData!.toMap());
    } on PlatformException catch (ex) {
      Logger.error('Failed to perform initial FCM authentication: ${ex.toString()}', tag: 'FCM-Auth');
      Logger.info('Fetching FCM data from the server...', tag: 'FCM-Auth');

      try {
        // If the first try fails, let's try again, but first, get the FCM data from the server
        dio.Response fcmResponse = await api.fcmClient();
        Logger.info('Received FCM data from the server. Attempting to re-authenticate', tag: 'FCM-Auth');

        // Parse out the new FCM data
        FCMData fcmData = parseFcmJson(fcmResponse.data["data"]);

        // Save the FCM data in settings
        SettingsManager().saveFCMData(fcmData);

        // Retry authenticating with Firebase
        result = await MethodChannelInterface().invokeMethod('auth', SettingsManager().fcmData!.toMap());
      } on PlatformException catch (e) {
        if (!catchException) {
          throw Exception("[FCM Auth] -> " + e.toString());
        } else {
          Logger.error("Failed to register with FCM: " + e.toString(), tag: 'FCM-Auth');
        }
      }
    }

    if (isNullOrEmpty(result)!) {
      Logger.error("Empty results, not registering device with the server.", tag: 'FCM-Auth');
    }

    try {
      token = result;
      Logger.info('Registering device with server...', tag: 'FCM-Auth');
      await api.addFcmDevice(deviceName, token!);
    } catch (ex) {
      Logger.error('[FCM Auth] -> Failed to register device with server: ${ex.toString()}');
      throw Exception("Failed to add FCM device to the server! Token: $token");
    }
  }

  Future<void> startIncrementalSync(Settings settings,
      {String? chatGuid, bool saveDate = true, Function? onConnectionError, Function? onComplete}) async {
    // If we are already syncing, don't sync again
    // Or, if we haven't finished setup, or we aren't connected, don't sync
    if (isIncrementalSyncing.value ||
        !settings.finishedSetup.value ||
        SocketManager().state.value != SocketState.CONNECTED) {
      return;
    }

    int syncStart = DateTime.now().millisecondsSinceEpoch;
    final incrementalSyncManager = IncrementalSyncManager(syncStart);

    // Store the time we started syncing
    incrementalSyncManager.addToOutput("Starting incremental sync for messages since: ${settings.lastIncrementalSync}");
    incrementalSyncManager.start();

    // Once we have added everything, save the last sync date
    if (saveDate) {
      incrementalSyncManager.addToOutput("Saving last sync date: $syncStart");

      Settings _settingsCopy = SettingsManager().settings;
      _settingsCopy.lastIncrementalSync.value = syncStart;
      SettingsManager().saveSettings(_settingsCopy);
    }

    if (SettingsManager().settings.showIncrementalSync.value) {
      showSnackbar('Success', '🔄 Incremental sync complete 🔄');
    }

    if (onComplete != null) {
      onComplete();
    }
  }
}
