import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

class Database {
  static int version = 5;

  static late final Store store;
  static late final Box<Attachment> attachments;
  static late final Box<Chat> chats;
  static late final Box<Contact> contacts;
  static late final Box<FCMData> fcmData;
  static late final Box<Handle> handles;
  static late final Box<Message> messages;
  static late final Box<ScheduledMessage> scheduledMessages;
  static late final Box<ThemeStruct> themes;
  static late final Box<ThemeEntry> themeEntries;

  // ignore: deprecated_member_use_from_same_package
  static late final Box<ThemeObject> themeObjects;

  static final Completer<void> initComplete = Completer();

  static Future<void> init() async {
    // Web doesn't use a database currently, so do not do anything
    if (kIsWeb) return;

    if (!kIsDesktop) {
      await _initDatabaseMobile();
    } else {
      await _initDatabaseDesktop();
    }

    try {
      Database.attachments = store.box<Attachment>();
      Database.chats = store.box<Chat>();
      Database.contacts = store.box<Contact>();
      Database.fcmData = store.box<FCMData>();
      Database.handles = store.box<Handle>();
      Database.messages = store.box<Message>();
      Database.themes = store.box<ThemeStruct>();
      Database.themeEntries = store.box<ThemeEntry>();
      // ignore: deprecated_member_use_from_same_package
      themeObjects = store.box<ThemeObject>();

      if (!ss.settings.finishedSetup.value) {
        Database.attachments.removeAll();
        Database.chats.removeAll();
        Database.contacts.removeAll();
        Database.fcmData.removeAll();
        Database.handles.removeAll();
        Database.messages.removeAll();
        Database.themes.removeAll();
        Database.themeEntries.removeAll();
        themeObjects.removeAll();
      }
    } catch (e, s) {
      Logger.error("Failed to setup ObjectBox boxes!", error: e, trace: s);
    }

    try {
      if (Database.themes.isEmpty()) {
        await ss.prefs.setString("selected-dark", "OLED Dark");
        await ss.prefs.setString("selected-light", "Bright White");
        Database.themes.putMany(ts.defaultThemes);
      }
    } catch (e, s) {
      Logger.error("Failed to seed themes!", error: e, trace: s);
    }

    try {
      _performDatabaseMigrations();

      // So long as migrations succeed, we can update the database version
      await ss.prefs.setInt('dbVersion', version);
    } catch (e, s) {
      Logger.error("Failed to perform database migrations!", error: e, trace: s);
    }

    initComplete.complete();
  }

  static Future<void> waitForInit() async {
    await initComplete.future;
  }

  static Future<void> _initDatabaseMobile({bool? storeOpenStatus}) async {
    Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
    final isStoreOpen = storeOpenStatus ?? Store.isOpen(objectBoxDirectory.path);

    try {
      if (isStoreOpen) {
        Logger.info("Attempting to attach to an existing ObjectBox store...");
        store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
        Logger.info("Successfully attached to an existing ObjectBox store");
      } else {
        Logger.info("Opening new ObjectBox store from path: ${objectBoxDirectory.path}");
        store = await openStore(directory: objectBoxDirectory.path);
      }
    } catch (e, s) {
      Logger.error("Failed to open ObjectBox store!", error: e, trace: s);

      if (e.toString().contains("another store is still open using the same path")) {
        Logger.info("Retrying to attach to an existing ObjectBox store");
        await _initDatabaseMobile(storeOpenStatus: true);
      }
    }
  }

  static Future<void> _initDatabaseDesktop() async {
    Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));

    try {
      objectBoxDirectory.createSync(recursive: true);
      if (ss.prefs.getBool('use-custom-path') == true && ss.prefs.getString('custom-path') != null) {
        Directory oldCustom = Directory(join(ss.prefs.getString('custom-path')!, 'objectbox'));
        if (oldCustom.existsSync()) {
          Logger.info("Detected prior use of custom path option. Migrating...");
          fs.copyDirectory(oldCustom, objectBoxDirectory);
        }
        await ss.prefs.remove('use-custom-path');
        await ss.prefs.remove('custom-path');
      }

      Logger.info("Opening ObjectBox store from path: ${objectBoxDirectory.path}");
      store = await openStore(directory: objectBoxDirectory.path);
    } catch (e, s) {
      if (Platform.isLinux) {
        Logger.debug("Another instance is probably running. Sending foreground signal");
        final instanceFile = File(join(fs.appDocDir.path, '.instance'));
        instanceFile.openSync(mode: FileMode.write).closeSync();
        exit(0);
      }

      Logger.error("Failed to initialize desktop database!", error: e, trace: s);
    }
  }

  static void _performDatabaseMigrations({int? versionOverride}) {
    int version = versionOverride ?? ss.prefs.getInt('dbVersion') ?? (ss.settings.finishedSetup.value ? 1 : Database.version);
    if (version > Database.version) return;

    final Stopwatch s = Stopwatch();
    s.start();

    int nextVersion = version;
    Logger.debug("Performing database migration from version $version to ${Database.version}", tag: "DB-Migration");
    switch (Database.version) {
      // Version 2 changed handleId to match the server side ROWID, rather than client side ROWID
      case 2:
        Logger.info("Fetching all messages and handles...", tag: "DB-Migration");
        final messages = Database.messages.getAll();
        if (messages.isNotEmpty) {
          final handles = Database.handles.getAll();
          Logger.info("Replacing handleIds for messages...", tag: "DB-Migration");
          for (Message m in messages) {
            if (m.isFromMe! || m.handleId == 0 || m.handleId == null) continue;
            m.handleId = handles.firstWhereOrNull((e) => e.id == m.handleId)?.originalROWID ?? m.handleId;
          }
          Logger.info("Final save...", tag: "DB-Migration");
          Database.messages.putMany(messages);
        }

        nextVersion = 2;
      // Version 3 modifies chat typing indicators and read receipts values to follow global setting initially
      case 3:
        final chats = Database.chats.getAll();
        final papi = ss.settings.enablePrivateAPI.value;
        final typeGlobal = ss.settings.privateSendTypingIndicators.value;
        final readGlobal = ss.settings.privateMarkChatAsRead.value;
        for (Chat c in chats) {
          if (papi && readGlobal && !(c.autoSendReadReceipts ?? true)) {
            // dont do anything
          } else {
            c.autoSendReadReceipts = null;
          }
          if (papi && typeGlobal && !(c.autoSendTypingIndicators ?? true)) {
            // dont do anything
          } else {
            c.autoSendTypingIndicators = null;
          }
        }

        Database.chats.putMany(chats);
        nextVersion = 3;
      // Version 4 saves FCM Data to the shared preferences for use in Tasker integration
      case 4:
        ss.getFcmData();
        ss.fcmData.save();
        nextVersion = 4;
      case 5:
        // Find the Bright White theme and reset it back to the default (new colors)
        final brightWhite = Database.themes.query(ThemeStruct_.name.equals("Bright White")).build().findFirst();
        if (brightWhite != null) {
          brightWhite.data = ts.whiteLightTheme;
          Database.themes.put(brightWhite, mode: PutMode.update);
        }

        // Find the OLED theme and reset it back to the default (new colors)
        final oled = Database.themes.query(ThemeStruct_.name.equals("OLED Dark")).build().findFirst();
        if (oled != null) {
          oled.data = ts.oledDarkTheme;
          Database.themes.put(oled, mode: PutMode.update);
        }
    }

    if (nextVersion != version) {
      _performDatabaseMigrations(versionOverride: nextVersion);
    }

    s.stop();
    Logger.info("Completed database migration in ${s.elapsedMilliseconds}ms", tag: "DB-Migration");
  }

  /// Wrapper for store.runInTransaction
  static R runInTransaction<R>(TxMode mode, R Function() fn) {
    return store.runInTransaction(mode, fn);
  }

  static reset() {
    Database.attachments.removeAll();
    Database.chats.removeAll();
    Database.fcmData.removeAll();
    Database.contacts.removeAll();
    Database.handles.removeAll();
    Database.messages.removeAll();
    Database.themes.removeAll();
  }
}