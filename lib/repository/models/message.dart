import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:sqflite/sqflite.dart';
import '../../helpers/utils.dart';

import '../database.dart';
import 'chat.dart';
import 'handle.dart';

Message messageFromJson(String str) {
  final jsonData = json.decode(str);
  return Message.fromMap(jsonData);
}

String messageToJson(Message data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

enum LineType {meToMe, otherToMe, meToOther, otherToOther}

class Message {
  int? id;
  int? originalROWID;
  String? guid;
  int? handleId;
  int? otherHandle;
  String? text;
  String? subject;
  String? country;
  final RxInt error = RxInt(0);
  DateTime? dateCreated;
  DateTime? dateRead;
  DateTime? dateDelivered;
  bool? isFromMe;
  bool? isDelayed;
  bool? isAutoReply;
  bool? isSystemMessage;
  bool? isServiceMessage;
  bool? isForward;
  bool? isArchived;
  bool? hasDdResults;
  String? cacheRoomnames;
  bool? isAudioMessage;
  DateTime? datePlayed;
  int? itemType;
  String? groupTitle;
  int? groupActionType;
  bool? isExpired;
  String? balloonBundleId;
  String? associatedMessageGuid;
  String? associatedMessageType;
  String? expressiveSendStyleId;
  DateTime? timeExpressiveSendStyleId;
  Handle? handle;
  bool hasAttachments;
  bool hasReactions;
  DateTime? dateDeleted;
  Map<String, dynamic>? metadata;
  String? threadOriginatorGuid;
  String? threadOriginatorPart;

  List<Attachment?> attachments = [];
  List<Message> associatedMessages = [];
  bool? bigEmoji;

  Message(
      {this.id,
      this.originalROWID,
      this.guid,
      this.handleId,
      this.otherHandle,
      this.text,
      this.subject,
      this.country,
      int? error2,
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
      this.hasDdResults = false,
      this.cacheRoomnames,
      this.isAudioMessage = false,
      this.datePlayed,
      this.itemType = 0,
      this.groupTitle,
      this.groupActionType = 0,
      this.isExpired = false,
      this.balloonBundleId,
      this.associatedMessageGuid,
      this.associatedMessageType,
      this.expressiveSendStyleId,
      this.timeExpressiveSendStyleId,
      this.handle,
      this.hasAttachments = false,
      this.hasReactions = false,
      this.attachments = const [],
      this.associatedMessages = const [],
      this.dateDeleted,
      this.metadata,
      this.threadOriginatorGuid,
      this.threadOriginatorPart}) {
    if (error2 != null) error.value = error2;
  }

  String get fullText {
    String fullText = subject ?? "";
    if (fullText.isNotEmpty) {
      fullText += "\n";
    }

    fullText += text ?? "";

    return sanitizeString(fullText);
  }

  factory Message.fromMap(Map<String, dynamic> json) {
    bool hasAttachments = false;
    if (json.containsKey("hasAttachments")) {
      hasAttachments = json["hasAttachments"] == 1 ? true : false;
    } else if (json.containsKey("attachments")) {
      hasAttachments = (json['attachments'] as List).isNotEmpty ? true : false;
    }

    List<Attachment> attachments =
        json.containsKey("attachments") ? (json['attachments'] as List).map((a) => Attachment.fromMap(a)).toList() : [];

    // Load the metadata
    dynamic metadata = json.containsKey("metadata") ? json["metadata"] : null;
    if (!isNullOrEmpty(metadata)!) {
      // If the metadata is a string, convert it to JSON
      if (metadata is String) {
        try {
          metadata = jsonDecode(metadata);
        } catch (_) {}
      }
    }

    String? associatedMessageGuid;
    if (json.containsKey("associatedMessageGuid") && json["associatedMessageGuid"] != null) {
      if ((json["associatedMessageGuid"] as String).contains("/")) {
        associatedMessageGuid = (json["associatedMessageGuid"] as String).split("/").last;
      } else {
        associatedMessageGuid = (json["associatedMessageGuid"] as String).split(":").last;
      }
    }

    var data = Message(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      handleId: (json["handleId"] != null) ? json["handleId"] : 0,
      otherHandle: (json["otherHandle"] != null) ? json["otherHandle"] : null,
      text: sanitizeString(json["text"]),
      subject: json.containsKey("subject") ? json["subject"] : null,
      country: json.containsKey("country") ? json["country"] : null,
      error2: json.containsKey("error") ? json["error"] : 0,
      dateCreated: json.containsKey("dateCreated") ? parseDate(json["dateCreated"]) : null,
      dateRead: json.containsKey("dateRead") ? parseDate(json["dateRead"]) : null,
      dateDelivered: json.containsKey("dateDelivered") ? parseDate(json["dateDelivered"]) : null,
      isFromMe: (json["isFromMe"] is bool) ? json['isFromMe'] : ((json['isFromMe'] == 1) ? true : false),
      isDelayed: (json["isDelayed"] is bool) ? json['isDelayed'] : ((json['isDelayed'] == 1) ? true : false),
      isAutoReply: (json["isAutoReply"] is bool) ? json['isAutoReply'] : ((json['isAutoReply'] == 1) ? true : false),
      isSystemMessage:
          (json["isSystemMessage"] is bool) ? json['isSystemMessage'] : ((json['isSystemMessage'] == 1) ? true : false),
      isServiceMessage: (json["isServiceMessage"] is bool)
          ? json['isServiceMessage']
          : ((json['isServiceMessage'] == 1) ? true : false),
      isForward: (json["isForward"] is bool) ? json['isForward'] : ((json['isForward'] == 1) ? true : false),
      isArchived: (json["isArchived"] is bool) ? json['isArchived'] : ((json['isArchived'] == 1) ? true : false),
      hasDdResults:
          (json["hasDdResults"] is bool) ? json['hasDdResults'] : ((json['hasDdResults'] == 1) ? true : false),
      cacheRoomnames: json.containsKey("cacheRoomnames") ? json["cacheRoomnames"] : null,
      isAudioMessage:
          (json["isAudioMessage"] is bool) ? json['isAudioMessage'] : ((json['isAudioMessage'] == 1) ? true : false),
      datePlayed: json.containsKey("datePlayed") ? parseDate(json["datePlayed"]) : null,
      itemType: json.containsKey("itemType") ? json["itemType"] : null,
      groupTitle: json.containsKey("groupTitle") ? json["groupTitle"] : null,
      groupActionType: (json["groupActionType"] != null) ? json["groupActionType"] : 0,
      isExpired: (json["isExpired"] is bool) ? json['isExpired'] : ((json['isExpired'] == 1) ? true : false),
      balloonBundleId: json.containsKey("balloonBundleId") ? json["balloonBundleId"] : null,
      associatedMessageGuid: associatedMessageGuid,
      associatedMessageType: json.containsKey("associatedMessageType") ? json["associatedMessageType"] : null,
      expressiveSendStyleId: json.containsKey("expressiveSendStyleId") ? json["expressiveSendStyleId"] : null,
      timeExpressiveSendStyleId: json.containsKey("timeExpressiveSendStyleId")
          ? DateTime.tryParse(json["timeExpressiveSendStyleId"].toString())?.toLocal()
          : null,
      handle: json.containsKey("handle") ? (json['handle'] != null ? Handle.fromMap(json['handle']) : null) : null,
      hasAttachments: hasAttachments,
      attachments: attachments,
      hasReactions: json.containsKey('hasReactions') ? ((json['hasReactions'] == 1) ? true : false) : false,
      dateDeleted: json.containsKey("dateDeleted") ? parseDate(json["dateDeleted"]) : null,
      metadata: metadata is String ? null : metadata,
      threadOriginatorGuid: json['threadOriginatorGuid'],
      threadOriginatorPart: json['threadOriginatorPart'],
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  Future<Message> save([bool updateIfAbsent = true]) async {
    final Database? db = await DBProvider.db.database;
    // Try to find an existing chat before saving it
    Message? existing = await Message.findOne({"guid": guid});
    if (existing != null) {
      id = existing.id;
    }

    // Save the participant & set the handle ID to the new participant
    if (handle != null) {
      await handle!.save();
      handleId = handle!.id;
    }
    if (associatedMessageType != null && associatedMessageGuid != null) {
      Message? associatedMessage = await Message.findOne({"guid": associatedMessageGuid});
      if (associatedMessage != null) {
        associatedMessage.hasReactions = true;
        await associatedMessage.save();
      }
    } else if (!hasReactions) {
      Message? reaction = await Message.findOne({"associatedMessageGuid": guid});
      if (reaction != null) {
        hasReactions = true;
      }
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      handleId ??= 0;
      var map = toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }
      if (map.containsKey("handle")) {
        map.remove("handle");
      }

      id = await db?.insert("message", map);
    } else if (updateIfAbsent) {
      await update();
    }

    return this;
  }

  static Future<Message?> replaceMessage(String? oldGuid, Message? newMessage,
      {bool awaitNewMessageEvent = true, Chat? chat}) async {
    final Database? db = await DBProvider.db.database;
    Message? existing = await Message.findOne({"guid": oldGuid});

    if (existing == null) {
      if (awaitNewMessageEvent) {
        await Future.delayed(Duration(milliseconds: 500));
        return replaceMessage(oldGuid, newMessage, awaitNewMessageEvent: false, chat: chat);
      } else {
        if (chat != null) {
          await chat.addMessage(newMessage!);
          NewMessageManager().addMessage(chat, newMessage, outgoing: false);
          return newMessage;
        }
      }

      return newMessage;
    }

    Map<String, dynamic> params = newMessage!.toMap();
    if (params.containsKey("ROWID")) {
      params.remove("ROWID");
    }
    if (params.containsKey("handle")) {
      params.remove("handle");
    }

    var theMap = existing.toMap();
    if (theMap.containsKey("handleId")) {
      params["handleId"] = theMap["handleId"];
      newMessage.handleId = existing.handleId;
    }
    if (existing.hasAttachments) {
      params["hasAttachments"] = existing.hasAttachments ? 1 : 0;
      newMessage.hasAttachments = existing.hasAttachments;
    }
    if (theMap.containsKey("hasReactions")) {
      params["hasReactions"] = theMap["hasReactions"];
      newMessage.hasReactions = existing.hasReactions;
    }
    if (theMap.containsKey("metadata")) {
      params["metadata"] = theMap["metadata"];
      newMessage.metadata = existing.metadata;
    }

    await db?.update("message", params, where: "ROWID = ?", whereArgs: [existing.id]);

    return newMessage;
  }

  Future<Message> updateMetadata(Metadata? metadata) async {
    final Database? db = await DBProvider.db.database;
    if (id == null) return this;
    this.metadata = metadata!.toJson();

    await db?.update("message", {"metadata": isNullOrEmpty(this.metadata)! ? null : jsonEncode(this.metadata)},
        where: "ROWID = ?", whereArgs: [id]);

    return this;
  }

  Future<Message> update() async {
    final Database? db = await DBProvider.db.database;

    Map<String, dynamic> params = {
      "dateCreated": (dateCreated == null) ? null : dateCreated!.millisecondsSinceEpoch,
      "dateRead": (dateRead == null) ? null : dateRead!.millisecondsSinceEpoch,
      "dateDelivered": (dateDelivered == null) ? null : dateDelivered!.millisecondsSinceEpoch,
      "isArchived": isArchived! ? 1 : 0,
      "datePlayed": (datePlayed == null) ? null : datePlayed!.millisecondsSinceEpoch,
      "error": error.value,
      "hasReactions": hasReactions ? 1 : 0,
      "hasDdResults": hasDdResults! ? 1 : 0,
      "metadata": isNullOrEmpty(metadata)! ? null : jsonEncode(metadata)
    };

    if (originalROWID != null) {
      params["originalROWID"] = originalROWID;
    }

    // If it already exists, update it
    if (id != null) {
      await db?.update("message", params, where: "ROWID = ?", whereArgs: [id]);
    } else {
      await save(false);
    }

    return this;
  }

  Future<List<Attachment?>?> fetchAttachments({CurrentChat? currentChat}) async {
    if (hasAttachments && attachments.isNotEmpty) {
      return attachments;
    }

    if (currentChat != null) {
      attachments = currentChat.getAttachmentsForMessage(this);
      if (attachments.isNotEmpty) return attachments;
    }

    final Database? db = await DBProvider.db.database;
    if (db == null) return [];
    if (id == null) return [];

    var res = await db.rawQuery(
        "SELECT"
        " attachment.ROWID AS ROWID,"
        " attachment.originalROWID AS originalROWID,"
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
        " attachment.metadata AS metadata,"
        " attachment.width AS width,"
        " attachment.height AS height"
        " FROM message"
        " JOIN attachment_message_join AS amj ON message.ROWID = amj.messageId"
        " JOIN attachment ON attachment.ROWID = amj.attachmentId"
        " WHERE message.ROWID = ?;",
        [id]);

    attachments = (res.isNotEmpty) ? res.map((c) => Attachment.fromMap(c)).toList() : [];

    return attachments;
  }

  static Future<Chat?> getChat(Message message) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    var res = await db.rawQuery(
        "SELECT"
        " chat.ROWID AS ROWID,"
        " chat.originalROWID AS originalROWID,"
        " chat.guid AS guid,"
        " chat.style AS style,"
        " chat.chatIdentifier AS chatIdentifier,"
        " chat.isArchived AS isArchived,"
        " chat.displayName AS displayName,"
        " chat.customAvatarPath AS customAvatarPath,"
        " chat.pinIndex AS pinIndex"
        " FROM chat"
        " JOIN chat_message_join AS cmj ON chat.ROWID = cmj.chatId"
        " JOIN message ON message.ROWID = cmj.messageId"
        " WHERE message.ROWID = ?;",
        [message.id]);

    return (res.isNotEmpty) ? Chat.fromMap(res[0]) : null;
  }

  Future<Message> fetchAssociatedMessages({MessageBloc? bloc}) async {
    if (associatedMessages.isNotEmpty &&
        associatedMessages.length == 1 &&
        associatedMessages[0].guid == guid) {
      return this;
    }
    if (kIsWeb) {
      associatedMessages = bloc?.reactionMessages.values.where((element) => element.associatedMessageGuid == guid).toList() ?? [];
      if (threadOriginatorGuid != null) {
        final existing = bloc?.messages.values.firstWhereOrNull((e) => e.guid == threadOriginatorGuid);
        final threadOriginator = existing ?? await Message.findOne({"guid": threadOriginatorGuid});
        threadOriginator?.handle ??= await Handle.findOne({"ROWID": threadOriginator.handleId});
        if (threadOriginator != null) associatedMessages.add(threadOriginator);
        if (existing == null && threadOriginator != null) bloc?.addMessage(threadOriginator);
        if (!guid!.startsWith("temp")) bloc?.threadOriginators[guid!] = threadOriginatorGuid!;
      }
    } else {
      associatedMessages = await Message.find({"associatedMessageGuid": guid});
      if (threadOriginatorGuid != null) {
        final existing = bloc?.messages.values.firstWhereOrNull((e) => e.guid == threadOriginatorGuid);
        final threadOriginator = existing ?? await Message.findOne({"guid": threadOriginatorGuid});
        threadOriginator?.handle ??= await Handle.findOne({"ROWID": threadOriginator.handleId});
        if (threadOriginator != null) associatedMessages.add(threadOriginator);
        if (existing == null && threadOriginator != null) bloc?.addMessage(threadOriginator);
        if (!guid!.startsWith("temp")) bloc?.threadOriginators[guid!] = threadOriginatorGuid!;
      }
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    if (!kIsWeb) associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    return this;
  }

  Future<Handle?> getHandle() async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    var res = await db.rawQuery(
        "SELECT"
        " handle.ROWID AS ROWID,"
        " handle.originalROWID AS originalROWID,"
        " handle.address AS address,"
        " handle.country AS country,"
        " handle.color AS color,"
        " handle.defaultPhone AS defaultPhone,"
        " handle.uncanonicalizedId AS uncanonicalizedId"
        " FROM handle"
        " JOIN message ON message.handleId = handle.ROWID"
        " WHERE message.ROWID = ?;",
        [id]);

    handle = (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList()[0] : null;
    return handle;
  }

  static Future<Message?> findOne(Map<String, dynamic> filters) async {
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
    var res = await db.query("message", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Message.fromMap(res.elementAt(0));
  }

  static Future<DateTime?> lastMessageDate() async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    // Get the last message
    var res = await db.query("message", limit: 1, orderBy: "dateCreated DESC");
    return (res.isNotEmpty) ? res.map((c) => Message.fromMap(c)).toList()[0].dateCreated : null;
  }

  static Future<List<Message>> find([Map<String, dynamic> filters = const {}]) async {
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

    var res = await db.query("message",
        where: (whereParams.isNotEmpty) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.isNotEmpty) ? whereArgs : null);
    return (res.isNotEmpty) ? res.map((c) => Message.fromMap(c)).toList() : [];
  }

  static Future<void> delete(Map<String, dynamic> where) async {
    final Database? db = await DBProvider.db.database;

    List<String> whereParams = [];
    for (var filter in where.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in where.values) {
      whereArgs.add(filter);
    }

    List<Message> toDelete = await Message.find(where);
    for (Message msg in toDelete) {
      await db?.delete("chat_message_join", where: "messageId = ?", whereArgs: [msg.id]);
      await db?.delete("message", where: "ROWID = ?", whereArgs: [msg.id]);
    }
  }

  static Future<void> softDelete(Map<String, dynamic> where) async {
    final Database? db = await DBProvider.db.database;

    List<String> whereParams = [];
    for (var filter in where.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in where.values) {
      whereArgs.add(filter);
    }

    List<Message> toDelete = await Message.find(where);
    for (Message msg in toDelete) {
      await db?.update("message", {'dateDeleted': DateTime.now().toUtc().millisecondsSinceEpoch},
          where: "ROWID = ?", whereArgs: [msg.id]);
    }
  }

  static flush() async {
    final Database? db = await DBProvider.db.database;
    await db?.delete("message");
  }

  bool isUrlPreview() {
    // first condition is for macOS < 11 and second condition is for macOS >= 11
    return (balloonBundleId != null &&
            balloonBundleId == "com.apple.messages.URLBalloonProvider" &&
            hasDdResults!) ||
        (hasDdResults! && (text ?? "").replaceAll("\n", " ").hasUrl);
  }

  String? getUrl() {
    if (text == null) return null;
    List<String> splits = text!.replaceAll("\n", " ").split(" ");
    return splits.firstWhereOrNull((String element) => element.hasUrl);
  }

  bool isInteractive() {
    return balloonBundleId != null && balloonBundleId != "com.apple.messages.URLBalloonProvider";
  }

  bool hasText({stripWhitespace = false}) {
    return !isEmptyString(fullText, stripWhitespace: stripWhitespace);
  }

  bool isGroupEvent() {
    return isEmptyString(fullText) && !hasAttachments && balloonBundleId == null;
  }

  bool isBigEmoji() {
    // We are checking the variable first because we want to
    // avoid processing twice for this as it won't change
    bigEmoji ??= MessageHelper.shouldShowBigEmoji(fullText);

    return bigEmoji!;
  }

  List<Attachment?> getRealAttachments() {
    return attachments.where((item) => item!.mimeType != null).toList();
  }

  List<Attachment?> getPreviewAttachments() {
    return attachments.where((item) => item!.mimeType == null).toList();
  }

  List<Message> getReactions() {
    return associatedMessages
        .where((item) => ReactionTypes.toList().contains(item.associatedMessageType))
        .toList();
  }

  void generateTempGuid() {
    List<String> unique = [text ?? "", dateCreated?.millisecondsSinceEpoch.toString() ?? ""];

    String preHashed;
    if (unique.every((element) => element.trim().isEmpty)) {
      preHashed = randomString(8);
    } else {
      preHashed = unique.join(":");
    }

    String hashed = crypto.sha1.convert(utf8.encode(preHashed)).toString();
    guid = "temp-$hashed";
  }

  static Future<int?> countForChat(Chat? chat) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return 0;
    if (chat == null || chat.id == null) return 0;

    String query = ("SELECT"
        " count(message.ROWID) AS count"
        " FROM message"
        " JOIN chat_message_join AS cmj ON cmj.messageId = message.ROWID"
        " JOIN chat ON chat.ROWID = cmj.chatId"
        " WHERE chat.ROWID = ?");

    // Execute the query
    var res = await db.rawQuery("$query;", [chat.id]);
    if (res.isEmpty) return 0;

    return res[0]["count"] as int?;
  }

  void merge(Message otherMessage) {
    if (dateCreated == null && otherMessage.dateCreated != null) {
      dateCreated = otherMessage.dateCreated;
    }
    if (dateDelivered == null && otherMessage.dateDelivered != null) {
      dateDelivered = otherMessage.dateDelivered;
    }
    if (dateRead == null && otherMessage.dateRead != null) {
      dateRead = otherMessage.dateRead;
    }
    if (dateDeleted == null && otherMessage.dateDeleted != null) {
      dateDeleted = otherMessage.dateDeleted;
    }
    if (datePlayed == null && otherMessage.datePlayed != null) {
      datePlayed = otherMessage.datePlayed;
    }
    if (metadata == null && otherMessage.metadata != null) {
      metadata = otherMessage.metadata;
    }
    if (originalROWID == null && otherMessage.originalROWID != null) {
      originalROWID = otherMessage.originalROWID;
    }
    if (!hasAttachments && otherMessage.hasAttachments) {
      hasAttachments = otherMessage.hasAttachments;
    }
    if (!hasReactions && otherMessage.hasReactions) {
      hasReactions = otherMessage.hasReactions;
    }
    if (error.value == 0 && otherMessage.error.value != 0) {
      error.value = otherMessage.error.value;
    }
  }

  /// Get what shape the reply line should be
  LineType getLineType(Message? olderMessage, Message threadOriginator) {
    if (olderMessage?.threadOriginatorGuid != threadOriginatorGuid) olderMessage = threadOriginator;
    if (isFromMe! && (olderMessage?.isFromMe ?? false)) {
      return LineType.meToMe;
    } else if (!isFromMe! && (olderMessage?.isFromMe ?? false)) {
      return LineType.meToOther;
    } else if (isFromMe! && !(olderMessage?.isFromMe ?? false)) {
      return LineType.otherToMe;
    } else {
      return LineType.otherToOther;
    }
  }

  /// Get whether the reply line from the message should connect to the message below
  bool shouldConnectLower(Message? olderMessage, Message? newerMessage, Message threadOriginator) {
    // if theres no newer message or it isn't part of the thread, don't connect
    if (newerMessage == null || newerMessage.threadOriginatorGuid != threadOriginatorGuid) return false;
    // if the line is from me to other or from other to other, don't connect lower.
    // we only want lines ending at messages to me to connect downwards (this
    // helps simplify some things and prevent rendering mistakes)
    if (getLineType(olderMessage, threadOriginator) == LineType.meToOther || getLineType(olderMessage, threadOriginator) == LineType.otherToOther) return false;
    // if the lower message isn't from me, then draw the connecting line
    // (if the message is from me, that message will draw a connecting line up
    // rather than this message drawing one downwards).
    return isFromMe != newerMessage.isFromMe;
  }

  /// Get whether the reply line from the message should connect to the message above
  bool shouldConnectUpper(Message? olderMessage, Message threadOriginator) {
    // if theres no older message, or it isn't a part of the thread (make sure
    // to check that it isn't actually an outlined bubble representing the
    // thread originator), don't connect
    if (olderMessage == null || (olderMessage.threadOriginatorGuid != threadOriginatorGuid && !upperIsThreadOriginatorBubble(olderMessage))) return false;
    // if the older message is the outlined bubble, or the originator is from
    // someone else and the message is from me, then draw the connecting line
    // (the second condition might be redundant / unnecessary but I left it in
    // just in case)
    if (upperIsThreadOriginatorBubble(olderMessage) || (!threadOriginator.isFromMe! && isFromMe!) || getLineType(olderMessage, threadOriginator) == LineType.meToMe  || getLineType(olderMessage, threadOriginator) == LineType.otherToMe) return true;
    // if the upper message is from me, then draw the connecting line
    // (if the message is not from me, that message will draw a connecting line
    // down rather than this message drawing one upwards).
    return isFromMe == olderMessage.isFromMe;
  }

  /// Get whether the upper bubble is actually the thread originator as the
  /// outlined bubble
  bool upperIsThreadOriginatorBubble(Message? olderMessage) {
    return olderMessage?.threadOriginatorGuid != threadOriginatorGuid;
  }

  /// Calculate the size of the message bubble by calculating text size or
  /// attachment size
  Size getBubbleSize(BuildContext context, {double? maxWidthOverride, double? minHeightOverride, String? textOverride}) {
    // cache this value because the calculation can be expensive
    if (ChatBloc().cachedMessageBubbleSizes[guid!] != null) return ChatBloc().cachedMessageBubbleSizes[guid!]!;
    // if attachment, then grab width / height
    if (fullText.isEmpty && attachments.isNotEmpty) {
      return Size(attachments
          .map((e) => e!.width)
          .fold(0, (p, e) => max(p, (e ?? CustomNavigator.width(context) / 2).toDouble()) + 28),
        attachments
          .map((e) => e!.height)
          .fold(0, (p, e) => max(p, (e ?? CustomNavigator.width(context) / 2).toDouble())));
    }
    // initialize constraints for text rendering
    final constraints = BoxConstraints(
      maxWidth: maxWidthOverride ?? CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE - 30,
      minHeight: minHeightOverride ?? Theme.of(context).textTheme.bodyText2!.fontSize!,
    );
    final renderParagraph = RichText(
      text: TextSpan(
        text: textOverride ?? fullText,
        style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
      ),
    ).createRenderObject(context);
    // get the text size
    Size size = renderParagraph.getDryLayout(constraints);
    // if the text is shorter than the full width, add 28 to account for the
    // container margins
    if (size.height < Theme.of(context).textTheme.bodyText2!.fontSize! * 2
        || (subject != null && size.height < Theme.of(context).textTheme.bodyText2!.fontSize! * 3)) {
      size = Size(size.width + 28, size.height);
    }
    // if we have a URL preview, extend to the full width
    if (isUrlPreview()) {
      size = Size(CustomNavigator.width(context) * 2 / 3 - 30, size.height);
    }
    // if we have reactions, account for the extra height they add
    if (hasReactions) {
      size = Size(size.width, size.height + 25);
    }
    // add 16 to the height to account for container margins
    size = Size(size.width, size.height + 16);
    // cache the value
    ChatBloc().cachedMessageBubbleSizes[guid!] = size;
    return size;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "handleId": handleId,
        "otherHandle": otherHandle,
        "text": sanitizeString(text),
        "subject": subject,
        "country": country,
        "error": error.value,
        "dateCreated": (dateCreated == null) ? null : dateCreated!.millisecondsSinceEpoch,
        "dateRead": (dateRead == null) ? null : dateRead!.millisecondsSinceEpoch,
        "dateDelivered": (dateDelivered == null) ? null : dateDelivered!.millisecondsSinceEpoch,
        "isFromMe": isFromMe! ? 1 : 0,
        "isDelayed": isDelayed! ? 1 : 0,
        "isAutoReply": isAutoReply! ? 1 : 0,
        "isSystemMessage": isSystemMessage! ? 1 : 0,
        "isServiceMessage": isServiceMessage! ? 1 : 0,
        "isForward": isForward! ? 1 : 0,
        "isArchived": isArchived! ? 1 : 0,
        "hasDdResults": hasDdResults! ? 1 : 0,
        "cacheRoomnames": cacheRoomnames,
        "isAudioMessage": isAudioMessage! ? 1 : 0,
        "datePlayed": (datePlayed == null) ? null : datePlayed!.millisecondsSinceEpoch,
        "itemType": itemType,
        "groupTitle": groupTitle,
        "groupActionType": groupActionType,
        "isExpired": isExpired! ? 1 : 0,
        "balloonBundleId": balloonBundleId,
        "associatedMessageGuid": associatedMessageGuid,
        "associatedMessageType": associatedMessageType,
        "expressiveSendStyleId": expressiveSendStyleId,
        "timeExpressiveSendStyleId":
            (timeExpressiveSendStyleId == null) ? null : timeExpressiveSendStyleId!.millisecondsSinceEpoch,
        "handle": (handle != null) ? handle!.toMap() : null,
        "hasAttachments": hasAttachments ? 1 : 0,
        "hasReactions": hasReactions ? 1 : 0,
        "dateDeleted": (dateDeleted == null) ? null : dateDeleted!.millisecondsSinceEpoch,
        "metadata": jsonEncode(metadata),
        "threadOriginatorGuid": threadOriginatorGuid,
        "threadOriginatorPart": threadOriginatorPart,
      };
}
