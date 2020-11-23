import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  StreamController<Settings> _stream = new StreamController.broadcast();
  Stream<Settings> get stream => _stream.stream;

  /// [appDocDir] is just a directory that is commonly used
  /// It cannot be accessed by the user, and is private to the app
  Directory appDocDir;

  /// [sharedFilesPath] is the path where most temporary files like those inserted from the keyboard or shared to the app are stored
  /// The getter simply is a helper to that path
  String get sharedFilesPath => "${appDocDir.path}/sharedFiles";

  /// [settings] is just an instance of the current settings that are saved
  Settings settings;
  FCMData fcmData;
  List<ThemeObject> themes;

  /// [sharedPreferences] is just an instance of [SharedPreferences] and it is stored here because it is commonly used
  SharedPreferences sharedPreferences;

  /// [init] is run at start and fetches both the [appDocDir] and sets the [settings] to a default value
  Future<void> init() async {
    settings = new Settings();
    appDocDir = await getApplicationSupportDirectory();
  }

  /// Retreives files from disk and stores them in [settings]
  ///
  ///
  /// @param [headless] determines whether the socket will be started automatically and fcm will be initialized.
  ///
  /// @param [context] is an optional parameter to be used for setting the adaptive theme based on the settings.
  /// Setting to null will prevent the theme from being set and will be set to null in the background isolate
  Future<void> getSavedSettings(
      {bool headless = false, BuildContext context}) async {
    await DBProvider.setupConfigRows();
    settings = await Settings.getSettings();
    fcmData = await FCMData.getFCM();
    // await DBProvider.setupDefaultPresetThemes(await DBProvider.db.database);
    themes = await ThemeObject.getThemes();
    for (ThemeObject theme in themes) {
      await theme.fetchData();
    }
    // If [context] is null, then we can't set the theme, and we shouldn't anyway
    if (context != null) {
      // Set the theme to match those of the settings
      ThemeObject light = await ThemeObject.getLightTheme();
      ThemeObject dark = await ThemeObject.getDarkTheme();
      AdaptiveTheme.of(context).setTheme(
        light: light.themeData,
        dark: dark.themeData,
      );
    }

    try {
      // Set the [displayMode] to that saved in settings
      await FlutterDisplayMode.setMode(await settings.getDisplayMode());
    } catch (e) {}

    // Change the [finishedSetup] status to that of the settings
    if (!settings.finishedSetup) {
      await DBProvider.deleteDB();
    }
    SocketManager().finishedSetup.sink.add(settings.finishedSetup);

    // If we aren't running in the background, then we should auto start the socket and authorize fcm just in case we haven't
    if (!headless) {
      SocketManager().startSocketIO();
      SocketManager().authFCM();
    }
  }

  /// Saves a [Settings] instance to disk
  ///
  /// @param [newSettings] are the settings to save
  Future<void> saveSettings(Settings newSettings) async {
    // Set the new settings as the current settings in the manager
    settings = newSettings;
    await settings.save();
    try {
      // Set the [displayMode] to that saved in settings
      await FlutterDisplayMode.setMode(await settings.getDisplayMode());
    } catch (e) {}

    _stream.sink.add(newSettings);
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
    ThemeObject selectedLightTheme,
    ThemeObject selectedDarkTheme,
  }) async {
    await selectedLightTheme?.save();
    await selectedDarkTheme?.save();
    await ThemeObject.setSelectedTheme(
        light: selectedLightTheme?.id ?? null,
        dark: selectedDarkTheme?.id ?? null);

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
    await fcmData.save();
    SocketManager().authFCM();
  }

  void dispose() {
    _stream.close();
  }
}
