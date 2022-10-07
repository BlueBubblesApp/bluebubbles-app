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
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class SetupBloc {
  // Setup as a Singleton
  static final SetupBloc _setupBloc = SetupBloc._internal();
  SetupBloc._internal();
  factory SetupBloc() {
    _setupBloc.fullSyncManager = FullSyncManager(
            messageCount: _setupBloc.numberOfMessagesPerPage.toInt(), skipEmptyChats: _setupBloc.skipEmptyChats);
    return _setupBloc;
  }

  late FullSyncManager fullSyncManager;
  IncrementalSyncManager? incrementalSyncManager;
  RxBool isIncrementalSyncing = false.obs;

  int numberOfMessagesPerPage = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;

  Future<void> startFullSync() async {
    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await SettingsManager().saveSettings(_settingsCopy);

    fullSyncManager = FullSyncManager(
      messageCount: numberOfMessagesPerPage.toInt(), skipEmptyChats: skipEmptyChats, saveLogs: saveToDownloads);
    await fullSyncManager.start();
    await finishSetup();
    await startIncrementalSync();
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
    String? token = socket.token;
    if (token != null && !force) {
      Logger.debug("Already authorized FCM device! Token: $token", tag: 'FCM-Auth');
      await http.addFcmDevice(deviceName, token);
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
        dio.Response fcmResponse = await http.fcmClient();
        Logger.info('Received FCM data from the server. Attempting to re-authenticate', tag: 'FCM-Auth');

        // Parse out the new FCM data
        if (fcmResponse.data["data"] != null) {
          FCMData fcmData = parseFcmJson(fcmResponse.data["data"]);

          // Save the FCM data in settings
          SettingsManager().saveFCMData(fcmData);

          // Retry authenticating with Firebase
          result = await MethodChannelInterface().invokeMethod('auth', SettingsManager().fcmData!.toMap());
        }
      } on PlatformException catch (e) {
        if (!catchException) {
          throw Exception("[FCM Auth] -> $e");
        } else {
          Logger.error("Failed to register with FCM: $e", tag: 'FCM-Auth');
        }
      }
    }

    if (isNullOrEmpty(result)!) {
      Logger.error("Empty results, not registering device with the server.", tag: 'FCM-Auth');
    }

    try {
      token = result;
      Logger.info('Registering device with server...', tag: 'FCM-Auth');
      await http.addFcmDevice(deviceName, token!);
    } catch (ex) {
      Logger.error('[FCM Auth] -> Failed to register device with server: ${ex.toString()}');
      throw Exception("Failed to add FCM device to the server! Token: $token");
    }
  }

  Future<void> startIncrementalSync({String? chatGuid, bool saveDate = true, Function? onComplete}) async {
    isIncrementalSyncing.value = true;
    try {
      int syncStart = SettingsManager().settings.lastIncrementalSync.value;
      incrementalSyncManager = IncrementalSyncManager(syncStart, chatGuid: chatGuid, saveDate: saveDate, onComplete: onComplete);
      await incrementalSyncManager!.start();
    } catch (ex) {
      Logger.error('Incremental sync failed! Error: $ex');
    } finally {
      isIncrementalSyncing.value = false;
    }
  }
}
