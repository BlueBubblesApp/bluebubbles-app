import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/main.dart';
import 'package:objectbox/objectbox.dart';


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

@Entity()
class ScheduledMessage {
  int? id;
  String? chatGuid;
  String? message;
  int? epochTime;
  bool? completed;

  ScheduledMessage({this.id, this.chatGuid, this.message, this.epochTime, this.completed});

  factory ScheduledMessage.fromMap(Map<String, dynamic> json) {
    return new ScheduledMessage(
        id: json.containsKey("ROWID") ? json["ROWID"] : null,
        chatGuid: json["chatGuid"],
        message: json["message"],
        epochTime: json["epochTime"],
        completed: json["completed"] == 0 ? false : true);
  }

  Future<ScheduledMessage> save([bool updateIfAbsent = false]) async {
    /*final Database? db = await DBProvider.db.database;

    // Try to find an existing handle before saving it
    ScheduledMessage? existing = await ScheduledMessage.findOne(
        {"chatGuid": this.chatGuid, "message": this.message, "epochTime": this.epochTime});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      map.remove("ROWID");
      try {
        this.id = await db?.insert("scheduled", map);
      } catch (e) {
        this.id = null;
      }
    } else if (updateIfAbsent) {
      await this.update();
    }*/
    scheduledBox.put(this);

    return this;
  }

  Future<ScheduledMessage> update() async {
    /*final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (this.id != null) {
      await db?.update(
          "scheduled",
          {
            "chatGuid": this.chatGuid,
            "message": this.message,
            "epochTime": this.epochTime,
            "completed": this.completed! ? 1 : 0
          },
          where: "ROWID = ?",
          whereArgs: [this.id]);
    } else {
      await this.save(false);
    }*/
    this.save();

    return this;
  }

  static Future<List<ScheduledMessage>> find([Map<String, dynamic> filters = const {}]) async {
    return scheduledBox.getAll();
  }

  static flush() async {
    scheduledBox.removeAll();
    /*final Database? db = await DBProvider.db.database;
    await db?.delete("scheduled");*/
  }

  Map<String, dynamic> toMap() =>
      {"ROWID": id, "chatGuid": chatGuid, "message": message, "epochTime": epochTime, "completed": completed! ? 1 : 0};
}
