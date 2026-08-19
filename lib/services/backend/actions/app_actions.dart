import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';

class AppActions {
  static Future<Map<String, dynamic>> checkForUpdate(Map<String, dynamic> data) async {
    final channelIndex = data['channel'] as int?;
    final channel = channelIndex != null ? AppUpdateChannel.values[channelIndex] : null;
    return await SettingsSvc.getAppUpdateDict(channel: channel);
  }
}
