import 'dart:convert';
import 'dart:io';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database.dart';

Attachment attachmentFromJson(String str) {
  final jsonData = json.decode(str);
  return Attachment.fromMap(jsonData);
}

String attachmentToJson(Attachment data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class Attachment {
  int id;
  String guid;
  String uti;
  String mimeType;
  String transferState;
  bool isOutgoing;
  String transferName;
  int totalBytes;
  bool isSticker;
  bool hideAttachment;
  String blurhash;

  Attachment({
    this.id,
    this.guid,
    this.uti,
    this.mimeType,
    this.transferState,
    this.isOutgoing,
    this.transferName,
    this.totalBytes,
    this.isSticker,
    this.hideAttachment,
    this.blurhash,
  });

  factory Attachment.fromMap(Map<String, dynamic> json) {
    return new Attachment(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      guid: json["guid"],
      uti: json["uti"],
      mimeType: json["mimeType"],
      transferState: json['transferState'].toString(),
      isOutgoing: (json["isOutgoing"] is bool)
          ? json['isOutgoing']
          : ((json['isOutgoing'] == 1) ? true : false),
      transferName: json['transferName'],
      totalBytes: json['totalBytes'] is int ? json['totalBytes'] : 0,
      isSticker: (json["isSticker"] is bool)
          ? json['isSticker']
          : ((json['isSticker'] == 1) ? true : false),
      hideAttachment: (json["hideAttachment"] is bool)
          ? json['hideAttachment']
          : ((json['hideAttachment'] == 1) ? true : false),
      blurhash: json.containsKey("blurhash") ? json["blurhash"] : null,
    );
  }

  Future<Attachment> save(Message message) async {
    final Database db = await DBProvider.db.database;

    // Try to find an existing attachment before saving it
    Attachment existing = await Attachment.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("participants")) {
        map.remove("participants");
      }
      // if (message.id == null) {
      //   //and here
      //   await message.save();
      // }

      this.id = await db.insert("attachment", map);
      await db.insert("attachment_message_join",
          {"attachmentId": this.id, "messageId": message.id});
    }

    return this;
  }

  static Future<Attachment> replaceAttachment(
      String oldGuid, Attachment newAttachment) async {
    final Database db = await DBProvider.db.database;
    Attachment existing = await Attachment.findOne({"guid": oldGuid});
    if (existing == null) {
      throw ("Old GUID does not exist!");
    }

    Map<String, dynamic> params = newAttachment.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("handle")) {
      params.remove("handle");
    }

    await db.update("attachment", params,
        where: "ROWID = ?", whereArgs: [existing.id]);
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/$oldGuid";
    Directory directory = Directory(pathName);
    await directory.rename("$appDocPath/${newAttachment.guid}");
    return existing;
  }

  static Future<Attachment> findOne(Map<String, dynamic> filters) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("attachment",
        where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Attachment.fromMap(res.elementAt(0));
  }

  static Future<List<Attachment>> find(
      [Map<String, dynamic> filters = const {}]) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));

    var res = await db.query("attachment",
        where: (whereParams.length > 0) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.length > 0) ? whereArgs : null);
    return (res.isNotEmpty)
        ? res.map((c) => Attachment.fromMap(c)).toList()
        : [];
  }

  static flush() async {
    final Database db = await DBProvider.db.database;
    await db.delete("attachment");
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "guid": guid,
        "uti": uti,
        "mimeType": mimeType,
        "transferState": transferState,
        "isOutgoing": isOutgoing ? 1 : 0,
        "transferName": transferName,
        "totalBytes": totalBytes,
        "isSticker": isSticker ? 1 : 0,
        "hideAttachment": hideAttachment ? 1 : 0,
        "blurhash": blurhash,
      };
}
