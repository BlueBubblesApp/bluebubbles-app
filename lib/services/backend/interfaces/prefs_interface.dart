import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/prefs_actions.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';

class PrefsInterface {
  // Reply-state persistence is SharedPreferences, not ObjectBox — there is no
  // reason to marshal it through the GlobalIsolate, and doing so is hazardous:
  // prefs writes are platform-channel write-throughs, and channel calls made
  // from inside the isolate were observed to hang around pause transitions
  // (2026-07-06 wedge: saveReplyToMessageState froze a healthy isolate and
  // every request behind it). Always run these on the calling engine.
  static Future<void> saveReplyToMessageState(String chatGuid, String? messageGuid, int? messagePart) async {
    final data = {
      'chatGuid': chatGuid,
      'messageGuid': messageGuid,
      'messagePart': messagePart,
    };
    return await PrefsActions.saveReplyToMessageState(data);
  }

  static Future<Map<String, dynamic>?> loadReplyToMessageState(String chatGuid) async {
    final data = {
      'chatGuid': chatGuid,
    };
    return PrefsActions.loadReplyToMessageState(data);
  }

  static Future<void> syncAllSettings({Map<String, dynamic>? settings}) async {
    final data = {
      'settings': settings ?? SettingsSvc.settings.toMap(),
    };

    if (isIsolate) {
      return await PrefsActions.syncAllSettings(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.syncAllSettings, input: data);
    }
  }

  static Future<void> syncSettings(Map<String, dynamic> settings) async {
    if (isIsolate) {
      return await PrefsActions.syncSettings(settings);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.syncSettings, input: settings);
    }
  }
}
