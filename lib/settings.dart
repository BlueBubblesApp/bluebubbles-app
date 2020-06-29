import 'package:adaptive_theme/adaptive_theme.dart';

class Settings {
  Settings();

  Settings.fromJson(Map<String, dynamic> json)
      : serverAddress =
            json.containsKey('server_address') ? json['server_address'] : "",
        fcmAuthData =
            json.containsKey('fcm_auth_data') ? json['fcm_auth_data'] : null,
        guidAuthKey =
            json.containsKey('guidAuthKey') ? json['guidAuthKey'] : "",
        _finishedSetup =
            json.containsKey('finishedSetup') ? json['finishedSetup'] : false,
        _chunkSize = json.containsKey('chunkSize') ? json['chunkSize'] : 512,
        _autoDownload =
            json.containsKey('autoDownload') ? json['autoDownload'] : true,
        _connected = json.containsKey('connected') ? json['connected'] : false;

  var fcmAuthData;
  String guidAuthKey = "";
  String serverAddress = "";
  bool _finishedSetup = false;
  int _chunkSize = 512;
  bool _autoDownload = true;
  bool _connected = false;

  set finishedSetup(bool val) => _finishedSetup = val;
  bool get finishedSetup => _finishedSetup;

  set chunkSize(int val) => _chunkSize = val;
  int get chunkSize => _chunkSize;

  set autoDownload(bool val) => _autoDownload = val;
  bool get autoDownload => _autoDownload;

  set connected(bool val) => _connected = val;
  bool get connected => _connected;

  Map<String, dynamic> toJson() => {
        'server_address': serverAddress,
        'fcm_auth_data': fcmAuthData,
        'guidAuthKey': guidAuthKey,
        'finishedSetup': _finishedSetup,
        'chunkSize': _chunkSize,
        'autoDownload': _autoDownload != null ? _autoDownload : true,
        'connected': _connected != null ? _connected : false,
      };
}
