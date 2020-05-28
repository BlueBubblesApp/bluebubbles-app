import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
    return await openDatabase(_path, version: 1, onOpen: (Database db) {
      debugPrint("Database Opened");
    }, onCreate: (Database db, int version) async {
      await this.buildDatabase(db);
    });
  }

  Future<void> buildDatabase(Database db) async {
    await createHandleTable(db);
    await createChatTable(db);
    await createMessageTable(db);
    await createAttachmentTable(db);
    await createAttachmentMessageJoinTable(db);
    await createChatHandleJoinTable(db);
    await createChatMessageJoinTable(db);
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
        "displayName TEXT DEFAULT NULL"
        ");");
  }

  createMessageTable(Database db) async {
    await db.execute("CREATE TABLE message ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "handleId INTEGER NOT NULL,"
        "guid TEXT NOT NULL,"
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
        "isExpired INTEGER DEFAULT 0,"
        "associatedMessageGuid TEXT DEFAULT NULL,"
        "associatedMessageType TEXT DEFAULT NULL,"
        "expressiveSendStyleId TEXT DEFAULT NULL,"
        "timeExpressiveSendStyleId INTEGER DEFAULT 0,"
        "hasAttachments INTEGER DEFAULT 0,"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID)"
        ");");
  }

  createAttachmentTable(Database db) async {
    await db.execute("CREATE TABLE attachment ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "guid TEXT NOT NULL,"
        "uti TEXT NOT NULL,"
        "transferState INTEGER DEFAULT 0,"
        "isOutgoing INTEGER DEFAULT 0,"
        "transferName INTEGER NOT NULL,"
        "totalBytes INTEGER NOT NULL,"
        "isSticker INTEGER DEFAULT 0,"
        "hideAttachment INTEGER DEFAULT 0"
        ");");
  }

  createChatHandleJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_handle_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "handleId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(handleId) REFERENCES handle(ROWID)"
        ");");
  }

  createChatMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE chat_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "chatId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(chatId) REFERENCES chat(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID)"
        ");");
  }

  createAttachmentMessageJoinTable(Database db) async {
    await db.execute("CREATE TABLE attachment_message_join ("
        "ROWID INTEGER PRIMARY KEY AUTOINCREMENT,"
        "attachmentId INTEGER NOT NULL,"
        "messageId INTEGER NOT NULL,"
        "FOREIGN KEY(attachmentId) REFERENCES attachment(ROWID),"
        "FOREIGN KEY(messageId) REFERENCES message(ROWID)"
        ");");
  }

  deleteDB(Database db) async {
    db.close();
    deleteDatabase(_path);
  }
}
