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
  int _chunkSize = 1;

  set finishedSetup(bool val) => _finishedSetup = val;
  bool get finishedSetup => _finishedSetup;

  set chunkSize(int val) => _chunkSize = val;
  int get chunkSize => _chunkSize;

  Map<String, dynamic> toJson() => {
        'server_address': serverAddress,
        'fcm_auth_data': fcmAuthData,
        'guidAuthKey': guidAuthKey,
        'finishedSetup': _finishedSetup,
      };
}
