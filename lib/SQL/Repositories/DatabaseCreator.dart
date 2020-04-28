import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Database db;

class DatabaseCreator {
  static const chatsTable = 'chats';
  static const messagesTable = 'messages';

  static void databaseLog(String functionName, String sql,
      [List<Map<String, dynamic>> selectQueryResult,
      int insertAndUpdateQueryResult,
      List<dynamic> params]) {
    print(functionName);
    print(sql);
    if (params != null) {
      print(params);
    }
    if (selectQueryResult != null) {
      print(selectQueryResult);
    } else if (insertAndUpdateQueryResult != null) {
      print(insertAndUpdateQueryResult);
    }
  }

  Future<void> createChatsTable(Database db) async {
    final chatSql = '''CREATE TABLE $chatsTable
    (
      id INTEGER PRIMARY KEY,
      guid TEXT,
      title MEDIUMTEXT,
      lastMessage MEDIUMTEXT,
      lastMessageTimeStamp INT,
      chatIdentifier TEXT
    )''';

    await db.execute(chatSql);
  }

  Future<void> createMessagesTable(Database db) async {
    final messageSql = '''CREATE TABLE $messagesTable
    (
      id INTEGER PRIMARY KEY,
      guid TEXT,
      text LONGTEXT,
      chatGuid TEXT,
      dateCreated INTEGER,
      attachments TEXT,
      isFromMe BIT DEFAULT 1
    )''';

    await db.execute(messageSql);
  }

  Future<String> getDatabasePath(String dbName) async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, dbName);

    //make sure the folder exists
    if (await Directory(dirname(path)).exists()) {
      //await deleteDatabase(path);
    } else {
      await Directory(dirname(path)).create(recursive: true);
    }
    return path;
  }

  Future<void> initDatabase() async {
    final path = await getDatabasePath('chats_db');
    db = await openDatabase(path, version: 1, onCreate: onCreate);
    print(db);
  }

  Future<void> onCreate(Database db, int version) async {
    await createChatsTable(db);
    await createMessagesTable(db);
  }
}
