class Settings {
  Settings();

  Settings.fromJson(Map<String, dynamic> json)
      : serverAddress = json['server_address'],
        fcmAuthData = json['fcm_auth_data'],
        guidAuthKey = json['guidAuthKey'],
        _finishedSetup = json['finishedSetup'];

  var fcmAuthData;
  String guidAuthKey = "";
  String serverAddress = "";
  bool _finishedSetup = false;

  set finishedSetup(bool val) {
    _finishedSetup = val;
  }

  bool get finishedSetup => _finishedSetup;

  Map<String, dynamic> toJson() => {
        'server_address': serverAddress,
        'fcm_auth_data': fcmAuthData,
        'guidAuthKey': guidAuthKey,
        'finishedSetup': _finishedSetup,
      };
}
