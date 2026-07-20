import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_admin_actions.dart';
import 'package:bluebubbles/services/backend/settings/desktop_shared_preferences_store.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_database_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_desktop_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_firebase_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_messaging_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_network_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_server_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_system_actions.dart';
import 'package:bluebubbles/services/backend/settings/actions/shared_preferences_theme_actions.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
SharedPreferencesService get PrefsSvc => GetIt.I<SharedPreferencesService>();

class SharedPreferencesService {
  @Deprecated('Use categorized helpers on PrefsSvc instead of raw i access')
  late final SharedPreferencesWithCache i;
  late final SharedPreferencesAdminActions admin;
  late final SharedPreferencesDatabaseActions database;
  late final SharedPreferencesDesktopActions desktop;
  late final SharedPreferencesFirebaseActions firebase;
  late final SharedPreferencesThemeActions theme;
  late final SharedPreferencesMessagingActions messaging;
  late final SharedPreferencesNetworkActions network;
  late final SharedPreferencesServerActions server;
  late final SharedPreferencesSystemActions system;

  /// On Android, back the async prefs API with the ORIGINAL SharedPreferences
  /// store (the FlutterSharedPreferences XML) instead of the default Jetpack
  /// DataStore. Native code reads settings synchronously and cannot see
  /// DataStore — the DartWorker's background callback handle, SettingsHelper,
  /// the foreground service, and the intent receivers all read
  /// context.getSharedPreferences("FlutterSharedPreferences"). Defaulting to
  /// DataStore silently broke every one of those reads (most critically,
  /// cold-start FCM handling: callback handle -1 → no Dart entrypoint → every
  /// message received while the process was dead was dropped).
  ///
  /// The file name MUST be passed explicitly: with a null fileName the plugin
  /// uses PreferenceManager.getDefaultSharedPreferences, which is a different
  /// file (`<package>_preferences.xml`) that native code does not read.
  static SharedPreferencesOptions get _options => (!kIsWeb && Platform.isAndroid)
      ? const SharedPreferencesAsyncAndroidOptions(
          backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
          originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(fileName: 'FlutterSharedPreferences'),
        )
      : const SharedPreferencesOptions();

  Future<void> init({bool headless = false}) async {
    // The stock Windows/Linux backends cache per isolate and clobber each
    // other's writes; swap in the cross-isolate-safe store before anything
    // (including the legacy migration below) touches prefs. Must run in every
    // isolate, which this init does. macOS/mobile backends are already safe.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      await DesktopSharedPreferencesStore.register();
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: prefs,
      sharedPreferencesAsyncOptions: _options,
      migrationCompletedKey: 'migrationCompleted',
    );

    // Values written while the async API was DataStore-backed exist only in
    // DataStore and would vanish when switching back to the XML store. Copy
    // them over once. Runs AFTER the legacy migration above so the (newer)
    // DataStore values win over any stale legacy values it re-imported.
    if (!kIsWeb && Platform.isAndroid) {
      await _migrateDataStoreToSharedPreferences();
    }

    i = await SharedPreferencesWithCache.create(
      sharedPreferencesOptions: _options,
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    admin = SharedPreferencesAdminActions(this);
    database = SharedPreferencesDatabaseActions(this);
    desktop = SharedPreferencesDesktopActions(this);
    firebase = SharedPreferencesFirebaseActions(this);
    theme = SharedPreferencesThemeActions(this);
    messaging = SharedPreferencesMessagingActions(this);
    network = SharedPreferencesNetworkActions(this);
    server = SharedPreferencesServerActions(this);
    system = SharedPreferencesSystemActions(this);
  }

  /// One-time copy of all values from the Jetpack DataStore backend (used
  /// between the SharedPreferencesWithCache migration and the switch back to
  /// the original SharedPreferences backend) into the XML-backed store.
  Future<void> _migrateDataStoreToSharedPreferences() async {
    const String migrationKey = 'dataStoreToSharedPreferencesMigrationCompleted';
    final SharedPreferencesAsync xmlPrefs = SharedPreferencesAsync(options: _options);
    if (await xmlPrefs.getBool(migrationKey) ?? false) return;

    // Default Android options = the DataStore backend.
    final SharedPreferencesAsync dataStorePrefs =
        SharedPreferencesAsync(options: const SharedPreferencesAsyncAndroidOptions());
    final Map<String, Object?> values = await dataStorePrefs.getAll();
    for (final entry in values.entries) {
      final Object? value = entry.value;
      if (value is bool) {
        await xmlPrefs.setBool(entry.key, value);
      } else if (value is int) {
        await xmlPrefs.setInt(entry.key, value);
      } else if (value is double) {
        await xmlPrefs.setDouble(entry.key, value);
      } else if (value is String) {
        await xmlPrefs.setString(entry.key, value);
      } else if (value is List<String>) {
        await xmlPrefs.setStringList(entry.key, value);
      }
    }

    await xmlPrefs.setBool(migrationKey, true);
  }
}
