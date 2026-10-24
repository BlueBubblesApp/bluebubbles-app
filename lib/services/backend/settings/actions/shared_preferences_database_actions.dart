import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class SharedPreferencesDatabaseActions {
  static const String _finishedSetupKey = 'finishedSetup';
  static const String _dbVersionKey = 'dbVersion';
  static const String _themesVersionKey = 'themesVersion';
  static const String _useCustomPathKey = 'use-custom-path';
  static const String _customPathKey = 'custom-path';
  static const String _chatStateBaselineKey = 'chat-state-replication-baseline-v2';
  static const String _deferredChatDeletionsKey = 'deferred-chat-deletions-v2';
  static const String _recoverableBaselineKey = 'recoverable-message-baseline';

  final SharedPreferencesService service;

  SharedPreferencesDatabaseActions(this.service);

  bool getFinishedSetup() => service.i.getBool(_finishedSetupKey) ?? false;

  int? getDbVersion() => service.i.getInt(_dbVersionKey);

  Future<void> setDbVersion(int version) => service.i.setInt(_dbVersionKey, version);

  int getThemesVersion() => service.i.getInt(_themesVersionKey) ?? 0;

  Future<void> setThemesVersion(int version) => service.i.setInt(_themesVersionKey, version);

  bool shouldUseCustomPath() => service.i.getBool(_useCustomPathKey) == true;

  String? getCustomPath() => service.i.getString(_customPathKey);

  String? getChatStateBaseline() => service.i.getString(_chatStateBaselineKey);

  Future<void> setChatStateBaseline(String value) => service.i.setString(_chatStateBaselineKey, value);

  String? getDeferredChatDeletions() => service.i.getString(_deferredChatDeletionsKey);

  Future<void> setDeferredChatDeletions(String value) => service.i.setString(_deferredChatDeletionsKey, value);
  /// The set of message GUIDs this client last hid because Apple had them in
  /// Recently Deleted. Deliberately not keyed by server address: a quick
  /// tunnel mints a new URL on every restart, which would make the baseline
  /// untrusted and silently disable the offline catch-up.
  String? getRecoverableMessageBaseline() => service.i.getString(_recoverableBaselineKey);

  Future<void> setRecoverableMessageBaseline(String value) =>
      service.i.setString(_recoverableBaselineKey, value);

  Future<void> clearCustomPathConfig() async {
    await service.i.remove(_useCustomPathKey);
    await service.i.remove(_customPathKey);
  }
}
