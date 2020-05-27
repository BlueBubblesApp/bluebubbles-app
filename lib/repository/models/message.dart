import 'dart:convert';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../database.dart';
import 'handle.dart';
import '../../helpers/utils.dart';

Message messageFromJson(String str) {
  final jsonData = json.decode(str);
  return Message.fromMap(jsonData);
}

String messageToJson(Message data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class Message {
  int id;
  String guid;
  int handleId;
  String text;
  String subject;
  String country;
  bool error;
  DateTime dateCreated;
  DateTime dateRead;
  DateTime dateDelivered;
  bool isFromMe;
  bool isDelayed;
  bool isAutoReply;
  bool isSystemMessage;
  bool isServiceMessage;
  bool isForward;
  bool isArchived;
  String cacheRoomnames;
  bool isAudioMessage;
  DateTime datePlayed;
  int itemType;
  String groupTitle;
  bool isExpired;
  String associatedMessageGuid;
  String associatedMessageType;
  String expressiveSendStyleId;
  DateTime timeExpressiveSendStyleId;
  Handle from;
  bool hasAttachments;

  Message(
      {this.id,
      this.guid,
      this.handleId,
      this.text,
      this.subject,
      this.country,
      this.error,
      this.dateCreated,
      this.dateRead,
      this.dateDelivered,
      this.isFromMe,
      this.isDelayed,
      this.isAutoReply,
      this.isSystemMessage,
      this.isServiceMessage,
      this.isForward,
      this.isArchived,
      this.cacheRoomnames,
      this.isAudioMessage,
      this.datePlayed,
      this.itemType,
      this.groupTitle,
      this.isExpired,
      this.associatedMessageGuid,
      this.associatedMessageType,
      this.expressiveSendStyleId,
      this.timeExpressiveSendStyleId,
      this.from,
      this.hasAttachments});

  factory Message.fromMap(Map<String, dynamic> json) {
    return new Message(
        id: json.containsKey("ROWID") ? json["ROWID"] : null,
        guid: json["guid"],
        handleId: (json["handleId"] != null) ? json["handleId"] : 0,
        text: json["text"],
        subject: json.containsKey("subject") ? json["subject"] : null,
        country: json.containsKey("country") ? json["country"] : null,
        error: (json["error"] is bool)
            ? json['error']
            : ((json['error'] == 1) ? true : false),
        dateCreated: json.containsKey("dateCreated")
            ? parseDate(json["dateCreated"])
            : null,
        dateRead:
            json.containsKey("dateRead") ? parseDate(json["dateRead"]) : null,
        dateDelivered: json.containsKey("dateDelivered")
            ? parseDate(json["dateDelivered"])
            : null,
        isFromMe: (json["isFromMe"] is bool)
            ? json['isFromMe']
            : ((json['isFromMe'] == 1) ? true : false),
        isDelayed: (json["isDelayed"] is bool)
            ? json['isDelayed']
            : ((json['isDelayed'] == 1) ? true : false),
        isAutoReply: (json["isAutoReply"] is bool)
            ? json['isAutoReply']
            : ((json['isAutoReply'] == 1) ? true : false),
        isSystemMessage: (json["isSystemMessage"] is bool)
            ? json['isSystemMessage']
            : ((json['isSystemMessage'] == 1) ? true : false),
        isServiceMessage: (json["isServiceMessage"] is bool)
            ? json['isServiceMessage']
            : ((json['isServiceMessage'] == 1) ? true : false),
        isForward: (json["isForward"] is bool)
            ? json['isForward']
            : ((json['isForward'] == 1) ? true : false),
        isArchived: (json["isArchived"] is bool)
            ? json['isArchived']
            : ((json['isArchived'] == 1) ? true : false),
        cacheRoomnames:
            json.containsKey("cacheRoomnames") ? json["cacheRoomnames"] : null,
        isAudioMessage: (json["isAudioMessage"] is bool)
            ? json['isAudioMessage']
            : ((json['isAudioMessage'] == 1) ? true : false),
        datePlayed: json.containsKey("datePlayed")
            ? parseDate(json["datePlayed"])
            : null,
        itemType: json.containsKey("itemType") ? json["itemType"] : null,
        groupTitle: json.containsKey("groupTitle") ? json["groupTitle"] : null,
        isExpired: (json["isExpired"] is bool)
            ? json['isExpired']
            : ((json['isExpired'] == 1) ? true : false),
        associatedMessageGuid: json.containsKey("associatedMessageGuid")
            ? json["associatedMessageGuid"]
            : null,
        associatedMessageType: json.containsKey("associatedMessageType")
            ? json["associatedMessageType"]
            : null,
        expressiveSendStyleId: json.containsKey("expressiveSendStyleId")
            ? json["expressiveSendStyleId"]
            : null,
        timeExpressiveSendStyleId: json.containsKey("timeExpressiveSendStyleId")
            ? parseDate(json["timeExpressiveSendStyleId"])
            : null,
        from: json.containsKey("from")
            ? (json['from'] != null ? Handle.fromMap(json['from']) : null)
            : null,
        hasAttachments: json.containsKey("attachments")
            ? (((json['attachments'] as List<dynamic>).length > 0)
                ? true
                : false)
            : false);
  }

  Future<Message> save([bool updateIfAbsent = true]) async {
    final Database db = await DBProvider.db.database;

    // Try to find an existing chat before saving it
    Message existing = await Message.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
    }

    // Save the participant
    if (this.from != null) {
      await this.from.save();

      // Pull out the from ID, if it's present and not null
      if (this.handleId == null && this.from.id != null) {
        debugPrint("setting handle ID to from ID: " + this.from.id.toString());
        this.handleId = this.from.id;
      }
    } else {
      debugPrint("this.from is null");
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("from")) {
        map.remove("from");
      }

      //this is where the issue is
      this.id = await db.insert("message", map);
    } else if (updateIfAbsent) {
      await this.update();
    }

    return this;
  }

  Future<Message> createMessage() async {}

  Future<Message> update() async {
    final Database db = await DBProvider.db.database;

    Map<String, dynamic> params = {
      "dateCreated": (this.dateCreated == null)
          ? null
          : this.dateCreated.millisecondsSinceEpoch,
      "dateRead":
          (this.dateRead == null) ? null : this.dateRead.millisecondsSinceEpoch,
      "dateDelivered": (this.dateDelivered == null)
          ? null
          : this.dateDelivered.millisecondsSinceEpoch,
      "isArchived": (this.isArchived) ? 1 : 0,
      "datePlayed": (this.datePlayed == null)
          ? null
          : this.datePlayed.millisecondsSinceEpoch,
    };

    // If it already exists, update it
    if (this.id != null) {
      await db.update("message", params);
    } else {
      await this.save(false);
    }

    return this;
  }

  //remove duplicate messages
  static cleanMessages() async {
    final Database db = await DBProvider.db.database;
  }

  static Future<List<Attachment>> getAttachments(Message message) async {
    final Database db = await DBProvider.db.database;

    var res = await db.rawQuery(
        "SELECT"
        " attachment.ROWID AS ROWID,"
        " attachment.guid AS guid,"
        " attachment.uti AS uti,"
        " attachment.transferState AS transferState,"
        " attachment.isOutgoing AS isOutgoing,"
        " attachment.transferName AS transferName,"
        " attachment.totalBytes AS totalBytes,"
        " attachment.isSticker AS isSticker,"
        " attachment.hideAttachment AS hideAttachment"
        " FROM message"
        " JOIN attachment_message_join AS amj ON message.ROWID = amj.messageId"
        " JOIN attachment ON attachment.ROWID = amj.attachmentId"
        " WHERE message.ROWID = ?;",
        [message.id]);

    return (res.isNotEmpty)
        ? res.map((c) => Attachment.fromMap(c)).toList()
        : [];
  }

  Future<Handle> getFrom() async {
    final Database db = await DBProvider.db.database;

    var res = await db.rawQuery(
        "SELECT"
        " handle.ROWID AS ROWID,"
        " handle.address AS address,"
        " handle.country AS country,"
        " handle.uncanonicalizedId AS uncanonicalizedId"
        " FROM handle"
        " JOIN message ON message.handleId = handle.ROWID"
        " WHERE message.ROWID = ?;",
        [this.id]);

    this.from =
        (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList()[0] : null;
    return this.from;
  }

  static Future<Message> findOne(Map<String, dynamic> filters) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("message",
        where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Message.fromMap(res.elementAt(0));
  }

  static Future<List<Message>> find(
      [Map<String, dynamic> filters = const {}]) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));

    var res = await db.query("message",
        where: (whereParams.length > 0) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.length > 0) ? whereArgs : null);
    return (res.isNotEmpty) ? res.map((c) => Message.fromMap(c)).toList() : [];
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "guid": guid,
        "handleId": handleId,
        "text": text,
        "subject": subject,
        "country": country,
        "error": error ? 1 : 0,
        "dateCreated":
            (dateCreated == null) ? null : dateCreated.millisecondsSinceEpoch,
        "dateRead": (dateRead == null) ? null : dateRead.millisecondsSinceEpoch,
        "dateDelivered": (dateDelivered == null)
            ? null
            : dateDelivered.millisecondsSinceEpoch,
        "isFromMe": isFromMe ? 1 : 0,
        "isDelayed": isDelayed ? 1 : 0,
        "isAutoReply": isAutoReply ? 1 : 0,
        "isSystemMessage": isSystemMessage ? 1 : 0,
        "isServiceMessage": isServiceMessage ? 1 : 0,
        "isForward": isForward ? 1 : 0,
        "isArchived": isArchived ? 1 : 0,
        "cacheRoomnames": cacheRoomnames,
        "isAudioMessage": isAudioMessage ? 1 : 0,
        "datePlayed":
            (datePlayed == null) ? null : datePlayed.millisecondsSinceEpoch,
        "itemType": itemType,
        "groupTitle": groupTitle,
        "isExpired": isExpired ? 1 : 0,
        "associatedMessageGuid": associatedMessageGuid,
        "associatedMessageType": associatedMessageType,
        "expressiveSendStyleId": expressiveSendStyleId,
        "timeExpressiveSendStyleId": (timeExpressiveSendStyleId == null)
            ? null
            : timeExpressiveSendStyleId.millisecondsSinceEpoch,
        "from": (from != null) ? from.toMap() : null
      };
}
