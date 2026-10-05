import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/models/models.dart' show AppUpdateInfo;
import 'package:bluebubbles/services/backend/actions/app_actions.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:github/github.dart';

class AppInterface {
  static Future<AppUpdateInfo> checkForUpdate({AppUpdateChannel? channel}) async {
    final data = {'channel': channel?.index};

    late Map<String, dynamic> response;
    if (isIsolate) {
      response = await AppActions.checkForUpdate(data);
    } else {
      response =
          await GetIt.I<GlobalIsolate>().send<Map<String, dynamic>>(IsolateRequestType.checkForUpdate, input: data);
    }

    final responseChannelIndex = response['channel'] as int?;
    return AppUpdateInfo(
      available: response['available'] as bool,
      latestRelease: response['latestRelease'] as Release?,
      isDesktopRelease: response['isDesktopRelease'] as bool,
      channel: responseChannelIndex != null ? AppUpdateChannel.values[responseChannelIndex] : null,
      version: (response['parsedVersion'] as Map<String, String>)['version']!,
      code: (response['parsedVersion'] as Map<String, String>)['code']!,
      buildNumber: (response['parsedVersion'] as Map<String, String>)['build']!,
      apkDownloadUrl: response['apkDownloadUrl'] as String?,
      apkAssetName: response['apkAssetName'] as String?,
      apkSizeBytes: response['apkSizeBytes'] as int?,
    );
  }
}
