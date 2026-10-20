import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/database/global/settings.dart';

class PrefsActions {
  static Future<void> saveReplyToMessageState(dynamic data) async {
    final chatGuid = data['chatGuid'] as String;
    final messageGuid = data['messageGuid'] as String?;
    final messagePart = data['messagePart'] as int?;

    await PrefsSvc.messaging.saveReplyToMessageState(
      chatGuid: chatGuid,
      messageGuid: messageGuid,
      messagePart: messagePart,
    );
  }

  static Future<Map<String, dynamic>?> loadReplyToMessageState(dynamic data) async {
    final chatGuid = data['chatGuid'] as String;

    final state = PrefsSvc.messaging.loadReplyToMessageState(chatGuid);

    if (state != null) {
      return {
        'messageGuid': state.messageGuid,
        'messagePart': state.messagePart,
      };
    }

    return null;
  }

  static Future<void> syncAllSettings(dynamic data) async {
    final settingsData = data['settings'] as Map<String, dynamic>;

    final newSettings = Settings.fromMap(settingsData);

    // Replace the settings in the SettingsService
    SettingsSvc.settings = newSettings;
  }

  static Future<void> syncSettings(dynamic data) async {
    Settings.updateFromMap(data);
  }
}
