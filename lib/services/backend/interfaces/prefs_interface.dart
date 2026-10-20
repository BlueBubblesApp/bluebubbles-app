import 'package:bluebubbles/database/global/settings.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/services/backend/actions/prefs_actions.dart';
import 'package:get_it/get_it.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/isolates/isolate_event.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';

class PrefsInterface {
  static Future<void> saveReplyToMessageState(String chatGuid, String? messageGuid, int? messagePart) async {
    final data = {
      'chatGuid': chatGuid,
      'messageGuid': messageGuid,
      'messagePart': messagePart,
    };

    if (isIsolate) {
      return await PrefsActions.saveReplyToMessageState(data);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.saveReplyToMessageState, input: data);
    }
  }

  static Future<Map<String, dynamic>?> loadReplyToMessageState(String chatGuid) async {
    final data = {
      'chatGuid': chatGuid,
    };

    if (isIsolate) {
      return PrefsActions.loadReplyToMessageState(data);
    } else {
      return await GetIt.I<GlobalIsolate>()
          .send<Map<String, dynamic>?>(IsolateRequestType.loadReplyToMessageState, input: data);
    }
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
      await PrefsActions.syncSettings(settings);
      // Main has its own copy (and so does the GlobalIsolate when this is another isolate); see below.
      IsolateEventEmitter.emit(IsolateEvent.settingsChanged, settings);
    } else {
      return await GetIt.I<GlobalIsolate>().send<void>(IsolateRequestType.syncSettings, input: settings);
    }
  }

  /// Applies settings saved inside [isolate] to main's copy, and to the GlobalIsolate's when they came from another
  /// isolate. Otherwise main's stale copy can be written back over them by its next [Settings.saveAsync].
  static void listenForIsolateSettings(GlobalIsolate isolate) {
    isolate.addEventListener(IsolateEvent.settingsChanged, (data) {
      final settings = Map<String, dynamic>.from(data as Map);
      Settings.updateFromMap(settings, save: false);
      final global = GetIt.I<GlobalIsolate>();
      // A stopped GlobalIsolate reloads from disk when it next starts.
      if (isolate != global && global.isRunning) global.broadcast(IsolateRequestType.syncSettings, settings);
    });
  }
}
