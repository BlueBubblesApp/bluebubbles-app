import 'dart:convert';
import 'dart:io';

import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/socket_manager.dart';
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

  void init() async {
    settings = new Settings();
    appDocDir = await getApplicationSupportDirectory();
  }

  void getSavedSettings() async {
    _manager.sharedPreferences = await SharedPreferences.getInstance();
    var result = _manager.sharedPreferences.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _manager.settings = Settings.fromJson(resultMap);
    }
    SocketManager().finishedSetup.sink.add(_manager.settings.finishedSetup);
    SocketManager().startSocketIO();
    SocketManager().authFCM();
  }

  void saveSettings(Settings settings,
      {bool connectToSocket = false,
      Function connectCb,
      bool authorizeFCM = true}) async {
    if (_manager.sharedPreferences == null) {
      _manager.sharedPreferences = await SharedPreferences.getInstance();
    }

    _manager.sharedPreferences.setString('Settings', jsonEncode(settings));
    if (authorizeFCM) {
      await SocketManager().authFCM();
    }

    if (connectToSocket) {
      SocketManager().startSocketIO(connectCB: connectCb);
    }
  }
}
