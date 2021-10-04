import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/attachment.dart';
import 'package:bluebubbles/repository/models/io/join_tables.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Condition;
import 'package:metadata_fetch/metadata_fetch.dart';

import 'chat.dart';
import 'handle.dart';

/// Async method to fetch attachments;
Future<Map<String, List<Attachment?>>> fetchAttachmentsIsolate(List<dynamic> stuff) async {
  /// Pull args from input and create new instances of store and boxes
  List<int> messageIds = stuff[0];
  List<String> guids = stuff[1];
  String? storeRef = stuff[2];
  final Map<String, List<Attachment?>> map = {};
  final store = Store.fromReference(getObjectBoxModel(), base64.decode(storeRef!).buffer.asByteData());
  final amJoinBox = store.box<AttachmentMessageJoin>();
  return store.runInTransaction(TxMode.read, () {
    /// Query the [amJoinBox] for relevant attachment IDs
    final amJoinQuery = amJoinBox.query(AttachmentMessageJoin_.messageId.oneOf(messageIds)).build();
    final amJoins = amJoinQuery.find();
    amJoinQuery.close();
    /// Add the attachments to the map with some clever list operations
    map.addEntries(guids.mapIndexed(
            (index, e) => MapEntry(e, attachmentBox.getMany(amJoins.where(
                (e2) => e2.messageId == messageIds[index]).map(
                (e3) => e3.attachmentId).toSet().toList(), growableResult: true))));
    return map;
  });
}

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

  /// Save a single message - prefer [bulkSave] for multiple messages rather
  /// than iterating through them
  Message save() {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
     Message? existing = Message.findOne(guid: guid);
     if (existing != null) {
       id = existing.id;
     }

     // Save the participant & set the handle ID to the new participant
     if (handle == null && id == null && handleId != null) {
       handle = Handle.findOne(originalROWID: handleId);
     }
     if (handle != null) {
       handle!.save();
       handleId = handle!.id;
     }
     // Save associated messages or the original message (depending on whether
     // this message is a reaction or regular message
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
       id = messageBox.put(this);
     } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save a list of messages
  static List<Message> bulkSave(List<Message> messages) {
    store.runInTransaction(TxMode.write, () {
      /// Find existing messages and match them to the messages to save, where
      /// possible
      List<Message> existingMessages = Message.find(cond: Message_.guid.oneOf(messages.map((e) => e.guid!).toList()));
      for (Message m in messages) {
        final existingMessage = existingMessages.firstWhereOrNull((e) => e.guid == m.guid);
        if (existingMessage != null) {
          m.id = existingMessage.id;
        }
      }
      /// Save the messages and update their IDs
      /// We do this first because we might want these same messages to show up
      /// in the next queries
      final ids = messageBox.putMany(messages);
      for (int i = 0; i < messages.length; i++) {
        messages[i].id = ids[i];
      }
      /// Find associated messages or original messages
      List<Message> associatedMessages = Message.find(cond: Message_.guid.oneOf(messages.map((e) => e.associatedMessageGuid ?? "").toList()));
      List<Message> originalMessages = Message.find(cond: Message_.associatedMessageGuid.oneOf(messages.map((e) => e.guid!).toList()));
      /// Save handles
      final handles = Handle.bulkSave(messages.where((e) => e.handle != null).map((e) => e.handle!).toList());
      /// Iterate thru messages and update the associated message or the original
      /// message, and update original message handle data
      for (Message m in messages) {
        if (m.associatedMessageType != null && m.associatedMessageGuid != null) {
          final associatedMessageList = associatedMessages.where((e) => e.guid == m.associatedMessageGuid);
          for (Message am in associatedMessageList) {
            am.hasReactions = true;
          }
        } else if (!m.hasReactions) {
          final originalMessage = originalMessages.firstWhereOrNull((e) => e.associatedMessageGuid == m.guid);
          if (originalMessage != null) {
            m.hasReactions = true;
          }
        }
        final existingHandle = handles.firstWhereOrNull((e) => e.address == m.handle?.address);
        if (existingHandle != null) {
          m.handleId = existingHandle.id;
        }
      }
      associatedMessages.removeWhere((message) {
        Message? _message = messages.firstWhereOrNull((e) => e.guid == message.guid);
        _message?.hasReactions = message.hasReactions;
        return _message != null;
      });
      try {
        /// Update the original messages and associated messages
        final ids = messageBox.putMany(messages..addAll(associatedMessages));
        for (int i = 0; i < messages.length; i++) {
          messages[i].id = ids[i];
        }
      } on UniqueViolationException catch (_) {}
    });
    return messages;
  }

  /// Replace a temp message with the message from the server
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

  /// Fetch attachments with a bulk list of messages. Returns a map with the
  /// message guid as key and a list of attachments as the value. DO NOT use this
  /// method in performance-sensitive areas, prefer using
  /// [fetchAttachmentsByMessagesAsync]
  static Map<String, List<Attachment?>> fetchAttachmentsByMessages(List<Message?> messages, {CurrentChat? currentChat}) {
    final Map<String, List<Attachment?>> map = {};
    if (kIsWeb) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, e.attachments ?? [])));
      return map;
    }

    /// If we have a [CurrentChat] just return the attachments stored in it
    if (currentChat != null) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, currentChat.getAttachmentsForMessage(e) ?? [])));
      return map;
    }

    if (messages.isEmpty) return {};

    return store.runInTransaction(TxMode.read, () {
      /// Find eligible message IDs and then find [AttachmentMessageJoin]s
      /// matching those message IDs
      final messageIds = messages.where((element) => element?.id != null).map((e) => e!.id!).toList();
      final amJoinQuery = amJoinBox.query(AttachmentMessageJoin_.messageId.oneOf(messageIds)).build();
      final amJoins = amJoinQuery.find();
      amJoinQuery.close();
      /// Add the attachments with some fancy list operations
      map.addEntries(messages.map(
          (e) => MapEntry(e!.guid!, attachmentBox.getMany(amJoins.where(
              (e2) => e2.messageId == e.id).map(
                  (e3) => e3.attachmentId).toSet().toList(), growableResult: true))));
      return map;
    });
  }

  /// Fetch message attachments for a list of messages, but async
  static Future<Map<String, List<Attachment?>>> fetchAttachmentsByMessagesAsync(List<Message?> messages, {CurrentChat? currentChat}) async {
    final Map<String, List<Attachment?>> map = {};
    if (kIsWeb) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, e.attachments ?? [])));
      return map;
    }

    if (currentChat != null) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, currentChat.getAttachmentsForMessage(e) ?? [])));
      return map;
    }

    return await compute(fetchAttachmentsIsolate, [messages.map((e) => e!.id!).toList(), messages.map((e) => e!.guid!).toList(), prefs.getString("objectbox-reference")]);
  }

  /// Fetch attachments for a single message. Prefer using [fetchAttachmentsByMessages]
  /// or [fetchAttachmentsByMessagesAsync] when working with a list of messages.
  List<Attachment?>? fetchAttachments({CurrentChat? currentChat}) {
    if (kIsWeb || (hasAttachments && attachments != null && attachments!.isNotEmpty)) {
      return attachments;
    }

    if (currentChat != null) {
      attachments = currentChat.getAttachmentsForMessage(this);
      attachments ??= [];
      if (attachments!.isNotEmpty) return attachments;
    }

    if (id == null) return [];
    return store.runInTransaction(TxMode.read, () {
      /// Find attachment IDs matching the provided message ID
      final attachmentIdQuery = amJoinBox.query(AttachmentMessageJoin_.messageId.equals(id!)).build();
      final attachmentIds = attachmentIdQuery.property(AttachmentMessageJoin_.attachmentId).find().toSet().toList();
      attachmentIdQuery.close();
      /// Find the attachments themselves
      final attachments = attachmentBox.getMany(attachmentIds, growableResult: true);
      this.attachments = attachments;
      return attachments;
    });
  }

  /// Get the chat associated with the message
  Chat? getChat() {
    if (kIsWeb) return null;
    return store.runInTransaction(TxMode.read, () {
      /// Find the chatID, then find the chat itself
      final chatIdQuery = cmJoinBox.query(ChatMessageJoin_.messageId.equals(id!)).build();
      /// Note: don't use [findFirst()] here because it errors out sometimes
      final chatId = chatIdQuery.property(ChatMessageJoin_.chatId).find().firstOrNull;
      chatIdQuery.close();
      if (chatId == null) return null;
      return chatBox.get(chatId);
    });
  }

  /// Fetch reactions
  Message fetchAssociatedMessages({MessageBloc? bloc}) {
    if (associatedMessages.isNotEmpty &&
        associatedMessages.length == 1 &&
        associatedMessages[0].guid == guid) {
      return this;
    }
    if (kIsWeb) {
      associatedMessages = bloc?.reactionMessages.values.where((element) => element.associatedMessageGuid == guid).toList() ?? [];
    } else {
      associatedMessages = Message.find(cond: Message_.associatedMessageGuid.equals(guid!));
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    if (!kIsWeb) associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    return this;
  }

  Handle? getHandle() {
    if (kIsWeb) return null;
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

  /// Find the date of the latest message in the DB
  static DateTime? lastMessageDate() {
    if (kIsWeb) return null;
    final query = (messageBox.query()..order(Message_.dateCreated, flags: Order.descending)..order(Message_.originalROWID, flags: Order.descending)).build();
    query.limit = 1;
    final messages = query.find();
    query.close();
    return messages.isEmpty ? null : messages.first.dateCreated;
  }

  /// Find a list of messages by the specified condition, or return all messages
  /// when no condition is specified
  static List<Message> find({Condition<Message>? cond}) {
    final query = messageBox.query(cond).build();
    return query.find();
  }

  /// Delete a message and remove all instances of that message in the DB
  static void delete(String guid) {
    if (kIsWeb) return;
    store.runInTransaction(TxMode.write, () {
      final query = messageBox.query(Message_.guid.equals(guid)).build();
      final results = query.find();
      final ids = results.map((e) => e.id!).toList();
      query.close();
      final query2 = cmJoinBox.query(ChatMessageJoin_.messageId.oneOf(ids)).build();
      final results2 = query2.find();
      query2.close();
      cmJoinBox.removeMany(results2.map((e) => e.id!).toList());
      messageBox.removeMany(ids);
    });
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

  /// Find how many messages exist in the DB for a chat
  static int? countForChat(Chat? chat) {
    if (kIsWeb || chat == null || chat.id == null) return 0;
    final chatIdQuery = cmJoinBox.query(ChatMessageJoin_.chatId.equals(chat.id!)).build();
    final length = chatIdQuery.find().length;
    chatIdQuery.close();
    return length;
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

  Map<String, dynamic> toMap({bool includeObjects = false}) {
     final map = {
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
     if (includeObjects) {
       map['attachments'] = (attachments ?? []).map((e) => e!.toMap()).toList();
       map['handle'] = handle?.toMap();
     }
     return map;
  }
}
