import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  factory SettingsManager() {
    return _manager;
  }

  static final SettingsManager _manager = SettingsManager._internal();

  SettingsManager._internal();

  Directory appDocDir;
  //settings
  Settings settings;
  SharedPreferences sharedPreferences;
  File debugFile;

  Future<void> init() async {
    settings = new Settings();
    appDocDir = await getApplicationSupportDirectory();
    new File(SettingsManager().appDocDir.path + "/debug.txt")
        .create()
        .then((value) => debugFile = value);
  }

  Future<void> getSavedSettings(
      {bool headless = false, BuildContext context}) async {
    _manager.sharedPreferences = await SharedPreferences.getInstance();
    var result = _manager.sharedPreferences.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _manager.settings = Settings.fromJson(resultMap);
    }
    if (context != null) {
      AdaptiveTheme.of(context)
          .setTheme(light: settings.lightTheme, dark: settings.darkTheme);
    }

    SocketManager().finishedSetup.sink.add(_manager.settings.finishedSetup);
    if (!headless) {
      SocketManager().startSocketIO();
      SocketManager().authFCM();
    }
  }

  Future<void> saveSettings(Settings settings,
      {bool connectToSocket = false,
      bool authorizeFCM = true,
      BuildContext context}) async {
    if (_manager.sharedPreferences == null) {
      _manager.sharedPreferences = await SharedPreferences.getInstance();
    }
    debugPrint("saving to settings " + settings.toJson().toString());
    await _manager.sharedPreferences
        .setString('Settings', jsonEncode(settings.toJson()));

    if (authorizeFCM) {
      await SocketManager().authFCM();
    }
    _manager.settings = settings;
    if (context != null) {
      AdaptiveTheme.of(context).setTheme(
        light: settings.lightTheme,
        dark: settings.darkTheme,
        isDefault: true,
      );
    }

    if (connectToSocket) {
      SocketManager().startSocketIO(forceNewConnection: true);
    }
  }
}
