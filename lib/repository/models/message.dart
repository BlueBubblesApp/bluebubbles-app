import 'dart:convert';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../database.dart';
import 'chat.dart';
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
  int originalROWID;
  String guid;
  int handleId;
  String text;
  String subject;
  String country;
  int error;
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
  int groupActionType;
  bool isExpired;
  String associatedMessageGuid;
  String associatedMessageType;
  String expressiveSendStyleId;
  DateTime timeExpressiveSendStyleId;
  Handle handle;
  bool hasAttachments;
  bool hasReactions;
  List<Attachment> attachments;

  Message({
    this.id,
    this.originalROWID,
    this.guid,
    this.handleId,
    this.text,
    this.subject,
    this.country,
    this.error = 0,
    this.dateCreated,
    this.dateRead,
    this.dateDelivered,
    this.isFromMe = true,
    this.isDelayed = false,
    this.isAutoReply = false,
    this.isSystemMessage = false,
    this.isServiceMessage = false,
    this.isForward = false,
    this.isArchived = false,
    this.cacheRoomnames,
    this.isAudioMessage = false,
    this.datePlayed,
    this.itemType = 0,
    this.groupTitle,
    this.groupActionType = 0,
    this.isExpired = false,
    this.associatedMessageGuid,
    this.associatedMessageType,
    this.expressiveSendStyleId,
    this.timeExpressiveSendStyleId,
    this.handle,
    this.hasAttachments = false,
    this.hasReactions = false,
    this.attachments,
  });

  factory Message.fromMap(Map<String, dynamic> json) {
    bool hasAttachments = false;
    if (json.containsKey("hasAttachments")) {
      hasAttachments = json["hasAttachments"] == 1 ? true : false;
    } else if (json.containsKey("attachments")) {
      hasAttachments = (json['attachments'] as List).length > 0 ? true : false;
    }

    List<Attachment> attachments = json.containsKey("attachments")
        ? (json['attachments'] as List)
            .map((a) => Attachment.fromMap(a))
            .toList()
        : [];

    String associatedMessageGuid;
    if (json.containsKey("associatedMessageGuid") &&
        json["associatedMessageGuid"] != null) {
      if ((json["associatedMessageGuid"] as String).contains("/")) {
        associatedMessageGuid =
            (json["associatedMessageGuid"] as String).split("/").last;
      } else {
        associatedMessageGuid =
            (json["associatedMessageGuid"] as String).split(":").last;
      }
    }

    return new Message(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID:
          json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      handleId: (json["handleId"] != null) ? json["handleId"] : 0,
      text: sanitizeString(json["text"]),
      subject: json.containsKey("subject") ? json["subject"] : null,
      country: json.containsKey("country") ? json["country"] : null,
      error: json.containsKey("error") ? json["error"] : 0,
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
      datePlayed:
          json.containsKey("datePlayed") ? parseDate(json["datePlayed"]) : null,
      itemType: json.containsKey("itemType") ? json["itemType"] : null,
      groupTitle: json.containsKey("groupTitle") ? json["groupTitle"] : null,
      groupActionType:
          (json["groupActionType"] != null) ? json["groupActionType"] : 0,
      isExpired: (json["isExpired"] is bool)
          ? json['isExpired']
          : ((json['isExpired'] == 1) ? true : false),
      associatedMessageGuid: associatedMessageGuid,
      associatedMessageType: json.containsKey("associatedMessageType")
          ? json["associatedMessageType"]
          : null,
      expressiveSendStyleId: json.containsKey("expressiveSendStyleId")
          ? json["expressiveSendStyleId"]
          : null,
      timeExpressiveSendStyleId: json.containsKey("timeExpressiveSendStyleId")
          ? parseDate(json["timeExpressiveSendStyleId"])
          : null,
      handle: json.containsKey("handle")
          ? (json['handle'] != null ? Handle.fromMap(json['handle']) : null)
          : null,
      hasAttachments: hasAttachments,
      attachments: attachments,
      hasReactions: json.containsKey('hasReactions')
          ? ((json['hasReactions'] == 1) ? true : false)
          : false,
    );
  }

  Future<Message> save([bool updateIfAbsent = true]) async {
    final Database db = await DBProvider.db.database;
    // Try to find an existing chat before saving it
    Message existing = await Message.findOne({"guid": this.guid});
    if (existing != null) {
      this.id = existing.id;
    }

    // Save the participant & set the handle ID to the new participant
    if (this.handle != null) {
      await this.handle.save();
      this.handleId = this.handle.id;
    }
    // QueueManager().logger.log(Level.info,
    //     "this.handle == null ${this.handle == null}, this.handleId = ${this.handleId}");

    // QueueManager()
    //     .logger
    //     .log(Level.info, "existing == null ${existing == null}");
    if (this.associatedMessageType != null &&
        this.associatedMessageGuid != null) {
      Message associatedMessage =
          await Message.findOne({"guid": this.associatedMessageGuid});
      if (associatedMessage != null) {
        associatedMessage.hasReactions = true;
        await associatedMessage.save();
      }
    } else if (!this.hasReactions) {
      Message reaction =
          await Message.findOne({"associatedMessageGuid": this.guid});
      if (reaction != null) {
        this.hasReactions = true;
      }
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      if (this.handleId == null) this.handleId = 0;
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("handle")) {
        map.remove("handle");
      }

      this.id = await db.insert("message", map);
    } else if (updateIfAbsent) {
      await this.update();
    }

    return this;
  }

  static Future<Message> replaceMessage(String oldGuid, Message newMessage,
      {bool awaitNewMessageEvent = true, Chat chat}) async {
    final Database db = await DBProvider.db.database;
    Message existing = await Message.findOne({"guid": oldGuid});
    if (existing == null) {
      if (awaitNewMessageEvent) {
        await Future.delayed(Duration(milliseconds: 500));
        return replaceMessage(oldGuid, newMessage,
            awaitNewMessageEvent: false, chat: chat);
      } else {
        if (chat != null) {
          debugPrint("adding message to chat");
          await newMessage.save();
          await chat.save();
          await chat.addMessage(newMessage);
          NewMessageManager().addMessage(chat, newMessage, outgoing: false);
          return newMessage;
        }
      }
      // return null;
    }

    Map<String, dynamic> params = newMessage.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("handle")) {
      params.remove("handle");
    }

    if (existing.toMap().containsKey("handleId")) {
      params["handleId"] = existing.toMap()["handleId"];
      newMessage.handleId = existing.handleId;
    }
    if (existing.hasAttachments) {
      params["hasAttachments"] = existing.hasAttachments ? 1 : 0;
      newMessage.hasAttachments = existing.hasAttachments;
    }
    if (existing.toMap().containsKey("hasReactions")) {
      params["hasReactions"] = existing.toMap()["hasReactions"];
      newMessage.hasReactions = existing.hasReactions;
    }

    await db.update("message", params,
        where: "ROWID = ?", whereArgs: [existing.id]);
    return newMessage;
  }

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
      "error": this.error,
      "hasReactions": this.hasReactions ? 1 : 0,
    };

    // If it already exists, update it
    if (this.id != null) {
      await db
          .update("message", params, where: "ROWID = ?", whereArgs: [this.id]);
    } else {
      await this.save(false);
    }

    return this;
  }

  static Future<List<Attachment>> getAttachments(Message message) async {
    if (message.hasAttachments &&
        message.attachments != null &&
        message.attachments.length != 0) {
      return message.attachments ?? [];
    }

    final Database db = await DBProvider.db.database;
    if (message.id == null) return [];

    var res = await db.rawQuery(
        "SELECT"
        " attachment.ROWID AS ROWID,"
        " attachment.guid AS guid,"
        " attachment.uti AS uti,"
        " attachment.mimeType AS mimeType,"
        " attachment.transferState AS transferState,"
        " attachment.isOutgoing AS isOutgoing,"
        " attachment.transferName AS transferName,"
        " attachment.totalBytes AS totalBytes,"
        " attachment.isSticker AS isSticker,"
        " attachment.hideAttachment AS hideAttachment,"
        " attachment.blurhash AS blurhash,"
        " attachment.width AS width,"
        " attachment.height AS height"
        " FROM message"
        " JOIN attachment_message_join AS amj ON message.ROWID = amj.messageId"
        " JOIN attachment ON attachment.ROWID = amj.attachmentId"
        " WHERE message.ROWID = ?;",
        [message.id]);

    message.attachments =
        (res.isNotEmpty) ? res.map((c) => Attachment.fromMap(c)).toList() : [];

    return message.attachments;
  }

  static Future<Chat> getChat(Message message) async {
    final Database db = await DBProvider.db.database;

    var res = await db.rawQuery(
        "SELECT"
        " chat.ROWID AS ROWID,"
        " chat.guid AS guid,"
        " chat.style AS style,"
        " chat.chatIdentifier AS chatIdentifier,"
        " chat.isArchived AS isArchived,"
        " chat.displayName AS displayName"
        " FROM chat"
        " JOIN chat_message_join AS cmj ON chat.ROWID = cmj.chatId"
        " JOIN message ON message.ROWID = cmj.messageId"
        " WHERE message.ROWID = ?;",
        [message.id]);

    return (res.isNotEmpty) ? Chat.fromMap(res[0]) : null;
  }

  Future<List<Message>> getReactions() async {
    List<Message> res =
        await Message.find({"associatedMessageGuid": this.guid});
    res.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    List<int> alreadyTrackedHandleIds = [];
    Map<int, Message> reactions = new Map();
    for (Message reaction in res) {
      if (!reactions.containsKey(reaction.handleId) &&
          !alreadyTrackedHandleIds.contains(reaction.handleId) &&
          !reaction.associatedMessageType.startsWith("-")) {
        reactions[reaction.handleId] = reaction;
      }
      alreadyTrackedHandleIds.add(reaction.handleId);
    }
    return reactions.values.toList();
  }

  Future<Handle> getHandle() async {
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

    this.handle =
        (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList()[0] : null;
    return this.handle;
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

  static Future<void> delete(Map<String, dynamic> where) async {
    final Database db = await DBProvider.db.database;

    List<String> whereParams = [];
    where.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    where.values.forEach((filter) => whereArgs.add(filter));

    List<Message> toDelete = await Message.find(where);
    for (Message msg in toDelete) {
      await db.delete("chat_message_join", where: "messageId = ?", whereArgs: [msg.id]);
      await db.delete("message", where: "ROWID = ?", whereArgs: [msg.id]);
    }
  }

  static flush() async {
    final Database db = await DBProvider.db.database;
    await db.delete("message");
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "handleId": handleId,
        "text": sanitizeString(text),
        "subject": subject,
        "country": country,
        "error": error,
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
        "groupActionType": groupActionType,
        "isExpired": isExpired ? 1 : 0,
        "associatedMessageGuid": associatedMessageGuid,
        "associatedMessageType": associatedMessageType,
        "expressiveSendStyleId": expressiveSendStyleId,
        "timeExpressiveSendStyleId": (timeExpressiveSendStyleId == null)
            ? null
            : timeExpressiveSendStyleId.millisecondsSinceEpoch,
        "handle": (handle != null) ? handle.toMap() : null,
        "hasAttachments": hasAttachments ? 1 : 0,
        "hasReactions": hasReactions ? 1 : 0
      };
}
