import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/attributed_body.dart';
import 'package:bluebubbles/repository/models/io/attachment.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Condition;
import 'package:metadata_fetch/metadata_fetch.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

import 'chat.dart';
import 'handle.dart';

/// Async method to fetch attachments;
class GetMessageAttachments extends AsyncTask<List<dynamic>, Map<String, List<Attachment?>>> {
  final List<dynamic> stuff;

  GetMessageAttachments(this.stuff);

  @override
  AsyncTask<List<dynamic>, Map<String, List<Attachment?>>> instantiate(List<dynamic> parameters,
      [Map<String, SharedData>? sharedData]) {
    return GetMessageAttachments(parameters);
  }

  @override
  List<dynamic> parameters() {
    return stuff;
  }

  @override
  FutureOr<Map<String, List<Attachment?>>> run() {
    /// Pull args from input and create new instances of store and boxes
    List<int> messageIds = stuff[0];
    final Map<String, List<Attachment?>> map = {};
    return store.runInTransaction(TxMode.read, () {
      /// Query the [amJoinBox] for relevant attachment IDs
      final messages = messageBox.getMany(messageIds);

      /// Add the attachments to the map with some clever list operations
      map.addEntries(messages.mapIndexed((index, e) => MapEntry(e!.guid!, e.dbAttachments)));
      return map;
    });
  }
}

/// Async method to get chats from objectbox
class BulkSaveNewMessages extends AsyncTask<List<dynamic>, List<Message>> {
  final List<dynamic> params;

  BulkSaveNewMessages(this.params);

  @override
  AsyncTask<List<dynamic>, List<Message>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return BulkSaveNewMessages(parameters);
  }

  @override
  List<dynamic> parameters() {
    return params;
  }

  @override
  FutureOr<List<Message>> run() {
    return store.runInTransaction(TxMode.write, () {
      // NOTE: This assumes that handles and chats will already be created and in the database
      // 0. Create map for the messages and attachments to save
      // 1. Check for existing attachments and save new ones
      // 2. Fetch all inserted/existing attachments based on input
      // 3. Create map of inserted/existing attachments
      // 4. Check for existing messages & create list of new messages to save
      // 5. Fetch all handles and map the old handle ROWIDs from each message to the new ones based on the original ROWID
      // 6. Relate the attachments to the messages
      // 7. Save all messages (and handle/attachment relationships)
      // 8. Get the inserted messages
      // 9. Check inserted messages for associated message GUIDs & update hasReactions flag
      // 10. Save the updated associated messages
      // 11. Update the associated chat's last message

      /// Takes the list of messages from [params] and saves it
      /// to the objectbox store.
      Chat inputChat = params[0];
      List<Message> inputMessages = params[1];
      List<String> inputMessageGuids = inputMessages.map((element) => element.guid!).toList();

      // 0. Create map for the messages and attachments to save
      Map<String, Attachment> attachmentsToSave = {};
      Map<String, List<String>> messageAttachments = {};
      for (final msg in inputMessages) {
        for (final a in msg.attachments) {
          if (!attachmentsToSave.containsKey(a!.guid)) {
            attachmentsToSave[a.guid!] = a;
          }

          if (!messageAttachments.containsKey(a.guid)) {
            messageAttachments[msg.guid!] = [];
          }

          if (!messageAttachments[msg.guid]!.contains(a.guid)) {
            messageAttachments[msg.guid]?.add(a.guid!);
          }
        }
      }

      // 1. Check for existing attachments and save new ones
      Map<String, Attachment> attachmentMap = {};
      if (attachmentsToSave.isNotEmpty) {
        List<String> inputAttachmentGuids = attachmentsToSave.values.map((e) => e.guid).whereNotNull().toList();
        QueryBuilder<Attachment> attachmentQuery = attachmentBox.query(Attachment_.guid.oneOf(inputAttachmentGuids));
        List<String> existingAttachmentGuids =
            attachmentQuery.build().find().map((e) => e.guid).whereNotNull().toList();

        // Insert the attachments that don't yet exist
        List<Attachment> attachmentsToInsert = attachmentsToSave.values
            .where((element) => !existingAttachmentGuids.contains(element.guid))
            .whereNotNull()
            .toList();
        attachmentBox.putMany(attachmentsToInsert);

        // 2. Fetch all inserted/existing attachments based on input
        QueryBuilder<Attachment> attachmentQuery2 = attachmentBox.query(Attachment_.guid.oneOf(inputAttachmentGuids));
        List<Attachment> attachments = attachmentQuery2.build().find().whereNotNull().toList();

        // 3. Create map of inserted/existing attachments
        for (final a in attachments) {
          attachmentMap[a.guid!] = a;
        }
      }

      // 4. Check for existing messages & create list of new messages to save
      QueryBuilder<Message> query = messageBox.query(Message_.guid.oneOf(inputMessageGuids));
      List<String> existingMessageGuids = query.build().find().map((e) => e.guid!).toList();
      inputMessages = inputMessages.where((element) => !existingMessageGuids.contains(element.guid)).toList();

      // 5. Fetch all handles and map the old handle ROWIDs from each message to the new ones based on the original ROWID
      List<Handle> handles = handleBox.getAll();
      Map<int, Handle> originalRowIdMap = {};
      for (final h in handles) {
        if (h.originalROWID != null) {
          originalRowIdMap[h.originalROWID!] = h;
        }
      }

      for (final msg in inputMessages) {
        msg.chat.target = inputChat;
        msg.handleId = originalRowIdMap[msg.handleId]?.id ?? msg.handleId;
        msg.handle = originalRowIdMap[msg.handleId];
        msg.otherHandle = originalRowIdMap[msg.otherHandle]?.id ?? msg.otherHandle;
      }

      // 6. Relate the attachments to the messages
      for (final msg in inputMessages) {
        final relatedAttachments =
            messageAttachments[msg.guid]?.map((e) => attachmentMap[e]).whereNotNull().toList() ?? [];
        msg.attachments = relatedAttachments;
        msg.dbAttachments.addAll(relatedAttachments);
      }

      // 7. Save all messages (and handle/attachment relationships)
      messageBox.putMany(inputMessages);

      // 8. Get the inserted messages
      QueryBuilder<Message> messageQuery = messageBox.query(Message_.guid.oneOf(inputMessageGuids));
      List<Message> messages = messageQuery.build().find().toList();

      // 9. Check inserted messages for associated message GUIDs & update hasReactions flag
      Map<String, Message> messagesToUpdate = {};
      for (final message in messages) {
        // Update the handles from our cache
        message.handle = handles.firstWhereOrNull((element) => element.id == message.handleId);

        // Continue if there isn't an associated message GUID to process
        if ((message.associatedMessageGuid ?? '').isEmpty) continue;

        // Find the associated message in the DB and update the hasReactions flag
        List<Message> associatedMessages =
            Message.find(cond: Message_.guid.equals(message.associatedMessageGuid!)).toList();
        if (associatedMessages.isNotEmpty) {
          // Toggle the hasReactions flag
          Message messageWithReaction = messagesToUpdate[associatedMessages[0].guid] ?? associatedMessages[0];
          messageWithReaction.hasReactions = true;

          // Make sure the current message has the associated message in it's list, and the hasReactions
          // flag is set as well
          Message reactionMessage = messagesToUpdate[message.guid!] ?? message;
          for (var e in messageWithReaction.associatedMessages) {
            if (e.guid == messageWithReaction.guid) {
              e.hasReactions = true;
              break;
            }
          }

          // Update the cached values
          messagesToUpdate[messageWithReaction.guid!] = messageWithReaction;
          messagesToUpdate[reactionMessage.guid!] = reactionMessage;
        }
      }

      // 10. Save the updated associated messages
      if (messagesToUpdate.isNotEmpty) {
        try {
          messageBox.putMany(messagesToUpdate.values.toList());
        } catch (ex) {
          print('Failed to put associated messages into DB: ${ex.toString()}');
        }
      }

      // 11. Update the associated chat's last message
      messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
      bool isNewer = false;

      // If the message was saved correctly, update this chat's latestMessage info,
      // but only if the incoming message's date is newer
      if (messages.isNotEmpty) {
        if ((messages[0].id != null || kIsWeb)) {
          if (inputChat.latestMessageDate == null) {
            isNewer = true;
          } else if (inputChat.latestMessageDate!.millisecondsSinceEpoch <
              messages[0].dateCreated!.millisecondsSinceEpoch) {
            isNewer = true;
          }
        }

        if (isNewer) {
          inputChat.latestMessage = messages[0];
          inputChat.latestMessageText = MessageHelper.getNotificationText(messages[0]);
          inputChat.fakeLatestMessageText =
              faker.lorem.words((inputChat.latestMessageText ?? "").split(" ").length).join(" ");
          inputChat.latestMessageDate = messages[0].dateCreated;

          // Save the chat with the new info
          chatBox.put(inputChat);
        }
      }

      return messages;
    });
  }
}

enum LineType { meToMe, otherToMe, meToOther, otherToOther }

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
  DateTime? dateCreated;
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
  List<AttributedBody>? attributedBody;

  final RxInt _error = RxInt(0);
  int get error => _error.value;
  set error(int i) => _error.value = i;

  final Rxn<DateTime> _dateRead = Rxn<DateTime>();
  DateTime? get dateRead => _dateRead.value;
  set dateRead(DateTime? d) => _dateRead.value = d;

  final Rxn<DateTime> _dateDelivered = Rxn<DateTime>();
  DateTime? get dateDelivered => _dateDelivered.value;
  set dateDelivered(DateTime? d) => _dateDelivered.value = d;

  @Backlink('message')
  final dbAttachments = ToMany<Attachment>();

  final chat = ToOne<Chat>();

  String? get dbAttributedBody => attributedBody == null ? null : jsonEncode(attributedBody!.map((e) => e.toMap()).toList());
  set dbAttributedBody(String? json) => attributedBody = json == null ? null : (jsonDecode(json) as List).map((e) => AttributedBody.fromMap(e)).toList();

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
      DateTime? dateRead2,
      DateTime? dateDelivered2,
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
      this.threadOriginatorPart,
      this.attributedBody}) {
    if (error2 != null) _error.value = error2;
    if (dateRead2 != null) _dateRead.value = dateRead2;
    if (dateDelivered2 != null) _dateDelivered.value = dateDelivered2;
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
    List<AttributedBody>? attributedBody;
    if (json.containsKey("attributedBody") && json["attributedBody"] != null) {
      if (json['attributedBody'] is Map) {
        json['attributedBody'] = [json['attributedBody']];
      }

      attributedBody = (json['attributedBody'] as List).map((a) => AttributedBody.fromMap(a)).toList();
    }

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
      dateRead2: json.containsKey("dateRead") ? parseDate(json["dateRead"]) : null,
      dateDelivered2: json.containsKey("dateDelivered") ? parseDate(json["dateDelivered"]) : null,
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
      threadOriginatorGuid: json.containsKey('threadOriginatorGuid') ? json['threadOriginatorGuid'] : null,
      threadOriginatorPart: json.containsKey('threadOriginatorPart') ? json['threadOriginatorPart'] : null,
      attributedBody: attributedBody
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  static int count() {
    return messageBox.count();
  }

  /// Save a single message - prefer [bulkSave] for multiple messages rather
  /// than iterating through them
  Message save({Chat? chat}) {
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
        if (chat != null) this.chat.target = chat;
        id = messageBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  static Future<List<Message>> bulkSaveNewMessages(Chat chat, List<Message> messages) async {
    if (kIsWeb) throw Exception("Web does not support saving messages!");

    final task = BulkSaveNewMessages([chat, messages]);
    return (await createAsyncTask<List<Message>>(task)) ?? [];
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
      List<Message> associatedMessages =
          Message.find(cond: Message_.guid.oneOf(messages.map((e) => e.associatedMessageGuid ?? "").toList()));
      List<Message> originalMessages =
          Message.find(cond: Message_.associatedMessageGuid.oneOf(messages.map((e) => e.guid!).toList()));

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
  static Future<Message> replaceMessage(String? oldGuid, Message newMessage,
      {bool awaitNewMessageEvent = true, Chat? chat}) async {
    Message? existing = Message.findOne(guid: oldGuid);

    // Create or wait for the new message
    if (existing == null || existing.handleId == null || (existing.handle == null && (existing.handleId ?? 0) > 0)) {
      // If we want to "await" the new message event, wait 500 milliseconds and then see if the message exists in the database
      // This is not actually awaiting the event, just the milliseconds.
      if (awaitNewMessageEvent) {
        await Future.delayed(Duration(milliseconds: 500));
        return replaceMessage(oldGuid, newMessage, awaitNewMessageEvent: false, chat: chat);
      }

      // If we have a chat and the message doesn't exist, let's add the message as new
      if (chat != null) {
        await chat.addMessage(newMessage);
        MessageManager().addMessage(chat, newMessage, outgoing: false);
        return newMessage;
      } else {
        // If we don't have a chat, we just want to add the message
        messageBox.put(newMessage);
        return newMessage;
      }
    }

    // This is what happens whenever the existing message already exists.
    // We just need to update the timestamps & error
    if (existing.guid != newMessage.guid) {
      existing.guid = newMessage.guid;
    }

    existing._dateDelivered.value = newMessage._dateDelivered.value ?? existing._dateDelivered.value;
    existing._dateRead.value = newMessage._dateRead.value ?? existing._dateRead.value;
    existing._error.value = newMessage._error.value;

    try {
      messageBox.put(existing, mode: PutMode.update);
    } catch (ex) {
      Logger.error(
          'Failed to replace message! This is likely due to a unique constraint being violated. See error below:');
      Logger.error(ex.toString());
    }

    return existing;
  }

  Message updateMetadata(Metadata? metadata) {
    if (kIsWeb || id == null) return this;
    this.metadata = metadata!.toJson();
    save();
    return this;
  }

  Message setPlayedDate({DateTime? timestamp}) {
    datePlayed = timestamp ?? DateTime.now().toUtc();
    save();
    return this;
  }

  /// Fetch attachments with a bulk list of messages. Returns a map with the
  /// message guid as key and a list of attachments as the value. DO NOT use this
  /// method in performance-sensitive areas, prefer using
  /// [fetchAttachmentsByMessagesAsync]
  static Map<String, List<Attachment?>> fetchAttachmentsByMessages(List<Message?> messages,
      {ChatController? currentChat}) {
    final Map<String, List<Attachment?>> map = {};
    if (kIsWeb) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, e.attachments)));
      return map;
    }

    /// If we have a [ChatController] just return the attachments stored in it
    if (currentChat != null) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, currentChat.getAttachmentsForMessage(e))));
      return map;
    }

    if (messages.isEmpty) return {};

    return store.runInTransaction(TxMode.read, () {
      /// Find eligible message IDs and then find [AttachmentMessageJoin]s
      /// matching those message IDs

      /// Add the attachments with some fancy list operations
      /// The conditional is in case objectbox hasn't persisted the dbAttachments yet
      map.addEntries(messages
          .where((element) => element?.id != null)
          .map((e) => MapEntry(e!.guid!, e.dbAttachments.isEmpty ? e.attachments : e.dbAttachments)));
      return map;
    });
  }

  /// Fetch message attachments for a list of messages, but async
  static Future<Map<String, List<Attachment?>>> fetchAttachmentsByMessagesAsync(List<Message?> messages,
      {ChatController? currentChat}) async {
    final Map<String, List<Attachment?>> map = {};
    if (kIsWeb) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, e.attachments)));
      return map;
    }

    if (currentChat != null) {
      map.addEntries(messages.map((e) => MapEntry(e!.guid!, currentChat.getAttachmentsForMessage(e))));
      return map;
    }

    final task = GetMessageAttachments([
      messages.map((e) => e!.id!).toList(),
    ]);
    return (await createAsyncTask<Map<String, List<Attachment?>>>(task)) ?? {};
  }

  /// Fetch attachments for a single message. Prefer using [fetchAttachmentsByMessages]
  /// or [fetchAttachmentsByMessagesAsync] when working with a list of messages.
  List<Attachment?>? fetchAttachments({ChatController? currentChat}) {
    if (kIsWeb || (hasAttachments && attachments.isNotEmpty)) {
      return attachments;
    }

    if (currentChat?.messageAttachments.containsKey(guid) ?? false) {
      attachments = currentChat!.getAttachmentsForMessage(this);
      if (attachments.isNotEmpty) return attachments;
    }

    if (id == null) return [];
    return store.runInTransaction(TxMode.read, () {
      return dbAttachments;
    });
  }

  /// Get the chat associated with the message
  Chat? getChat() {
    if (kIsWeb) return null;
    return store.runInTransaction(TxMode.read, () {
      return chat.target;
    });
  }

  /// Fetch reactions
  Message fetchAssociatedMessages({MessageBloc? bloc, bool shouldRefresh = false}) {
    associatedMessages = Message.find(cond: Message_.associatedMessageGuid.equals(guid ?? ""));
    associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    if (threadOriginatorGuid != null) {
      final existing = bloc?.messages.values.firstWhereOrNull((e) => e.guid == threadOriginatorGuid);
      final threadOriginator = existing ?? Message.findOne(guid: threadOriginatorGuid);
      threadOriginator?.handle ??= Handle.findOne(id: threadOriginator.handleId);
      if (threadOriginator != null) associatedMessages.add(threadOriginator);
      if (existing == null && threadOriginator != null) bloc?.addMessage(threadOriginator);
      if (!guid!.startsWith("temp"))
        bloc?.threadOriginators.conditionalAdd(guid!, threadOriginatorGuid!, shouldRefresh);
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    return this;
  }

  Handle? getHandle() {
    if (kIsWeb || handleId == 0 || handleId == null) return null;
    return handleBox.get(handleId!);
  }

  static Message? findOne({String? guid, String? associatedMessageGuid}) {
    if (kIsWeb) return null;
    if (guid != null) {
      final query = messageBox.query(Message_.guid.equals(guid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      result?.handle = result.getHandle();
      return result;
    } else if (associatedMessageGuid != null) {
      final query = messageBox.query(Message_.associatedMessageGuid.equals(associatedMessageGuid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      result?.handle = result.getHandle();
      return result;
    }
    return null;
  }

  /// Find the date of the latest message in the DB
  static DateTime? lastMessageDate() {
    if (kIsWeb) return null;
    final query = (messageBox.query()
          ..order(Message_.dateCreated, flags: Order.descending)
          ..order(Message_.originalROWID, flags: Order.descending))
        .build();
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
      final result = query.findFirst();
      query.close();
      if (result?.id != null) {
        messageBox.remove(result!.id!);
      }
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
    return (balloonBundleId != null && balloonBundleId == "com.apple.messages.URLBalloonProvider" && hasDdResults!) ||
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
    return isEmptyString(fullText) &&
        (!hasAttachments || (itemType == 3 && groupActionType == 1)) &&
        balloonBundleId == null;
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
    return associatedMessages.where((item) => ReactionTypes.toList().contains(item.associatedMessageType?.replaceAll("-", ""))).toList();
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
    return chat.messages.length;
  }

  void mergeWith(Message otherMessage) {
    Message.merge(this, otherMessage);
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
    if (getLineType(olderMessage, threadOriginator) == LineType.meToOther ||
        getLineType(olderMessage, threadOriginator) == LineType.otherToOther) return false;
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
    if (olderMessage == null ||
        (olderMessage.threadOriginatorGuid != threadOriginatorGuid && !upperIsThreadOriginatorBubble(olderMessage))) {
      return false;
    }
    // if the older message is the outlined bubble, or the originator is from
    // someone else and the message is from me, then draw the connecting line
    // (the second condition might be redundant / unnecessary but I left it in
    // just in case)
    if (upperIsThreadOriginatorBubble(olderMessage) ||
        (!threadOriginator.isFromMe! && isFromMe!) ||
        getLineType(olderMessage, threadOriginator) == LineType.meToMe ||
        getLineType(olderMessage, threadOriginator) == LineType.otherToMe) return true;
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
  Size getBubbleSize(BuildContext context,
      {double? maxWidthOverride, double? minHeightOverride, String? textOverride}) {
    // cache this value because the calculation can be expensive
    if (ChatBloc().cachedMessageBubbleSizes[guid!] != null) return ChatBloc().cachedMessageBubbleSizes[guid!]!;
    // if attachment, then grab width / height
    if (fullText.isEmpty && (attachments).isNotEmpty) {
      return Size(
          attachments
              .map((e) => e!.width)
              .fold(0, (p, e) => max(p, (e ?? CustomNavigator.width(context) / 2).toDouble()) + 28),
          attachments
              .map((e) => e!.height)
              .fold(0, (p, e) => max(p, (e ?? CustomNavigator.width(context) / 2).toDouble())));
    }
    // initialize constraints for text rendering
    final fontSizeFactor = isBigEmoji() ? 4.0 : 1.0;
    final constraints = BoxConstraints(
      maxWidth: maxWidthOverride ?? CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE - 30,
      minHeight: minHeightOverride ?? Theme.of(context).textTheme.bodySmall!.fontSize! * fontSizeFactor,
    );
    final renderParagraph = RichText(
      text: TextSpan(
        text: textOverride ?? fullText,
        style: context.theme.textTheme.bodySmall!.apply(color: Colors.white, fontSizeFactor: fontSizeFactor),
      ),
    ).createRenderObject(context);
    // get the text size
    Size size = renderParagraph.getDryLayout(constraints);
    // if the text is shorter than the full width, add 28 to account for the
    // container margins
    if (size.height < context.theme.textTheme.bodySmall!.fontSize! * 2 * fontSizeFactor ||
        (subject != null && size.height < context.theme.textTheme.bodySmall!.fontSize! * 3 * fontSizeFactor)) {
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

  static Message merge(Message existing, Message newMessage) {
    existing.id ??= newMessage.id;
    existing.guid ??= newMessage.guid;
  
    // Update date created
    if ((existing.dateCreated == null && newMessage.dateCreated != null) ||
        (existing.dateCreated != null &&
            newMessage.dateCreated != null &&
            existing.dateCreated!.millisecondsSinceEpoch < newMessage.dateCreated!.millisecondsSinceEpoch)) {
      existing.dateCreated = newMessage.dateCreated;
    }

    // Update date delivered
    if ((existing._dateDelivered.value == null && newMessage._dateDelivered.value != null) ||
        (existing._dateDelivered.value != null &&
            newMessage.dateDelivered != null &&
            existing._dateDelivered.value!.millisecondsSinceEpoch <
                newMessage._dateDelivered.value!.millisecondsSinceEpoch)) {
      existing._dateDelivered.value = newMessage.dateDelivered;
    }

    // Update date delivered
    if ((existing._dateRead.value == null && newMessage._dateRead.value != null) ||
        (existing._dateRead.value != null &&
            newMessage._dateRead.value != null &&
            existing._dateRead.value!.millisecondsSinceEpoch < newMessage._dateRead.value!.millisecondsSinceEpoch)) {
      existing._dateRead.value = newMessage.dateRead;
    }

    // Update date played
    if ((existing.datePlayed == null && newMessage.datePlayed != null) ||
        (existing.datePlayed != null &&
            newMessage.datePlayed != null &&
            existing.datePlayed!.millisecondsSinceEpoch < newMessage.datePlayed!.millisecondsSinceEpoch)) {
      existing.datePlayed = newMessage.datePlayed;
    }

    // Update date deleted
    if ((existing.dateDeleted == null && newMessage.dateDeleted != null) ||
        (existing.dateDeleted != null &&
            newMessage.dateDeleted != null &&
            existing.dateDeleted!.millisecondsSinceEpoch < newMessage.dateDeleted!.millisecondsSinceEpoch)) {
      existing.dateDeleted = newMessage.dateDeleted;
    }

    // Update error
    if (existing._error.value != newMessage._error.value) {
      existing._error.value = newMessage._error.value;
    }

    // Update has Dd results
    if ((existing.hasDdResults == null && newMessage.hasDdResults != null) ||
        (!existing.hasDdResults! && newMessage.hasDdResults!)) {
      existing.hasDdResults = newMessage.hasDdResults;
    }

    // Update metadata
    existing.metadata = mergeTopLevelDicts(existing.metadata, newMessage.metadata);

    // Update original ROWID
    if (existing.originalROWID == null && newMessage.originalROWID != null) {
      existing.originalROWID = newMessage.originalROWID;
    }

    // Update attachments flag
    if (!existing.hasAttachments && newMessage.hasAttachments) {
      existing.hasAttachments = newMessage.hasAttachments;
    }

    // Update has reactions flag
    if (!existing.hasReactions && newMessage.hasReactions) {
      existing.hasReactions = newMessage.hasReactions;
    }

    // Update chat
    if (!existing.chat.hasValue && newMessage.chat.hasValue) {
      existing.chat.target = newMessage.chat.target;
    }

    // Update handle
    if (existing.handle?.id == null && newMessage.handle?.id != null) {
      existing.handle = newMessage.handle;
    }

    // Update attachments
    if (existing.dbAttachments.isEmpty && newMessage.dbAttachments.isNotEmpty) {
      existing.dbAttachments.addAll(newMessage.dbAttachments);
    }

    return existing;
  }

  /// Checks if Message [b] is newer than Message [a], based on date
  static bool isNewer(Message a, Message b) {
    if (a.id == null && b.id != null) return true;

    // Check all date created cases
    if (a.dateCreated == null && b.dateCreated != null) return true;
    if (a.dateCreated != null && b.dateCreated == null) return false;
    if (a.dateCreated!.millisecondsSinceEpoch < b.dateCreated!.millisecondsSinceEpoch) return true;
    if (a.dateCreated!.millisecondsSinceEpoch > b.dateCreated!.millisecondsSinceEpoch) return false;

    // Check all date delivered cases
    if (a.dateDelivered == null && b.dateDelivered != null) return true;
    if (a.dateDelivered != null && b.dateDelivered == null) return false;
    if (a.dateDelivered!.millisecondsSinceEpoch < b.dateDelivered!.millisecondsSinceEpoch) return true;
    if (a.dateDelivered!.millisecondsSinceEpoch > b.dateDelivered!.millisecondsSinceEpoch) return false;

    // Check all date read cases
    if (a.dateRead == null && b.dateRead != null) return true;
    if (a.dateRead != null && b.dateRead == null) return false;
    if (a.dateRead!.millisecondsSinceEpoch < b.dateRead!.millisecondsSinceEpoch) return true;
    if (a.dateRead!.millisecondsSinceEpoch > b.dateRead!.millisecondsSinceEpoch) return false;

    return false;
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
      "dateRead": (_dateRead.value == null) ? null : _dateRead.value!.millisecondsSinceEpoch,
      "dateDelivered": (_dateDelivered.value == null) ? null : _dateDelivered.value!.millisecondsSinceEpoch,
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
    if (includeObjects) {
      map['attachments'] = (attachments).map((e) => e!.toMap()).toList();
      map['handle'] = handle?.toMap();
    }
    return map;
  }
}
