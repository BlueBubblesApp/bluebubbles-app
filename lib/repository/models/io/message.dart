import 'dart:async';
import 'dart:convert';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/attachment.dart';
import 'package:collection/src/iterable_extensions.dart';
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
    String fullText = this.subject ?? "";
    if (fullText.isNotEmpty) {
      fullText += "\n";
    }

    fullText += this.text ?? "";

    return sanitizeString(fullText);
  }

  factory Message.fromMap(Map<String, dynamic> json) {
    bool hasAttachments = false;
    if (json.containsKey("hasAttachments")) {
      hasAttachments = json["hasAttachments"] == 1 ? true : false;
    } else if (json.containsKey("attachments")) {
      hasAttachments = (json['attachments'] as List).length > 0 ? true : false;
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
        } catch (ex) {}
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

    var data = new Message(
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
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Message save() {
   if (kIsWeb) return this;
    Message? existing = Message.findOne(guid: this.guid);
    if (existing != null) {
      this.id = existing.id;
    }

    // Save the participant & set the handle ID to the new participant
    if (this.handle != null) {
      this.handle!.save();
      this.handleId = this.handle!.id;
    }
    if (this.associatedMessageType != null && this.associatedMessageGuid != null) {
      Message? associatedMessage = Message.findOne(guid: this.associatedMessageGuid);
      if (associatedMessage != null) {
        associatedMessage.hasReactions = true;
        associatedMessage.save();
      }
    } else if (!this.hasReactions) {
      Message? reaction = Message.findOne(associatedMessageGuid: this.guid);
      if (reaction != null) {
        this.hasReactions = true;
      }
    }

    try {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
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
          // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
          NewMessageManager().addMessage(chat, newMessage, outgoing: false);
          return newMessage;
        }
      }

      return newMessage;
    }

    newMessage!.id = existing.id;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    messageBox.put(newMessage);

    return newMessage;
  }

  Message updateMetadata(Metadata? metadata) {
    if (kIsWeb || this.id == null) return this;
    this.metadata = metadata!.toJson();
    this.save();
    return this;
  }

  List<Attachment?>? fetchAttachments({CurrentChat? currentChat}) {
    if (kIsWeb || (this.hasAttachments && this.attachments != null && this.attachments!.length != 0)) {
      return this.attachments;
    }

    if (currentChat != null) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      this.attachments = currentChat.getAttachmentsForMessage(this);
      if (this.attachments == null) this.attachments = [];
      if (this.attachments!.length != 0) return this.attachments;
    }

    if (this.id == null) return [];
    final attachmentIds = amJoinBox.getAll().where((element) => element.messageId == this.id!).map((e) => e.attachmentId).toList();
    final attachments = attachmentBox.getMany(attachmentIds, growableResult: true);
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    this.attachments = attachments;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return attachments;
  }

  static Chat? getChat(Message message) {
    if (kIsWeb) return null;
    final chatId = cmJoinBox.getAll().firstWhere((element) => element.messageId == message.id).chatId;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return chatBox.get(chatId);
  }

  Message fetchAssociatedMessages({MessageBloc? bloc}) {
    if (this.associatedMessages.isNotEmpty &&
        this.associatedMessages.length == 1 &&
        this.associatedMessages[0].guid == this.guid) {
      return this;
    }
    if (kIsWeb) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      associatedMessages = bloc?.reactionMessages.values.where((element) => element.associatedMessageGuid == guid).toList() ?? [];
    } else {
      associatedMessages = Message.find().where((element) => element.associatedMessageGuid == this.guid).toList();
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    if (!kIsWeb) associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    return this;
  }

  Handle? getHandle() {
    if (kIsWeb) return null;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    this.handle = handleBox.get(this.handleId!);
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return handleBox.get(this.handleId!);
  }

  static Message? findOne({String? guid, String? associatedMessageGuid}) {
    if (kIsWeb) return null;
    if (guid != null) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      final query = messageBox.query(Message_.guid.equals(guid)).build();
      query..limit = 1;
      final result = query.findFirst();
      query.close();
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      return result;
    } else if (associatedMessageGuid != null) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      final query = messageBox.query(Message_.associatedMessageGuid.equals(associatedMessageGuid)).build();
      query..limit = 1;
      final result = query.findFirst();
      query.close();
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      return result;
    }
    return null;
  }

  static DateTime? lastMessageDate() {
    if (kIsWeb) return null;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    final query = (messageBox.query()..order(Message_.dateCreated, flags: Order.descending)).build();
    query..limit = 1;
    final messages = query.find();
    query.close();
    return messages.isEmpty ? null : messages.first.dateCreated;
  }

  static List<Message> find() {
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return messageBox.getAll();
  }

  static void delete(String guid) {
    if (kIsWeb) return;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    final query = messageBox.query(Message_.guid.equals(guid)).build();
    final results = query.find();
    final ids = results.map((e) => e.id!).toList();
    query.close();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    final query2 = cmJoinBox.query(ChatMessageJoin_.messageId.oneOf(ids)).build();
    final results2 = query2.find();
    query2.close();
    cmJoinBox.removeMany(results2.map((e) => e.id!).toList());
    messageBox.removeMany(ids);
  }

  static void softDelete(String guid) {
    if (kIsWeb) return null;
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
    return (this.balloonBundleId != null &&
            this.balloonBundleId == "com.apple.messages.URLBalloonProvider" &&
            this.hasDdResults!) ||
        (this.hasDdResults! && (this.text ?? "").replaceAll("\n", " ").hasUrl);
  }

  String? getUrl() {
    if (text == null) return null;
    List<String> splits = this.text!.replaceAll("\n", " ").split(" ");
    return splits.firstWhereOrNull((String element) => element.hasUrl);
  }

  bool isInteractive() {
    return this.balloonBundleId != null && this.balloonBundleId != "com.apple.messages.URLBalloonProvider";
  }

  bool hasText({stripWhitespace = false}) {
    return !isEmptyString(this.fullText, stripWhitespace: stripWhitespace);
  }

  bool isGroupEvent() {
    return isEmptyString(this.fullText) && !this.hasAttachments && this.balloonBundleId == null;
  }

  bool isBigEmoji() {
    // We are checking the variable first because we want to
    // avoid processing twice for this as it won't change
    if (this.bigEmoji == null) {
      this.bigEmoji = MessageHelper.shouldShowBigEmoji(this.fullText);
    }

    return this.bigEmoji!;
  }

  List<Attachment?> getRealAttachments() {
    return this.attachments!.where((item) => item!.mimeType != null).toList();
  }

  List<Attachment?> getPreviewAttachments() {
    return this.attachments!.where((item) => item!.mimeType == null).toList();
  }

  List<Message> getReactions() {
    return this
        .associatedMessages
        .where((item) => ReactionTypes.toList().contains(item.associatedMessageType))
        .toList();
  }

  void generateTempGuid() {
    List<String> unique = [this.text ?? "", this.dateCreated?.millisecondsSinceEpoch.toString() ?? ""];

    String preHashed;
    if (unique.every((element) => element.trim().length == 0)) {
      preHashed = randomString(8);
    } else {
      preHashed = unique.join(":");
    }

    String hashed = crypto.sha1.convert(utf8.encode(preHashed)).toString();
    this.guid = "temp-$hashed";
  }

  static int? countForChat(Chat? chat) {
    if (kIsWeb || chat == null || chat.id == null) return 0;
    return cmJoinBox.getAll().where((element) => element.chatId == chat.id).length;
  }

  void merge(Message otherMessage) {
    if (this.dateCreated == null && otherMessage.dateCreated != null) {
      this.dateCreated = otherMessage.dateCreated;
    }
    if (this.dateDelivered == null && otherMessage.dateDelivered != null) {
      this.dateDelivered = otherMessage.dateDelivered;
    }
    if (this.dateRead == null && otherMessage.dateRead != null) {
      this.dateRead = otherMessage.dateRead;
    }
    if (this.dateDeleted == null && otherMessage.dateDeleted != null) {
      this.dateDeleted = otherMessage.dateDeleted;
    }
    if (this.datePlayed == null && otherMessage.datePlayed != null) {
      this.datePlayed = otherMessage.datePlayed;
    }
    if (this.metadata == null && otherMessage.metadata != null) {
      this.metadata = otherMessage.metadata;
    }
    if (this.originalROWID == null && otherMessage.originalROWID != null) {
      this.originalROWID = otherMessage.originalROWID;
    }
    if (!this.hasAttachments && otherMessage.hasAttachments) {
      this.hasAttachments = otherMessage.hasAttachments;
    }
    if (!this.hasReactions && otherMessage.hasReactions) {
      this.hasReactions = otherMessage.hasReactions;
    }
    if (this._error.value == 0 && otherMessage._error.value != 0) {
      this._error.value = otherMessage._error.value;
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
