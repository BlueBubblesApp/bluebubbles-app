import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/core/abstractions/migration.dart';
import 'package:bluebubbles/core/abstractions/service.dart';
import 'package:bluebubbles/core/abstractions/database_service.dart';
import 'package:bluebubbles/core/lib/migrations/object_box_handle_id_migration.dart';
import 'package:bluebubbles/core/lib/migrations/object_box_nulify_fields_migration.dart';
import 'package:bluebubbles/core/lib/migrations/object_box_save_fcm_data_migration.dart';
import 'package:bluebubbles/core/utilities/filesystem_utils.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' show basename, dirname, join;
import 'package:path/path.dart' as p;

import '../../services/backend/filesystem/filesystem_service.dart';
import '../../services/backend/settings/settings_service.dart';
import '../../services/ui/theme/themes_service.dart';


class ObjectBoxDatabaseService extends DatabaseService {
  @override
  final String name = "ObjectBox Database Service";

  @override
  final int version = 4;

  @override
  List<Service> dependencies = [];

  late final Store store;

  @override
  get attachments => store.box<Attachment>();

  @override
  get chats => store.box<Chat>();

  @override
  get messages => store.box<Message>();

  @override
  get handles => store.box<Handle>();

  @override
  get contacts => store.box<Contact>();

  @override
  get fcm => store.box<FCMData>();

  @override
  get scheduledMessages => store.box<ScheduledMessage>();

  @override
  get themes => store.box<ThemeStruct>();

  @override
  get themeEntries => store.box<ThemeEntry>();

  @override
  // ignore: deprecated_member_use_from_same_package
  get themeObjects => store.box<ThemeObject>();

  get directory => Directory(join(fs.appDocDir.path, 'objectbox'));

  Future<bool> attachNewStore() async {
    try {
      log.info("Attaching ObjectBox store from path: ${directory.path}");
      store = Store.attach(getObjectBoxModel(), directory.path);
      return true;
    } catch (e, s) {
      log.error(e);
      log.error(s);
      log.info("Failed to attach to existing store, opening from path");
      return false;
    }
  }

  Future<bool> openExistingStore() async {
    try {
      log.info("Opening ObjectBox store from path: ${directory.path}");
      store = await openStore(directory: directory.path);
      return true;
    } catch (e, s) {
      log.error(e);
      log.error(s);
      // this can very rarely happen
      if (e.toString().contains("another store is still open using the same path")) {
        log.info("Retrying to attach to an existing ObjectBox store");
        store = Store.attach(getObjectBoxModel(), directory.path);
        return true;
      }

      return false;
    }
  }

  @override
  Future<void> initMobile() async {
    bool success = await attachNewStore();
    if (!success) {
      success = await openExistingStore();
    }

    if (!success) {
      throw Exception("Failed to open ObjectBox store!");
    }
  }

  @override
  Future<void> initDesktop() async {
    await migrateDesktopDirectories();
    
    try {
      directory.createSync(recursive: true);
      await migrateDesktopCustomPath();
      await openExistingStore();
    } catch (e, s) {
      if (Platform.isLinux) {
        log.debug("Another instance is probably running. Sending foreground signal");
        final instanceFile = File(join(fs.appDocDir.path, '.instance'));
        instanceFile.openSync(mode: FileMode.write).closeSync();
        exit(0);
      }

      log.error(e);
      log.error(s);
    }
  }

  @override
  Future<void> start() async {
    await super.start();
    await ss.prefs.setInt('dbVersion', version);
  }

  @override
  Future<void> seed() async {
    if (themes.isEmpty()) {
      await ss.prefs.setString("selected-dark", "OLED Dark");
      await ss.prefs.setString("selected-light", "Bright White");
      themes.putMany(ts.defaultThemes);
    }
  }

  @override
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    return store.runInTransaction(mode, fn);
  }

  @override
  Future<void> purge({ onlyMessageData = false }) {
    if (!ss.settings.finishedSetup.value) {
      attachments.removeAll();
      chats.removeAll();
      handles.removeAll();
      messages.removeAll();

      if (!onlyMessageData) {
        contacts.removeAll();
        fcm.removeAll();
        themes.removeAll();
        themeEntries.removeAll();
        themeObjects.removeAll();
      }
    }

    return Future.value();
  }

  Future<void> migrateDesktopDirectories() async {
    //ignore: unnecessary_cast, we need this as a workaround
    Directory appData = fs.appDocDir as Directory;
    if (!await Directory(join(appData.path, "objectbox")).exists()) {
      // Migrate to new appdata location if this function returns the new place and we still have the old place
      if (basename(appData.absolute.path) == "bluebubbles") {
        Directory oldAppData = Platform.isWindows
            ? Directory(join(dirname(dirname(appData.absolute.path)), "com.bluebubbles\\bluebubbles_app"))
            : Directory(join(dirname(appData.absolute.path), "bluebubbles_app"));
        bool storeApp = basename(dirname(dirname(appData.absolute.path))) != "Roaming";
        if (await oldAppData.exists()) {
          log.info("Copying appData to new directory");
          copyDirectory(oldAppData, appData);
          log.info("Finished migrating appData");
        } else if (Platform.isWindows) {
          // Find the other appdata.
          String appDataRoot = p.joinAll(p.split(appData.absolute.path).slice(0, 4));
          if (storeApp) {
            // If current app is store, we first look for new location nonstore appdata in case people are installing
            // diff versions
            oldAppData = Directory(join(appDataRoot, "Roaming", "BlueBubbles", "bluebubbles"));
            // If that doesn't exist, we look in the old non-store location
            if (!await oldAppData.exists()) {
              oldAppData = Directory(join(appDataRoot, "Roaming", "com.bluebubbles", "bluebubbles_app"));
            }
            if (await oldAppData.exists()) {
              log.info("Copying appData from NONSTORE location to new directory");
              copyDirectory(oldAppData, appData);
              log.info("Finished migrating appData");
            }
          } else {
            oldAppData = Directory(join(appDataRoot, "Local", "Packages", "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw", "LocalCache", "Roaming",
                "BlueBubbles", "bluebubbles"));
            if (!await oldAppData.exists()) {
              oldAppData = Directory(join(appDataRoot, "Local", "Packages", "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw", "LocalCache", "Roaming",
                  "com.bluebubbles", "bluebubbles_app"));
            }
            if (await oldAppData.exists()) {
              log.info("Copying appData from STORE location to new directory");
              copyDirectory(oldAppData, appData);
              log.info("Finished migrating appData");
            }
          }
        }
      }
    }
  }

  Future<void> migrateDesktopCustomPath() async {
    if (ss.prefs.getBool('use-custom-path') == true && ss.prefs.getString('custom-path') != null) {
      Directory oldCustom = Directory(join(ss.prefs.getString('custom-path')!, 'objectbox'));
      if (oldCustom.existsSync()) {
        log.info("Detected prior use of custom path option. Migrating...");
        copyDirectory(oldCustom, directory);
      }
      await ss.prefs.remove('use-custom-path');
      await ss.prefs.remove('custom-path');
    }
  }

  @override
  Future<void> migrate() async {
    int dbVersion = ss.prefs.getInt('dbVersion') ?? (ss.settings.finishedSetup.value ? 1 : this.version);
    List<Migration> migrations = [
      ObjectBoxHandleIdMigration(),
      ObjectBoxNullifyFieldsMigration(),
      ObjectBoxSaveFcmDataMigration()
    ];

    if (dbVersion >= version) {
      log.debug("Database is up to date!");
      return Future.value();
    }

    log.info('Migrating database from version $version to version ${version}');

    // Execute the database migration when the dbVersion is less than the current version.
    // Only execute migrations if it's version is newer than the dbVersion
    for (Migration migration in migrations) {
      if (migration.version > dbVersion) {
        log.debug("Executing Migration: ${migration.name}");
        log.debug("  -> ${migration.description}");

        try {
          await migration.execute();
        } catch (e, s) {
          log.error("Failed to execute migration!");
          log.error(e);
          log.error(s);
        }
      }
    }

    log.info("Database is up to date!");
    return Future.value();
  }
}