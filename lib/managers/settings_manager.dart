import 'dart:async';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// [SettingsManager] is responsible for making the current settings accessible to other managers and for saving new settings
///
/// The class also holds miscelaneous stuff such as the [appDocDir] which is used a lot throughout the app
/// This class is a singleton
class SettingsManager {
  factory SettingsManager() {
    return _manager;
  }

  static final SettingsManager _manager = SettingsManager._internal();

  SettingsManager._internal();

  /// [appDocDir] is just a directory that is commonly used
  /// It cannot be accessed by the user, and is private to the app
  late Directory appDocDir;

  /// [settings] is just an instance of the current settings that are saved
  late Settings settings;
  FCMData? fcmData;
  late List<ThemeObject> themes;
  String? countryCode;
  int? _macOSVersion;
  String? _serverVersion;
  bool canAuthenticate = false;

  int get compressionQuality {
    if (settings.lowMemoryMode.value) {
      return 10;
    }

    return SettingsManager().settings.previewCompressionQuality.value;
  }

  /// [init] is run at start and fetches both the [appDocDir] and sets the [settings] to a default value
  Future<void> init() async {
    settings = new Settings();
    if (!kIsWeb) {
      //ignore: unnecessary_cast, we need this as a workaround
      appDocDir = (await getApplicationSupportDirectory()) as Directory;
    }
    canAuthenticate = !kIsWeb && !kIsDesktop && await LocalAuthentication().isDeviceSupported();
  }

  /// Retreives files from disk and stores them in [settings]
  ///
  ///
  /// @param [headless] determines whether the socket will be started automatically and fcm will be initialized.
  ///
  /// @param [context] is an optional parameter to be used for setting the adaptive theme based on the settings.
  /// Setting to null will prevent the theme from being set and will be set to null in the background isolate
  Future<void> getSavedSettings({bool headless = false, BuildContext? context}) async {
    if (!headless) {
      for (ThemeObject theme in Themes.themes) {
        await theme.save(updateIfAbsent: false);
      }
    }
    settings = Settings.getSettings();

    fcmData = await FCMData.getFCM();
    if (headless) return;
    // await DBProvider.setupDefaultPresetThemes(await DBProvider.db.database);
    themes = await ThemeObject.getThemes();
    for (ThemeObject theme in themes) {
      await theme.fetchData();
    }

    // // If [context] is null, then we can't set the theme, and we shouldn't anyway
    await loadTheme(context);

    try {
      // Set the [displayMode] to that saved in settings
      if (!kIsWeb && !kIsDesktop) {
        await FlutterDisplayMode.setPreferredMode(await settings.getDisplayMode());
      }
    } catch (e) {}

    // Change the [finishedSetup] status to that of the settings
    if (!settings.finishedSetup.value) {
      attachmentBox.removeAll();
      chatBox.removeAll();
      fcmDataBox.removeAll();
      handleBox.removeAll();
      messageBox.removeAll();
      scheduledBox.removeAll();
      themeEntryBox.removeAll();
      themeObjectBox.removeAll();
      amJoinBox.removeAll();
      chJoinBox.removeAll();
      cmJoinBox.removeAll();
      tvJoinBox.removeAll();
    }
    SocketManager().finishedSetup.sink.add(settings.finishedSetup.value);

    // If we aren't running in the background, then we should auto start the socket and authorize fcm just in case we haven't
    if (!headless) {
      try {
        SocketManager().startSocketIO();
        SocketManager().authFCM();
      } catch (e) {}
    }
  }

  /// Saves a [Settings] instance to disk
  ///
  /// @param [newSettings] are the settings to save
  Future<void> saveSettings(Settings newSettings) async {
    // Set the new settings as the current settings in the manager
    settings = newSettings;
    settings.save();
    try {
      // Set the [displayMode] to that saved in settings
      if (!kIsWeb && !kIsDesktop) {
        await FlutterDisplayMode.setPreferredMode(await settings.getDisplayMode());
      }
    } catch (e) {}
  }

  /// Updates the selected theme for the app
  ///
  /// @param [selectedLightTheme] is the [ThemeObject] of the light theme to save and set as light theme in the db
  ///
  /// @param [selectedDarkTheme] is the [ThemeObject] of the dark theme to save and set as dark theme in the db
  ///
  /// @param [context] is the [BuildContext] used to set the theme of the new settings
  Future<void> saveSelectedTheme(
    BuildContext context, {
    ThemeObject? selectedLightTheme,
    ThemeObject? selectedDarkTheme,
  }) async {
    await selectedLightTheme?.save();
    await selectedDarkTheme?.save();
    await ThemeObject.setSelectedTheme(light: selectedLightTheme?.id ?? null, dark: selectedDarkTheme?.id ?? null);

    ThemeData lightTheme = (await ThemeObject.getLightTheme()).themeData;
    ThemeData darkTheme = (await ThemeObject.getDarkTheme()).themeData;
    AdaptiveTheme.of(context).setTheme(
      light: lightTheme,
      dark: darkTheme,
      isDefault: true,
    );
  }

  /// Updates FCM data and saves to disk. It will also run [authFCM] automatically
  ///
  /// @param [data] is the [FCMData] to save
  Future<void> saveFCMData(FCMData data) async {
    fcmData = data;
    await fcmData!.save();
    SocketManager().authFCM();
  }

  Future<void> resetConnection() async {
    if (SocketManager().socket != null && SocketManager().socket!.connected) {
      SocketManager().socket!.disconnect();
    }

    Settings temp = this.settings;
    temp.finishedSetup.value = false;
    temp.guidAuthKey.value = "";
    temp.serverAddress.value = "";
    temp.lastIncrementalSync.value = 0;
    await this.saveSettings(temp);
  }

  FutureOr<int?> getMacOSVersion() async {
    if (_macOSVersion == null) {
      var res = await SocketManager().sendMessage("get-server-metadata", {}, (_) {});
      _macOSVersion = int.tryParse(res['data']['os_version'].split(".")[0]);
    }
    return _macOSVersion;
  }

  FutureOr<String?> getServerVersion() async {
    if (_macOSVersion == null) {
      var res = await SocketManager().sendMessage("get-server-metadata", {}, (_) {});
      _serverVersion = res['data']['server_version'];
    }
    return _serverVersion;
  }
}
