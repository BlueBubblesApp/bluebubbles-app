import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesServerActions {
  static const String _macOSVersionKey = 'macos-version';
  static const String _macOSMinorVersionKey = 'macos-minor-version';
  static const String _serverVersionKey = 'server-version';
  static const String _serverVersionCodeKey = 'server-version-code';
  static const String _apiVersionsKey = 'server-api-versions';
  static const String _serverBuildVersionKey = 'server-build-version';
  static const String _privateApiEnableTipKey = 'private-api-enable-tip';
  static const String _serverUpdateCheckKey = 'server-update-check';
  static const String _clientUpdateCheckKey = 'client-update-check';

  final SharedPreferencesService service;

  SharedPreferencesServerActions(this.service);

  int? getMacOSVersion() => service.i.getInt(_macOSVersionKey);

  int? getMacOSMinorVersion() => service.i.getInt(_macOSMinorVersionKey);

  String? getServerVersion() => service.i.getString(_serverVersionKey);

  int? getServerVersionCode() => service.i.getInt(_serverVersionCodeKey);

  List<int>? getApiVersions() =>
      service.i.getStringList(_apiVersionsKey)?.map(int.tryParse).whereType<int>().toList();

  /// Saved as "" for a server without one, so a switch to it clears the last server's
  String? getServerBuildVersion() {
    final version = service.i.getString(_serverBuildVersionKey);
    return version == null || version.isEmpty ? null : version;
  }

  Future<void> setServerDetails({
    int? macOSVersion,
    int? macOSMinorVersion,
    String? serverVersion,
    int? serverVersionCode,
    List<int>? apiVersions,
    String? serverBuildVersion,
  }) async {
    if (macOSVersion != null) {
      await service.i.setInt(_macOSVersionKey, macOSVersion);
    }
    if (macOSMinorVersion != null) {
      await service.i.setInt(_macOSMinorVersionKey, macOSMinorVersion);
    }
    if (serverVersion != null) {
      await service.i.setString(_serverVersionKey, serverVersion);
    }
    if (serverVersionCode != null) {
      await service.i.setInt(_serverVersionCodeKey, serverVersionCode);
    }
    if (apiVersions != null) {
      await service.i.setStringList(_apiVersionsKey, apiVersions.map((v) => v.toString()).toList());
    }
    if (serverBuildVersion != null) {
      await service.i.setString(_serverBuildVersionKey, serverBuildVersion);
    }
  }

  bool hasSeenPrivateApiEnableTip() => service.i.getBool(_privateApiEnableTipKey) ?? false;

  Future<void> markPrivateApiEnableTipShown() async {
    await service.i.setBool(_privateApiEnableTipKey, true);
  }

  String? getServerUpdateCheckVersion() => service.i.getString(_serverUpdateCheckKey);

  Future<void> setServerUpdateCheckVersion(String version) async {
    await service.i.setString(_serverUpdateCheckKey, version);
  }

  String? getClientUpdateCheckCode() => service.i.getString(_clientUpdateCheckKey);

  Future<void> setClientUpdateCheckCode(String code) async {
    await service.i.setString(_clientUpdateCheckKey, code);
  }
}
