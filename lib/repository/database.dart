import 'dart:async';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:collection/collection.dart';
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
      await migrateToObjectBox(db, initStore);
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
  }

  Future<void> migrateToObjectBox(Database db, Future<void> Function()? initStore) async {
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
      // The general premise of the migration is to transfer every single bit
      // of data from SQLite into ObjectBox. The most important thing to keep
      // track of are the IDs, since we have numerous queries that relate IDs
      // from one table to IDs from another table.
      //
      // As such, this code will create a "migration map", which contains some
      // unique identifying characteristic of the data item as the key, and
      // then another map containing the old (SQLite) ID and the new (ObjectBox)
      // ID as the value.
      //
      // This map is then used when saving the "join" tables, which would still
      // have the old (SQLite) IDs for each data item. Using the map, we can
      // update that old ID to the new ID and thus avoid creating an incorrect
      // link due to the ID mismatch.
      store.runInTransaction(TxMode.write, () {
        Logger.info("Migrating chats...", tag: "OB Migration");
        final chats = tableData[0].map((e) => Chat.fromMap(e)).toList();
        final chatIdsMigrationMap = <String, Map<String, int>>{};
        for (Chat element in chats) {
          chatIdsMigrationMap[element.guid] = {
            "old": element.id!
          };
          element.id = null;
        }
        Logger.info("Created chat ID migration map, length ${chatIdsMigrationMap.length}", tag: "OB Migration");
        chatBox.putMany(chats);
        Logger.info("Inserted chats into ObjectBox", tag: "OB Migration");
        final newChats = chatBox.getAll();
        Logger.info("Fetched ObjectBox chats, length ${newChats.length}", tag: "OB Migration");
        for (Chat element in newChats) {
          chatIdsMigrationMap[element.guid]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to chat ID migration map", tag: "OB Migration");
        chats.clear();
        newChats.clear();
        Logger.info("Migrating handles...", tag: "OB Migration");
        final handles = tableData[1].map((e) => Handle.fromMap(e)).toList();
        final handleIdsMigrationMap = <String, Map<String, int>>{};
        for (Handle element in handles) {
          handleIdsMigrationMap[element.address] = {
            "old": element.id!
          };
          element.id = null;
        }
        Logger.info("Created handle ID migration map, length ${handleIdsMigrationMap.length}", tag: "OB Migration");
        handleBox.putMany(handles);
        Logger.info("Inserted handles into ObjectBox", tag: "OB Migration");
        final newHandles = handleBox.getAll();
        Logger.info("Fetched ObjectBox handles, length ${newHandles.length}", tag: "OB Migration");
        for (Handle element in newHandles) {
          handleIdsMigrationMap[element.address]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to handle ID migration map", tag: "OB Migration");
        handles.clear();
        newHandles.clear();
        Logger.info("Migrating messages...", tag: "OB Migration");
        final messages = tableData[2].map((e) => Message.fromMap(e)).toList();
        final messageIdsMigrationMap = <String, Map<String, int>>{};
        for (Message element in messages) {
          messageIdsMigrationMap[element.guid!] = {
            "old": element.id!
          };
          element.id = null;
          if (element.handleId != null && element.handleId != 0) {
            // we must have new handle ID if the current one is known to not be null or 0
            final newHandleId = handleIdsMigrationMap.values.firstWhereOrNull((e) => e['old'] == element.handleId)?['new'];
            element.handleId = newHandleId ?? 0;
          }
        }
        Logger.info("Created message ID migration map, length ${messageIdsMigrationMap.length}", tag: "OB Migration");
        messageBox.putMany(messages);
        Logger.info("Inserted messages into ObjectBox", tag: "OB Migration");
        final newMessages = messageBox.getAll();
        Logger.info("Fetched ObjectBox messages, length ${newMessages.length}", tag: "OB Migration");
        for (Message element in newMessages) {
          messageIdsMigrationMap[element.guid!]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to message ID migration map", tag: "OB Migration");
        messages.clear();
        newMessages.clear();
        Logger.info("Migrating attachments....", tag: "OB Migration");
        final attachments = tableData[3].map((e) => Attachment.fromMap(e)).toList();
        final attachmentIdsMigrationMap = <String, Map<String, int>>{};
        for (Attachment element in attachments) {
          attachmentIdsMigrationMap[element.guid!] = {
            "old": element.id!
          };
          element.id = null;
        }
        Logger.info("Created attachment ID migration map, length ${attachmentIdsMigrationMap.length}", tag: "OB Migration");
        attachmentBox.putMany(attachments);
        Logger.info("Inserted attachments into ObjectBox", tag: "OB Migration");
        final newAttachments = attachmentBox.getAll();
        Logger.info("Fetched ObjectBox attachments, length ${newAttachments.length}", tag: "OB Migration");
        for (Attachment element in newAttachments) {
          attachmentIdsMigrationMap[element.guid!]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to attachment ID migration map", tag: "OB Migration");
        attachments.clear();
        newAttachments.clear();
        Logger.info("Migrating chat-handle joins...", tag: "OB Migration");
        List<ChatHandleJoin> chJoins = tableData[4].map((e) => ChatHandleJoin.fromMap(e)).toList();
        for (ChatHandleJoin chj in chJoins) {
          // we will always have a new and an old form of ID, so these should never error
          final newChatId = chatIdsMigrationMap.values.firstWhere((e) => e['old'] == chj.chatId)['new'];
          final newHandleId = handleIdsMigrationMap.values.firstWhereOrNull((e) => e['old'] == chj.handleId)?['new'];
          chj.chatId = newChatId!;
          chj.handleId = newHandleId ?? 0;
        }
        Logger.info("Replaced old chat & handle IDs with new ObjectBox IDs", tag: "OB Migration");
        final chats2 = chatBox.getAll();
        for (int i = 0; i < chats2.length; i++) {
          // this migration must happen cleanly, we cannot ignore any null errors
          // the chats must retain all handleIDs previously associated with them
          final handleIds = chJoins.where((e) => e.chatId == chats2[i].id).map((e) => e.handleId).toList();
          final handles = handleBox.getMany(handleIds);
          chats2[i].handles.addAll(List<Handle>.from(handles));
        }
        chatBox.putMany(chats2);
        Logger.info("Inserted chat-handle joins into ObjectBox", tag: "OB Migration");
        chJoins.clear();
        Logger.info("Migrating chat-message joins...", tag: "OB Migration");
        List<ChatMessageJoin> cmJoins = tableData[5].map((e) => ChatMessageJoin.fromMap(e)).toList();
        for (ChatMessageJoin cmj in cmJoins) {
          // we will always have a new and an old form of ID, so these should never error
          final newChatId = chatIdsMigrationMap.values.firstWhere((e) => e['old'] == cmj.chatId)['new'];
          final newMessageId = messageIdsMigrationMap.values.firstWhere((e) => e['old'] == cmj.messageId)['new'];
          cmj.chatId = newChatId!;
          cmj.messageId = newMessageId!;
        }
        Logger.info("Replaced old chat & message IDs with new ObjectBox IDs", tag: "OB Migration");
        final messages2 = messageBox.getAll();
        final toDelete = <int>[];
        for (int i = 0; i < messages2.length; i++) {
          // if we can't find a valid chatID to associate the message with, delete it
          final chatId = cmJoins.firstWhereOrNull((e) => e.messageId == messages2[i].id)?.chatId;
          if (chatId == null) {
            toDelete.add(messages2[i].id!);
          } else {
            final chat = chatBox.get(chatId);
            messages2[i].chat.target = chat;
          }
        }
        messageBox.putMany(messages2);
        messageBox.removeMany(toDelete);
        Logger.info("Inserted chat-message joins into ObjectBox", tag: "OB Migration");
        cmJoins.clear();
        Logger.info("Migrating attachment-message joins...", tag: "OB Migration");

        List<AttachmentMessageJoin> amJoins = tableData[6].map((e) => AttachmentMessageJoin.fromMap(e)).toList();
        final amjToRemove = <int>[];
        for (int i = 0; i < amJoins.length; i++) {
          // If messages were deleted, these can be null
          final newAttachmentId = attachmentIdsMigrationMap.values.firstWhereOrNull((e) => e['old'] == amJoins[i].attachmentId)?['new'];
          final newMessageId = messageIdsMigrationMap.values.firstWhereOrNull((e) => e['old'] == amJoins[i].messageId)?['new'];
          
          // If we don't have new message or attachment IDs, we need to add the index to a list
          // to be deleted later
          if (newAttachmentId != null && newMessageId != null) {
            amJoins[i].attachmentId = newAttachmentId;
            amJoins[i].messageId = newMessageId;
          } else {
            amjToRemove.add(i);
          }
        }

        // Remove all the join rows that do not have an associated message or attachment
        for (int i in amjToRemove) {
          amJoins.removeAt(i);
        }

        Logger.info("Replaced old attachment & message IDs with new ObjectBox IDs", tag: "OB Migration");
        final attachments2 = attachmentBox.getAll();
        final toDelete3 = <int>[];
        for (int i = 0; i < attachments2.length; i++) {
          // if we can't find a valid messageID to associate the attachment with, delete it
          final messageId = amJoins.firstWhereOrNull((e) => e.attachmentId == attachments2[i].id)?.messageId;
          if (messageId == null) {
            toDelete3.add(attachments2[i].id!);
          } else {
            final message = messageBox.get(messageId);
            attachments2[i].message.target = message;
          }
        }
        attachmentBox.putMany(attachments2);
        attachmentBox.removeMany(toDelete3);
        Logger.info("Inserted attachment-message joins into ObjectBox", tag: "OB Migration");
        amJoins.clear();
        Logger.info("Migrating theme objects...", tag: "OB Migration");
        final themeObjects = tableData[7].map((e) => ThemeObject.fromMap(e)).toList();
        final themeObjectIdsMigrationMap = <String, Map<String, int>>{};
        for (ThemeObject element in themeObjects) {
          themeObjectIdsMigrationMap[element.name!] = {
            "old": element.id!
          };
          element.id = null;
        }
        Logger.info("Created theme object ID migration map, length ${themeObjectIdsMigrationMap.length}", tag: "OB Migration");
        themeObjectBox.putMany(themeObjects);
        Logger.info("Inserted theme objects into ObjectBox", tag: "OB Migration");
        final newThemeObjects = themeObjectBox.getAll();
        Logger.info("Fetched ObjectBox theme objects, length ${newThemeObjects.length}", tag: "OB Migration");
        for (ThemeObject element in newThemeObjects) {
          themeObjectIdsMigrationMap[element.name]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to theme object ID migration map", tag: "OB Migration");
        themeObjects.clear();
        newThemeObjects.clear();
        Logger.info("Migrating theme entries...", tag: "OB Migration");
        final themeEntries = tableData[8].map((e) => ThemeEntry.fromMap(e)).toList();
        final themeEntryIdsMigrationMap = <String, Map<String, int>>{};
        for (ThemeEntry element in themeEntries) {
          // we will always have a new and an old form of ID, so these should never error
          final newThemeId = themeObjectIdsMigrationMap.values.firstWhere((e) => e['old'] == element.themeId)['new'];
          element.themeId = newThemeId!;
          themeEntryIdsMigrationMap["${element.name}-${element.themeId!}"] = {
            "old": element.id!
          };
          element.id = null;
        }
        Logger.info("Created theme entry ID migration map, length ${themeEntryIdsMigrationMap.length}", tag: "OB Migration");
        themeEntryBox.putMany(themeEntries);
        Logger.info("Inserted theme entries into ObjectBox", tag: "OB Migration");
        final newThemeEntries = themeEntryBox.getAll();
        Logger.info("Fetched ObjectBox theme entries, length ${newThemeEntries.length}", tag: "OB Migration");
        for (ThemeEntry element in newThemeEntries) {
          themeEntryIdsMigrationMap["${element.name}-${element.themeId!}"]!['new'] = element.id!;
        }
        Logger.info("Added new IDs to theme entry ID", tag: "OB Migration");
        themeEntries.clear();
        newThemeEntries.clear();
        Logger.info("Migrating theme-value joins...", tag: "OB Migration");
        List<ThemeValueJoin> tvJoins = tableData[9].map((e) => ThemeValueJoin.fromMap(e)).toList();
        for (ThemeValueJoin tvj in tvJoins) {
          // we will always have a new and an old form of ID, so these should never error
          final newThemeId = themeObjectIdsMigrationMap.values.firstWhere((e) => e['old'] == tvj.themeId)['new'];
          final newThemeValueId = themeEntryIdsMigrationMap.values.firstWhere((e) => e['old'] == tvj.themeValueId)['new'];
          tvj.themeId = newThemeId!;
          tvj.themeValueId = newThemeValueId!;
        }
        Logger.info("Replaced old theme object & theme entry IDs with new ObjectBox IDs", tag: "OB Migration");
        final themeValues2 = themeEntryBox.getAll();
        for (int i = 0; i < themeValues2.length; i++) {
          // this migration must happen cleanly, we cannot ignore any null errors
          // the theme values must all associate with a theme object, otherwise
          // there will be errors when trying to load the theme
          final themeId = tvJoins.firstWhere((e) => e.themeValueId == themeValues2[i].id).themeId;
          final themeObject = themeObjectBox.get(themeId);
          themeValues2[i].themeObject.target = themeObject;
        }
        themeEntryBox.putMany(themeValues2);
        Logger.info("Inserted theme-value joins into ObjectBox", tag: "OB Migration");
        tvJoins.clear();
      });
      Logger.info("Migrating FCM data...", tag: "OB Migration");
      List<ConfigEntry> entries = [];
      for (Map<String, dynamic> setting in tableData[10]) {
        entries.add(ConfigEntry.fromMap(setting));
      }
      final fcm = FCMData.fromConfigEntries(entries);
      Logger.info("Parsed FCM data from SQLite", tag: "OB Migration");
      fcm.save();
      Logger.info("Inserted FCM data into ObjectBox", tag: "OB Migration");
      prefs.setBool('objectbox-migration', true);
      Logger.info("Migration to ObjectBox complete!", tag: "OB Migration");
    }
  }
}
