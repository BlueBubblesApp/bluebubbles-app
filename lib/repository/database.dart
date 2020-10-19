import 'dart:io';

import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum Tables {
  chat,
  handle,
  message,
  attachment,
  chat_handle_join,
  chat_message_join,
  attachment_message_join
}

class DBProvider {
  DBProvider._();
  static final DBProvider db = DBProvider._();

  static Database _database;
  static String _path = "";

  Future<Database> get database async {
    if (_database != null) return _database;

    // if _database is null we instantiate it
    _database = await initDB();
    return _database;
  }

  String get path => _path;

  initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    _path = join(documentsDirectory.path, "chat.db");
    return await openDatabase(_path, version: 1, onOpen: (Database db) async {
      debugPrint("Database Opened");
      await checkTableExistenceAndCreate(db);
    }, onCreate: (Database db, int version) async {
      debugPrint("creating database");
      await this.buildDatabase(db);
    });
  }

  static Future<void> deleteDB() async {
    Database db = await DBProvider.db.database;

    // Remove base tables
    await Handle.flush();
    await Chat.flush();
    await Attachment.flush();
    await Message.flush();

    // Remove join tables
    await db.execute("DELETE FROM chat_handle_join");
    await db.execute("DELETE FROM chat_message_join");
    await db.execute("DELETE FROM attachment_message_join");
  }

  Future<void> checkTableExistenceAndCreate(Database db) async {
    //this is to ensure that all tables are created on start
    //this will allow us to also add more tables and make it so that users will not have to
    for (Tables tableName in Tables.values) {
      var table = await db.rawQuery(
          "SELECT * FROM sqlite_master WHERE name ='${tableName.toString().split(".").last}' and type='table'; ");
      if (table.length == 0) {
        switch (tableName) {
          case Tables.chat:
            await createChatTable(db);
            break;
          case Tables.handle:
            await createHandleTable(db);
            break;
          case Tables.message:
            await createMessageTable(db);
            break;
          case Tables.attachment:
            await createAttachmentTable(db);
            break;
          case Tables.chat_handle_join:
            await createChatHandleJoinTable(db);
            break;
          case Tables.chat_message_join:
            await createChatMessageJoinTable(db);
            break;
          case Tables.attachment_message_join:
            await createAttachmentMessageJoinTable(db);
            break;
        }
        debugPrint(
            "creating missing table " + tableName.toString().split(".").last);
      }
    }
  }

  Future<void> buildDatabase(Database db) async {
    await createHandleTable(db);
    await createChatTable(db);
    await createMessageTable(db);
    await createAttachmentTable(db);
    await createAttachmentMessageJoinTable(db);
    await createChatHandleJoinTable(db);
    await createChatMessageJoinTable(db);
    await createIndexes(db);
  }

  createHandleTable(Database db) async {
    await db.execute("CREATE TABLE handle ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "address TEXT UNIQUE NOT NULL,"
        "country TEXT DEFAULT NULL,"
        "uncanonicalizedId TEXT DEFAULT NULL"
        ");");
  }

  createChatTable(Database db) async {
    await db.execute("CREATE TABLE chat ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "guid TEXT UNIQUE NOT NULL,"
        "style INTEGER NOT NULL,"
        "chatIdentifier TEXT NOT NULL,"
        "isArchived INTEGER DEFAULT 0,"
        "isMuted INTEGER DEFAULT 0,"
        "hasUnreadMessage INTEGER DEFAULT 0,"
        "latestMessageDate INTEGER DEFAULT 0,"
        "latestMessageText TEXT,"
        "displayName TEXT DEFAULT NULL"
        ");");
  }

  createMessageTable(Database db) async {
    await db.execute("CREATE TABLE message ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "originalROWID INTEGER DEFAULT NULL,"
        "handleId INTEGER NOT NULL,"
        "guid TEXT UNIQUE NOT NULL,"
        "text TEXT,"
        "subject TEXT DEFAULT NULL,"
        "country TEXT DEFAULT NULL,"
        "error INTEGER DEFAULT 0,"
        "dateCreated INTEGER,"
        "dateRead INTEGER DEFAULT 0,"
        "dateDelivered INTEGER DEFAULT 0,"
        "isFromMe INTEGER DEFAULT 0,"
        "isDelayed INTEGER DEFAULT 0,"
        "isAutoReply INTEGER DEFAULT 0,"
        "isSystemMessage INTEGER DEFAULT 0,"
        "isServiceMessage INTEGER DEFAULT 0,"
        "isForward INTEGER DEFAULT 0,"
        "isArchived INTEGER DEFAULT 0,"
        "cacheRoomnames TEXT DEFAULT NULL,"
        "isAudioMessage INTEGER DEFAULT 0,"
        "datePlayed INTEGER DEFAULT 0,"
        "itemType INTEGER NOT NULL,"
        "groupTitle TEXT DEFAULT NULL,"
        "groupActionType INTEGER DEFAULT 0,"
        "isExpired INTEGER DEFAULT 0,"
        "associatedMessageGuid TEXT DEFAULT NULL,"
        "associatedMessageType TEXT DEFAULT NULL,"
        "expressiveSendStyleId TEXT DEFAULT NULL,"
        "timeExpressiveSendStyleId INTEGER DEFAULT 0,"
        "hasAttachments INTEGER DEFAULT 0,"
        "hasReactions INTEGER DEFAULT 0,"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID)"
        ");");
  }

  createAttachmentTable(Database db) async {
    await db.execute("CREATE TABLE attachment ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "guid TEXT UNIQUE NOT NULL,"
        "uti TEXT NOT NULL,"
        "mimeType TEXT DEFAULT NULL,"
        "transferState INTEGER DEFAULT 0,"
        "isOutgoing INTEGER DEFAULT 0,"
        "transferName INTEGER NOT NULL,"
        "totalBytes INTEGER NOT NULL,"
        "isSticker INTEGER DEFAULT 0,"
        "hideAttachment INTEGER DEFAULT 0,"
        "blurhash VARCHAR(64) DEFAULT NULL,"
        "height INTEGER DEFAULT NULL,"
        "width INTEGER DEFAULT NULL"
        ");");
  }

  createChatHandleJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_handle_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "handleId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID),"
        "UNIQUE (chatId, handleId)"
        ");");
  }

  createChatMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID),"
        "UNIQUE (chatId, messageId)"
        ");");
  }

  createAttachmentMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE attachment_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "attachmentId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(attachmentId) REFERENCES attachment(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID),"
        "UNIQUE (attachmentId, messageId)"
        ");");
  }

  createIndexes(Database db) async {
    await db.execute("CREATE UNIQUE INDEX idx_handle_address ON handle (address);");
    await db.execute("CREATE UNIQUE INDEX idx_message_guid ON message (guid);");
    await db.execute("CREATE UNIQUE INDEX idx_chat_guid ON chat (guid);");
    await db.execute("CREATE UNIQUE INDEX idx_attachment_guid ON attachment (guid);");
  }
}
