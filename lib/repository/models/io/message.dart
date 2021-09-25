import 'dart:async';
import 'dart:convert';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/attachment.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'chat.dart';
import 'handle.dart';

@Entity()
class Message {
  int? id;
  int? originalROWID;
  @Unique()
  String? guid;
  int? handleId;
  int? otherHandle;
  String? text;
  String? subject;
  String? country;
  final RxInt _error = RxInt(0);
  int get error => _error.value;
  set error(int i) => _error.value = i;
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
  List<Attachment?>? attachments = [];
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
      this.metadata}) {
    if (error2 != null) _error.value = error2;
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
      error2: json.containsKey("_error") ? json["_error"] : 0,
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
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  Message save() {
   if (kIsWeb) return this;
    Message? existing = Message.findOne(guid: guid);
    if (existing != null) {
      id = existing.id;
    }

    // Save the participant & set the handle ID to the new participant
    if (handle != null) {
      handle!.save();
      handleId = handle!.id;
    }
    if (associatedMessageType != null && associatedMessageGuid != null) {
      Message? associatedMessage = Message.findOne(guid: associatedMessageGuid);
      if (associatedMessage != null) {
        associatedMessage.hasReactions = true;
        associatedMessage.save();
      }
    } else if (!hasReactions) {
      Message? reaction = Message.findOne(associatedMessageGuid: guid);
      if (reaction != null) {
        hasReactions = true;
      }
    }

    try {
      messageBox.put(this);
    } on UniqueViolationException catch (_) {}

    return this;
  }

  static Future<Message?> replaceMessage(String? oldGuid, Message? newMessage,
      {bool awaitNewMessageEvent = true, Chat? chat}) async {
    Message? existing = Message.findOne(guid: oldGuid);

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

    newMessage!.id = existing.id;
    messageBox.put(newMessage);

    return newMessage;
  }

  Message updateMetadata(Metadata? metadata) {
    if (kIsWeb || id == null) return this;
    this.metadata = metadata!.toJson();
    save();
    return this;
  }

  List<Attachment?>? fetchAttachments({CurrentChat? currentChat}) {
    if (kIsWeb || (hasAttachments && this.attachments != null && this.attachments!.isNotEmpty)) {
      return this.attachments;
    }

    if (currentChat != null) {
      this.attachments = currentChat.getAttachmentsForMessage(this);
      if (this.attachments == null) this.attachments = [];
      if (this.attachments!.isNotEmpty) return this.attachments;
    }

    if (id == null) return [];
    final attachmentIds = amJoinBox.getAll().where((element) => element.messageId == id!).map((e) => e.attachmentId).toList();
    final attachments = attachmentBox.getMany(attachmentIds, growableResult: true);
    this.attachments = attachments;
    return attachments;
  }

  static Chat? getChat(Message message) {
    if (kIsWeb) return null;
    final chatId = cmJoinBox.getAll().firstWhere((element) => element.messageId == message.id).chatId;
    return chatBox.get(chatId);
  }

  Message fetchAssociatedMessages({MessageBloc? bloc}) {
    if (associatedMessages.isNotEmpty &&
        associatedMessages.length == 1 &&
        associatedMessages[0].guid == guid) {
      return this;
    }
    if (kIsWeb) {
      associatedMessages = bloc?.reactionMessages.values.where((element) => element.associatedMessageGuid == guid).toList() ?? [];
    } else {
      associatedMessages = Message.find().where((element) => element.associatedMessageGuid == guid).toList();
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    if (!kIsWeb) associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    return this;
  }

  Handle? getHandle() {
    if (kIsWeb) return null;
    handle = handleBox.get(handleId!);
    return handleBox.get(handleId!);
  }

  static Message? findOne({String? guid, String? associatedMessageGuid}) {
    if (kIsWeb) return null;
    if (guid != null) {
      final query = messageBox.query(Message_.guid.equals(guid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (associatedMessageGuid != null) {
      final query = messageBox.query(Message_.associatedMessageGuid.equals(associatedMessageGuid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static DateTime? lastMessageDate() {
    if (kIsWeb) return null;
    final query = (messageBox.query()..order(Message_.dateCreated, flags: Order.descending)).build();
    query.limit = 1;
    final messages = query.find();
    query.close();
    return messages.isEmpty ? null : messages.first.dateCreated;
  }

  static List<Message> find() {
    return messageBox.getAll();
  }

  static void delete(String guid) {
    if (kIsWeb) return;
    final query = messageBox.query(Message_.guid.equals(guid)).build();
    final results = query.find();
    final ids = results.map((e) => e.id!).toList();
    query.close();
    final query2 = cmJoinBox.query(ChatMessageJoin_.messageId.oneOf(ids)).build();
    final results2 = query2.find();
    query2.close();
    cmJoinBox.removeMany(results2.map((e) => e.id!).toList());
    messageBox.removeMany(ids);
  }

  static void softDelete(String guid) {
    if (kIsWeb) return;
    Message? toDelete = Message.findOne(guid: guid);
    toDelete?.dateDeleted = DateTime.now().toUtc();
    toDelete?.save();
  }

  static void flush() {
    if (kIsWeb) return;
    messageBox.removeAll();
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
    return attachments!.where((item) => item!.mimeType != null).toList();
  }

  List<Attachment?> getPreviewAttachments() {
    return attachments!.where((item) => item!.mimeType == null).toList();
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

  static int? countForChat(Chat? chat) {
    if (kIsWeb || chat == null || chat.id == null) return 0;
    return cmJoinBox.getAll().where((element) => element.chatId == chat.id).length;
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
    if (_error.value == 0 && otherMessage._error.value != 0) {
      _error.value = otherMessage._error.value;
    }
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
        "_error": _error.value,
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
      };
}
