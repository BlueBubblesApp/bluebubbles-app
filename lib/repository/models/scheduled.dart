import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import './chat.dart';
import '../database.dart';

ScheduledMessage scheduledFromJson(String str) {
  final jsonData = json.decode(str);
  return ScheduledMessage.fromMap(jsonData);
}

String scheduledToJson(ScheduledMessage data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class ScheduledMessage {
  int? id;
  String? chatGuid;
  String? message;
  int? epochTime;
  bool? completed;

  ScheduledMessage({this.id, this.chatGuid, this.message, this.epochTime, this.completed});

  factory ScheduledMessage.fromMap(Map<String, dynamic> json) {
    return ScheduledMessage(
        id: json.containsKey("ROWID") ? json["ROWID"] : null,
        chatGuid: json["chatGuid"],
        message: json["message"],
        epochTime: json["epochTime"],
        completed: json["completed"] == 0 ? false : true);
  }

  Future<ScheduledMessage> save([bool updateIfAbsent = false]) async {
    final Database? db = await DBProvider.db.database;

    // Try to find an existing handle before saving it
    ScheduledMessage? existing = await ScheduledMessage.findOne(
        {"chatGuid": chatGuid, "message": message, "epochTime": epochTime});
    if (existing != null) {
      id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = toMap();
      map.remove("ROWID");
      try {
        id = await db?.insert("scheduled", map);
      } catch (e) {
        id = null;
      }
    } else if (updateIfAbsent) {
      await update();
    }

    return this;
  }

  Future<ScheduledMessage> update() async {
    final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (id != null) {
      await db?.update(
          "scheduled",
          {
            "chatGuid": chatGuid,
            "message": message,
            "epochTime": epochTime,
            "completed": completed! ? 1 : 0
          },
          where: "ROWID = ?",
          whereArgs: [id]);
    } else {
      await save(false);
    }

    return this;
  }

  static Future<ScheduledMessage?> findOne(Map<String, dynamic> filters) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    for (var filter in filters.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in filters.values) {
      whereArgs.add(filter);
    }
    var res = await db.query("scheduled", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return ScheduledMessage.fromMap(res.elementAt(0));
  }

  static Future<List<ScheduledMessage>> find([Map<String, dynamic> filters = const {}]) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return [];
    List<String> whereParams = [];
    for (var filter in filters.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in filters.values) {
      whereArgs.add(filter);
    }
    var res = await db.query("scheduled",
        where: (whereParams.isNotEmpty) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.isNotEmpty) ? whereArgs : null);

    return (res.isNotEmpty) ? res.map((c) => ScheduledMessage.fromMap(c)).toList() : [];
  }

  static Future<List<ScheduledMessage>> getScheduledMessages(Chat chat) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return [];
    var res = await db.rawQuery(
        "SELECT"
        " scheduled.ROWID AS ROWID,"
        " scheduled.chatGuid AS chatGuid,"
        " scheduled.message AS message,"
        " scheduled.epochTime AS epochTime,"
        " scheduled.completed AS completed,"
        " FROM scheduled"
        " WHERE scheduled.chatGuid = ?;",
        [chat.guid]);

    return (res.isNotEmpty) ? res.map((c) => ScheduledMessage.fromMap(c)).toList() : [];
  }

  static flush() async {
    final Database? db = await DBProvider.db.database;
    await db?.delete("scheduled");
  }

  Map<String, dynamic> toMap() =>
      {"ROWID": id, "chatGuid": chatGuid, "message": message, "epochTime": epochTime, "completed": completed! ? 1 : 0};
}
