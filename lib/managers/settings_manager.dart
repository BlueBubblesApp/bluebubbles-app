import 'dart:convert';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
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

  /// [appDocDir] is just a directory that is commonly used
  /// It cannot be accessed by the user, and is private to the app
  Directory appDocDir;

  /// [settings] is just an instance of the current settings that are saved
  Settings settings;

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
    // Get the shared preferences and store it
    sharedPreferences = await SharedPreferences.getInstance();

    // Get `Settings` from the shared preferences
    String result = sharedPreferences.getString('Settings');

    // Set those settings as the [settings] variable
    if (result != null) {
      Map resultMap = jsonDecode(result);
      settings = Settings.fromJson(resultMap);
    }

    // If [context] is null, then we can't set the theme, and we shouldn't anyway
    if (context != null) {
      // Set the theme to match those of the settings
      AdaptiveTheme.of(context)
          .setTheme(light: settings.lightTheme, dark: settings.darkTheme);
    }

    // Change the [finishedSetup] status to that of the settings
    SocketManager().finishedSetup.sink.add(_manager.settings.finishedSetup);

    // If we aren't running in the background, then we should auto start the socket and authorize fcm just in case we haven't
    if (!headless) {
      SocketManager().startSocketIO();
      SocketManager().authFCM();
    }
  }

  /// Saves a [Settings] instance to disk
  ///
  /// @param [newSettings] are the settings to save
  ///
  /// @param [connectToSocket] is an optional parameter which will change whether we should auto reconnect to the socket. It is false by default.
  /// This is used when the ngrok url is changed and as such we need to try to reconnect to that new url to make sure it will even work
  ///
  /// @param [authorizeFCM] is an optional parameter which will change whether we should auto authorize fcm. It is true by default.
  /// Usually we do this regardless cause it doesn't really do any harm
  ///
  /// @param [context] is an optional parameter which is the [BuildContext] used to set the theme of the new settings
  Future<void> saveSettings(
    Settings newSettings, {
    bool connectToSocket = false,
    bool authorizeFCM = true,
    BuildContext context,
  }) async {
    // Retreive the [sharedPreferences] if we haven't already
    if (sharedPreferences == null) {
      sharedPreferences = await SharedPreferences.getInstance();
    }

    // Save the settings to disk
    await sharedPreferences.setString(
        'Settings', jsonEncode(newSettings.toJson()));

    // Authoize fcm
    if (authorizeFCM) {
      await SocketManager().authFCM();
    }

    // Set the new settings as the current settings in the manager
    settings = newSettings;

    // If there is a context, then we need to update the theme of the app
    if (context != null) {
      AdaptiveTheme.of(context).setTheme(
        light: newSettings.lightTheme,
        dark: newSettings.darkTheme,
        isDefault: true,
      );
    }

    // Connect to the socket
    if (connectToSocket) {
      SocketManager().startSocketIO(forceNewConnection: true);
    }
  }
}
