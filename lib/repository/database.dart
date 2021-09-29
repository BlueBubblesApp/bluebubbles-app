import 'dart:async';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/foundation.dart';
//ignore: implementation_imports
import 'package:objectbox/src/transaction.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_io/io.dart';

enum Tables {
  chat,
  handle,
  message,
  attachment,
  chat_handle_join,
  chat_message_join,
  attachment_message_join,
  themes,
  theme_values,
  theme_value_join,
  fcm,
}

class DBUpgradeItem {
  int addedInVersion;
  Function(Database) upgrade;

  DBUpgradeItem({required this.addedInVersion, required this.upgrade});
}

class DBProvider {
  DBProvider._();

  static final DBProvider db = DBProvider._();

  static int currentVersion = 14;

  /// Contains list of functions to invoke when going from a previous to the current database verison
  /// The previous version is always [key - 1], for example for key 2, it will be the upgrade scheme from version 1 to version 2
  static final List<DBUpgradeItem> upgradeSchemes = [
    DBUpgradeItem(
        addedInVersion: 2,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN hasDdResults INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 3,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN balloonBundleId TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isFiltered INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 4,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN dateDeleted INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN isPinned INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 5,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE attachment ADD COLUMN originalROWID INTEGER DEFAULT NULL;");
          db.execute("ALTER TABLE message ADD COLUMN otherHandle INTEGER DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 6,
        upgrade: (Database db) {
          db.execute("ALTER TABLE attachment ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 7,
        upgrade: (Database db) {
          db.execute("ALTER TABLE message ADD COLUMN metadata TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 8,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN color TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 9,
        upgrade: (Database db) {
          db.execute("ALTER TABLE handle ADD COLUMN defaultPhone TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 10,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN customAvatarPath TEXT DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 11,
        upgrade: (Database db) {
          db.execute("ALTER TABLE chat ADD COLUMN pinIndex INTEGER DEFAULT NULL;");
        }),
    DBUpgradeItem(
        addedInVersion: 12,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE chat ADD COLUMN muteType TEXT DEFAULT NULL;");
          db.execute("ALTER TABLE chat ADD COLUMN muteArgs TEXT DEFAULT NULL;");
          await db.update("chat", {'muteType': 'mute'}, where: "isMuted = ?", whereArgs: [1]);
        }),
    DBUpgradeItem(
        addedInVersion: 13,
        upgrade: (Database db) {
          db.execute("ALTER TABLE themes ADD COLUMN gradientBg INTEGER DEFAULT 0;");
        }),
    DBUpgradeItem(
        addedInVersion: 14,
        upgrade: (Database db) async {
          db.execute("ALTER TABLE themes ADD COLUMN previousLightTheme INTEGER DEFAULT 0;");
          db.execute("ALTER TABLE themes ADD COLUMN previousDarkTheme INTEGER DEFAULT 0;");
          Settings s = await Settings.getSettingsOld(db);
          s.save();
          db.execute("DELETE FROM config");
        }),
  ];

  Future<Database> initDB({Future<void> Function()? initStore}) async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    }
    //ignore: unnecessary_cast, we need this as a workaround
    Directory documentsDirectory = (await getApplicationDocumentsDirectory()) as Directory;
    //ignore: unnecessary_cast, we need this as a workaround
    if (kIsDesktop) documentsDirectory = (await getApplicationSupportDirectory()) as Directory;
    String path = join(documentsDirectory.path, "chat.db");
    return await openDatabase(path, version: currentVersion, onUpgrade: _onUpgrade, onOpen: (Database db) async {
      Logger.info("Database Opened");
      await checkTableExistenceAndCreate(db, initStore);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run each upgrade scheme for every difference in version.
    // If the user is on version 1 and they need to upgrade to version 3,
    // then we will run every single scheme from 1 -> 2 and 2 -> 3

    for (DBUpgradeItem item in upgradeSchemes) {
      if (oldVersion < item.addedInVersion) {
        Logger.info("Upgrading DB from version $oldVersion to version $newVersion");

        try {
          await item.upgrade(db);
        } catch (ex) {
          Logger.error("Failed to perform DB upgrade: ${ex.toString()}");
        }
      }
    }
  }

  static Future<void> deleteDB() async {
    if (kIsWeb) return;
    attachmentBox.removeAll();
    chatBox.removeAll();
    fcmDataBox.removeAll();
    handleBox.removeAll();
    messageBox.removeAll();
    scheduledBox.removeAll();
    themeEntryBox.removeAll();
    themeObjectBox.removeAll();
    amJoinBox.removeAll();
    chJoinBox.removeAll();
    cmJoinBox.removeAll();
    tvJoinBox.removeAll();
  }

  Future<void> checkTableExistenceAndCreate(Database db, Future<void> Function()? initStore) async {
    //this is to ensure that all tables are created on start
    //this will allow us to also add more tables and make it so that users will not have to
    if (initStore != null) {
      Stopwatch s = Stopwatch();
      s.start();
      List<List<dynamic>> tableData = [];
      for (Tables tableName in Tables.values) {
        final table = await db.rawQuery("SELECT * FROM ${tableName.toString().split(".").last}");
        tableData.add(table);
      }
      s.stop();
      Logger.info("Pulled data in ${s.elapsedMilliseconds} ms");
      await initStore.call();
      attachmentBox.removeAll();
      chatBox.removeAll();
      fcmDataBox.removeAll();
      handleBox.removeAll();
      messageBox.removeAll();
      scheduledBox.removeAll();
      themeEntryBox.removeAll();
      themeObjectBox.removeAll();
      amJoinBox.removeAll();
      chJoinBox.removeAll();
      cmJoinBox.removeAll();
      tvJoinBox.removeAll();
      store.runInTransaction(TxMode.write, () {
        List<Chat> chats = tableData[0].map((e) => Chat.fromMap(e)).toList();
        for (Chat element in chats) {
          element.id = null;
        }
        chatBox.putMany(chats);
        chats.clear();
        List<Handle> handles = tableData[1].map((e) => Handle.fromMap(e)).toList();
        for (Handle element in handles) {
          element.id = null;
        }
        handleBox.putMany(handles);
        handles.clear();
        List<Message> messages = tableData[2].map((e) => Message.fromMap(e)).toList();
        for (Message element in messages) {
          element.id = null;
        }
        messageBox.putMany(messages);
        messages.clear();
        List<Attachment> attachments = tableData[3].map((e) => Attachment.fromMap(e)).toList();
        for (Attachment element in attachments) {
          element.id = null;
        }
        attachmentBox.putMany(attachments);
        attachments.clear();
        List<ChatHandleJoin> chJoins = tableData[4].map((e) => ChatHandleJoin.fromMap(e)).toList();
        chJoinBox.putMany(chJoins);
        chJoins.clear();
        List<ChatMessageJoin> cmJoins = tableData[5].map((e) => ChatMessageJoin.fromMap(e)).toList();
        cmJoinBox.putMany(cmJoins);
        cmJoins.clear();
        List<AttachmentMessageJoin> amJoins = tableData[6].map((e) => AttachmentMessageJoin.fromMap(e)).toList();
        amJoinBox.putMany(amJoins);
        amJoins.clear();
        List<ThemeObject> themeObjects = tableData[7].map((e) => ThemeObject.fromMap(e)).toList();
        for (ThemeObject element in themeObjects) {
          element.id = null;
        }
        themeObjectBox.putMany(themeObjects);
        themeObjects.clear();
        List<ThemeEntry> themeEntries = tableData[8].map((e) => ThemeEntry.fromMap(e)).toList();
        for (ThemeEntry element in themeEntries) {
          element.id = null;
        }
        themeEntryBox.putMany(themeEntries);
        themeEntries.clear();
        List<ThemeValueJoin> tvJoins = tableData[9].map((e) => ThemeValueJoin.fromMap(e)).toList();
        tvJoinBox.putMany(tvJoins);
        tvJoins.clear();
      });
      List<ConfigEntry> entries = [];
      for (Map<String, dynamic> setting in tableData[10]) {
        entries.add(ConfigEntry.fromMap(setting));
      }
      final fcm = FCMData.fromConfigEntries(entries);
      fcm.save();
      prefs.setBool('objectbox-migration', true);
    }
  }
}
