import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Condition;
import 'package:metadata_fetch/metadata_fetch.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

/// Async method to fetch attachments
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

      for (final msg in inputMessages) {
        msg.chat.target = inputChat;
        msg.handle = handles.firstWhereOrNull((e) => e.originalROWID == msg.handleId);
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
        message.handle = handles.firstWhereOrNull((element) => element.originalROWID == message.handleId);

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
        final first = messages.first;
        if (first.id != null || kIsWeb) {
          isNewer = first.dateCreated!.isAfter(inputChat.latestMessage.dateCreated!);
          if (isNewer) {
            inputChat.latestMessage = first;
            if (!first.isFromMe! && !cm.isChatActive(inputChat.guid)) {
              inputChat.toggleHasUnread(true);
            }
          }
        }
      }

      return messages;
    });
  }
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
  DateTime? dateCreated;
  bool? isFromMe;
  // Data detector results
  bool? hasDdResults;
  DateTime? datePlayed;
  int? itemType;
  String? groupTitle;
  int? groupActionType;
  String? balloonBundleId;
  String? associatedMessageGuid;
  int? associatedMessagePart;
  String? associatedMessageType;
  String? expressiveSendStyleId;
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
  List<AttributedBody> attributedBody;
  List<MessageSummaryInfo> messageSummaryInfo;
  PayloadData? payloadData;
  bool hasApplePayloadData;
  bool wasDeliveredQuietly;
  bool didNotifyRecipient;

  final RxInt _error = RxInt(0);
  int get error => _error.value;
  set error(int i) => _error.value = i;

  final Rxn<DateTime> _dateRead = Rxn<DateTime>();
  DateTime? get dateRead => _dateRead.value;
  set dateRead(DateTime? d) => _dateRead.value = d;

  final Rxn<DateTime> _dateDelivered = Rxn<DateTime>();
  DateTime? get dateDelivered => _dateDelivered.value;
  set dateDelivered(DateTime? d) => _dateDelivered.value = d;

  final Rxn<DateTime> _dateEdited = Rxn<DateTime>();
  DateTime? get dateEdited => _dateEdited.value;
  set dateEdited(DateTime? d) => _dateEdited.value = d;

  @Backlink('message')
  final dbAttachments = ToMany<Attachment>();

  final chat = ToOne<Chat>();

  String? get dbAttributedBody => jsonEncode(attributedBody.map((e) => e.toMap()).toList());
  set dbAttributedBody(String? json) => attributedBody = json == null
      ? <AttributedBody>[] : (jsonDecode(json) as List).map((e) => AttributedBody.fromMap(e)).toList();

  String? get dbMessageSummaryInfo => jsonEncode(messageSummaryInfo.map((e) => e.toJson()).toList());
  set dbMessageSummaryInfo(String? json) => messageSummaryInfo = json == null
      ? <MessageSummaryInfo>[] : (jsonDecode(json) as List).map((e) => MessageSummaryInfo.fromJson(e)).toList();

  String? get dbPayloadData => payloadData == null
      ? null : jsonEncode(payloadData!.toJson());
  set dbPayloadData(String? json) => payloadData = json == null
      ? null : PayloadData.fromJson(jsonDecode(json));

  String? get dbMetadata => metadata == null
      ? null : jsonEncode(metadata);
  set dbMetadata(String? json) => metadata = json == null
      ? null : jsonDecode(json) as Map<String, dynamic>;

  Message({
    this.id,
    this.originalROWID,
    this.guid,
    this.handleId,
    this.otherHandle,
    this.text,
    this.subject,
    this.country,
    int? error,
    this.dateCreated,
    DateTime? dateRead,
    DateTime? dateDelivered,
    this.isFromMe = true,
    this.hasDdResults = false,
    this.datePlayed,
    this.itemType = 0,
    this.groupTitle,
    this.groupActionType = 0,
    this.balloonBundleId,
    this.associatedMessageGuid,
    this.associatedMessagePart,
    this.associatedMessageType,
    this.expressiveSendStyleId,
    this.handle,
    this.hasAttachments = false,
    this.hasReactions = false,
    this.attachments = const [],
    this.associatedMessages = const [],
    this.dateDeleted,
    this.metadata,
    this.threadOriginatorGuid,
    this.threadOriginatorPart,
    this.attributedBody = const [],
    this.messageSummaryInfo = const [],
    this.payloadData,
    this.hasApplePayloadData = false,
    DateTime? dateEdited,
    this.wasDeliveredQuietly = false,
    this.didNotifyRecipient = false,
  }) {
      if (error != null) _error.value = error;
      if (dateRead != null) _dateRead.value = dateRead;
      if (dateDelivered != null) _dateDelivered.value = dateDelivered;
      if (dateEdited != null) _dateEdited.value = dateEdited;
      if (attachments.isEmpty) attachments = [];
      if (associatedMessages.isEmpty) associatedMessages = [];
      if (attributedBody.isEmpty) attributedBody = [];
      if (messageSummaryInfo.isEmpty) messageSummaryInfo = [];
  }

  factory Message.fromMap(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List? ?? []).map((a) => Attachment.fromMap(a)).toList();

    List<AttributedBody> attributedBody = [];
    if (json["attributedBody"] != null) {
      if (json['attributedBody'] is Map) {
        json['attributedBody'] = [json['attributedBody']];
      }
      try {
        attributedBody = (json['attributedBody'] as List).map((a) => AttributedBody.fromMap(a)).toList();
      } catch (e) {
        Logger.error('Failed to parse attributed body! $e');
      }
    }

    Map<String, dynamic> metadata = {};
    if (!isNullOrEmpty(json["metadata"])!) {
      if (json["metadata"] is String) {
        try {
          metadata = jsonDecode(json["metadata"]);
        } catch (_) {}
      } else {
        metadata = json["metadata"];
      }
    }

    List<MessageSummaryInfo> msi = [];
    try {
      msi = (json['messageSummaryInfo'] as List? ?? []).map((e) => MessageSummaryInfo.fromJson(e)).toList();
    } catch (e) {
      Logger.error('Failed to parse summary info! $e');
    }

    PayloadData? payloadData;
    try {
      payloadData = json['payloadData'] == null ? null : PayloadData.fromJson(json['payloadData']);
    } catch (e) {
      Logger.error('Failed to parse payload data! $e');
    }

    return Message(
      id: json["ROWID"] ?? json['id'],
      originalROWID: json["originalROWID"],
      guid: json["guid"],
      handleId: json["handleId"] ?? 0,
      otherHandle: json["otherHandle"],
      text: sanitizeString(json["text"] ?? attributedBody.firstOrNull?.string),
      subject: json["subject"],
      country: json["country"],
      error: json["error"] ?? json["_error"] ?? 0,
      dateCreated: parseDate(json["dateCreated"]),
      dateRead: parseDate(json["dateRead"]),
      dateDelivered: parseDate(json["dateDelivered"]),
      isFromMe: json['isFromMe'] == true,
      hasDdResults: json['hasDdResults'] == true,
      datePlayed: parseDate(json["datePlayed"]),
      itemType: json["itemType"],
      groupTitle: json["groupTitle"],
      groupActionType: json["groupActionType"] ?? 0,
      balloonBundleId: json["balloonBundleId"],
      associatedMessageGuid: json["associatedMessageGuid"]?.toString().replaceAll("bp:", "").split("/").last,
      associatedMessagePart: json["associatedMessagePart"] ?? int.tryParse(json["associatedMessageGuid"].toString().replaceAll("p:", "").split("/").first),
      associatedMessageType: json["associatedMessageType"],
      expressiveSendStyleId: json["expressiveSendStyleId"],
      handle: json['handle'] != null ? Handle.fromMap(json['handle']) : null,
      hasAttachments: attachments.isNotEmpty || json['hasAttachments'] == true,
      attachments: (json['attachments'] as List? ?? []).map((a) => Attachment.fromMap(a)).toList(),
      hasReactions: json['hasReactions'] == true,
      dateDeleted: parseDate(json["dateDeleted"]),
      metadata: metadata is String ? null : metadata,
      threadOriginatorGuid: json['threadOriginatorGuid'],
      threadOriginatorPart: json['threadOriginatorPart'],
      attributedBody: attributedBody,
      messageSummaryInfo: msi,
      payloadData: payloadData,
      hasApplePayloadData: json['hasApplePayloadData'] == true || payloadData != null,
      dateEdited: parseDate(json["dateEdited"]),
      wasDeliveredQuietly: json['wasDeliveredQuietly'] ?? false,
      didNotifyRecipient: json['didNotifyRecipient'] ?? false,
    );
  }

  /// Save a single message - prefer [bulkSave] for multiple messages rather
  /// than iterating through them
  Message save({Chat? chat}) {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      Message? existing = Message.findOne(guid: guid);
      if (existing != null) {
        id = existing.id;
        text ??= existing.text;
      }

      // Save the participant & set the handle ID to the new participant
      if (handle == null && handleId != null) {
        handle = Handle.findOne(originalROWID: handleId);
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
          m.text ??= existingMessage.text;
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
  static Future<Message> replaceMessage(String? oldGuid, Message newMessage) async {
    Message? existing = Message.findOne(guid: oldGuid);
    if (existing == null) {
      throw Exception("Cannot replace on a null existing message!!");
    }

    // We just need to update the timestamps & error
    if (existing.guid != newMessage.guid) {
      existing.guid = newMessage.guid;
    }
    existing._dateDelivered.value = newMessage._dateDelivered.value ?? existing._dateDelivered.value;
    existing._dateRead.value = newMessage._dateRead.value ?? existing._dateRead.value;
    existing._dateEdited.value = newMessage._dateEdited.value ?? existing._dateEdited.value;
    existing.attributedBody = newMessage.attributedBody.isNotEmpty ? newMessage.attributedBody : existing.attributedBody;
    existing.messageSummaryInfo = newMessage.messageSummaryInfo.isNotEmpty ? newMessage.messageSummaryInfo : existing.messageSummaryInfo;
    existing.payloadData = newMessage.payloadData ?? existing.payloadData;
    existing.wasDeliveredQuietly = newMessage.wasDeliveredQuietly ? newMessage.wasDeliveredQuietly : existing.wasDeliveredQuietly;
    existing.didNotifyRecipient = newMessage.didNotifyRecipient ? newMessage.didNotifyRecipient : existing.didNotifyRecipient;
    existing._error.value = newMessage._error.value;

    try {
      messageBox.put(existing, mode: PutMode.update);
    } catch (ex) {
      Logger.error('Failed to replace message! This is likely due to a unique constraint being violated. See error below:');
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

  /// Fetch attachments for a single message. Prefer using [fetchAttachmentsByMessages]
  /// or [fetchAttachmentsByMessagesAsync] when working with a list of messages.
  List<Attachment?>? fetchAttachments({ChatLifecycleManager? currentChat}) {
    if (attachments.isNotEmpty) {
      return attachments;
    }

    return store.runInTransaction(TxMode.read, () {
      attachments = dbAttachments;
      return attachments;
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
  Message fetchAssociatedMessages({MessagesService? service, bool shouldRefresh = false}) {
    associatedMessages = Message.find(cond: Message_.associatedMessageGuid.equals(guid ?? ""));
    associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
    if (threadOriginatorGuid != null) {
      final existing = service?.struct.getMessage(threadOriginatorGuid!);
      final threadOriginator = existing ?? Message.findOne(guid: threadOriginatorGuid);
      threadOriginator?.handle ??= threadOriginator.getHandle();
      if (threadOriginator != null) associatedMessages.add(threadOriginator);
      if (existing == null && threadOriginator != null) service?.struct.addThreadOriginator(threadOriginator);
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    return this;
  }

  Handle? getHandle() {
    if (kIsWeb || handleId == 0 || handleId == null) return null;
    return Handle.findOne(originalROWID: handleId!);
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

  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)!).join("\n"));

  // first condition is for macOS < 11 and second condition is for macOS >= 11
  bool get isLegacyUrlPreview => (balloonBundleId == "com.apple.messages.URLBalloonProvider" && hasDdResults!)
      || (hasDdResults! && (text ?? "").trim().isURL);

  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);

  bool get isInteractive => balloonBundleId != null && !isLegacyUrlPreview;

  String get interactiveText {
    String text = "";
    final temp = balloonBundleIdMap[balloonBundleId?.split(":").first] ?? (balloonBundleId?.split(":").first ?? "Unknown");
    if (temp is Map) {
      text = temp[balloonBundleId?.split(":").last] ?? ((balloonBundleId?.split(":").last ?? "Unknown"));
    } else {
      text = temp.toString();
    }
    return text;
  }

  bool get isGroupEvent => groupTitle != null || (itemType ?? 0) > 0 || (groupActionType ?? 0) > 0;

  String get groupEventText {
    String text = "Unknown group event";
    String name = handle?.displayName ?? "You";

    String? other = "someone";
    if (otherHandle != null && isParticipantEvent) {
      other = Handle.findOne(originalROWID: otherHandle)?.displayName;
    }

    if (itemType == 1) {
      if (groupActionType == 0) {
        text = "$name added $other to the conversation";
      } else if (groupActionType == 1) {
        text = "$name removed $other from the conversation";
      }
    } else if (itemType == 2) {
      if (groupTitle != null) {
        text = "$name named the conversation \"$groupTitle\"";
      } else {
        text = "$name removed the name from the conversation";
      }
    } else if (itemType == 3) {
      if (groupActionType == null || groupActionType == 0) {
        text = "$name left the conversation";
      } else if (groupActionType == 1) {
        text = "$name changed the group photo";
      } else if (groupActionType == 2) {
        text = "$name removed the group photo";
      }
    } else if (itemType == 4 && groupActionType == 0) {
      text = "$name shared ${name == "You" ? "your" : "their"} location";
    } else if (itemType == 6) {
      text = "$name started a FaceTime call";
    }

    return text;
  }

  bool get isParticipantEvent => isGroupEvent && ((itemType == 1 && [0, 1].contains(groupActionType)) || [2, 3].contains(itemType));

  bool get isBigEmoji => bigEmoji ?? MessageHelper.shouldShowBigEmoji(fullText);

  List<Attachment> get realAttachments => attachments.where((e) => e != null && e.mimeType != null).cast<Attachment>().toList();

  List<Attachment> get previewAttachments => attachments.where((e) => e != null && e.mimeType == null).cast<Attachment>().toList();

  List<Message> get reactions => associatedMessages.where((item) =>
      ReactionTypes.toList().contains(item.associatedMessageType?.replaceAll("-", ""))).toList();

  Indicator get indicatorToShow {
    if (!isFromMe!) return Indicator.NONE;
    if (dateRead != null) return Indicator.READ;
    if (dateDelivered != null) return Indicator.DELIVERED;
    if (dateCreated != null) return Indicator.SENT;
    return Indicator.NONE;
  }

  bool showTail(Message? newer) {
    // if there is no newer, or if the newer is a different sender
    if (newer == null || !sameSender(newer) || newer.isGroupEvent) return true;
    // if newer is over a minute newer
    return newer.dateCreated!.difference(dateCreated!).inMinutes.abs() > 1;
  }

  bool sameSender(Message? other) {
    return (isFromMe! && isFromMe == other?.isFromMe) || (!isFromMe! && !(other?.isFromMe ?? true) && handleId == other?.handleId);
  }

  void generateTempGuid() {
    guid = "temp-${randomString(8)}";
  }

  /// Find how many messages exist in the DB for a chat
  static int? countForChat(Chat? chat) {
    if (kIsWeb || chat == null || chat.id == null) return 0;
    return chat.messages.length;
  }

  Message mergeWith(Message otherMessage) {
    return Message.merge(this, otherMessage);
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

  int get normalizedThreadPart => threadOriginatorPart == null ? 0 : int.parse(threadOriginatorPart![0]);

  bool connectToUpper() => threadOriginatorGuid != null;

  bool showUpperMessage(Message olderMessage) {
    // find the part count of the older message
    final olderPartCount = getActiveMwc(olderMessage.guid!)?.parts.length ?? 1;
    // make sure the older message is none of the following:
    // 1) thread originator
    // 2) part of the thread with the same thread partIndex
    // OR
    // 1) It is the thread originator but the part is not the last part of the older message
    // 2) It is part of the thread but has multiple parts
    return (olderMessage.guid != threadOriginatorGuid && (olderMessage.threadOriginatorGuid != threadOriginatorGuid || olderMessage.normalizedThreadPart != normalizedThreadPart))
        || (olderMessage.guid == threadOriginatorGuid && normalizedThreadPart != olderPartCount - 1)
        || (olderMessage.threadOriginatorGuid == threadOriginatorGuid && olderPartCount > 1);
  }

  bool connectToLower(Message newerMessage) {
    final thisPartCount = getActiveMwc(guid!)?.parts.length ?? 1;
    if (newerMessage.isFromMe != isFromMe) return false;
    if (newerMessage.normalizedThreadPart != thisPartCount - 1) return false;
    if (threadOriginatorGuid != null) {
      return newerMessage.threadOriginatorGuid == threadOriginatorGuid;
    } else {
      return newerMessage.threadOriginatorGuid == guid;
    }
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
    if (MessagesService.cachedBubbleSizes[guid!] != null) return MessagesService.cachedBubbleSizes[guid!]!;
    // if attachment, then grab width / height
    if (fullText.isEmpty && (attachments).isNotEmpty) {
      return Size(
          attachments
              .map((e) => e!.width)
              .fold(0, (p, e) => max(p, (e ?? ns.width(context) / 2).toDouble()) + 28),
          attachments
              .map((e) => e!.height)
              .fold(0, (p, e) => max(p, (e ?? ns.width(context) / 2).toDouble())));
    }
    // initialize constraints for text rendering
    final fontSizeFactor = isBigEmoji ? bigEmojiScaleFactor : 1.0;
    final constraints = BoxConstraints(
      maxWidth: maxWidthOverride ?? ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
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
    if (isLegacyUrlPreview) {
      size = Size(ns.width(context) * 2 / 3 - 30, size.height);
    }
    // if we have reactions, account for the extra height they add
    if (hasReactions) {
      size = Size(size.width, size.height + 25);
    }
    // add 16 to the height to account for container margins
    size = Size(size.width, size.height + 16);
    // cache the value
    MessagesService.cachedBubbleSizes[guid!] = size;
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

    // Update date edited (and attr body & message summary info)
    if ((existing.dateEdited == null && newMessage.dateEdited != null) ||
        (existing.dateEdited != null &&
            newMessage.dateEdited != null &&
            existing.dateEdited!.millisecondsSinceEpoch < newMessage.dateEdited!.millisecondsSinceEpoch)) {
      existing.dateEdited = newMessage.dateEdited;
      if (!isNullOrEmpty(newMessage.attributedBody)!) {
        existing.attributedBody = newMessage.attributedBody;
      }
      if (!isNullOrEmpty(newMessage.messageSummaryInfo)!) {
        existing.messageSummaryInfo = newMessage.messageSummaryInfo;
      }
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

    if (existing.payloadData == null && newMessage.payloadData != null) {
      existing.payloadData = newMessage.payloadData;
    }

    if (!existing.wasDeliveredQuietly && newMessage.wasDeliveredQuietly) {
      existing.wasDeliveredQuietly = newMessage.wasDeliveredQuietly;
    }

    if (!existing.didNotifyRecipient && newMessage.didNotifyRecipient) {
      existing.didNotifyRecipient = newMessage.didNotifyRecipient;
    }

    return existing;
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
      "dateCreated": dateCreated?.millisecondsSinceEpoch,
      "dateRead": _dateRead.value?.millisecondsSinceEpoch,
      "dateDelivered":  _dateDelivered.value?.millisecondsSinceEpoch,
      "isFromMe": isFromMe!,
      "hasDdResults": hasDdResults!,
      "datePlayed": datePlayed?.millisecondsSinceEpoch,
      "itemType": itemType,
      "groupTitle": groupTitle,
      "groupActionType": groupActionType,
      "balloonBundleId": balloonBundleId,
      "associatedMessageGuid": associatedMessageGuid,
      "associatedMessagePart": associatedMessagePart,
      "associatedMessageType": associatedMessageType,
      "expressiveSendStyleId": expressiveSendStyleId,
      "handle": handle?.toMap(includeObjects: true),
      "hasAttachments": hasAttachments,
      "hasReactions": hasReactions,
      "dateDeleted": dateDeleted?.millisecondsSinceEpoch,
      "metadata": jsonEncode(metadata),
      "threadOriginatorGuid": threadOriginatorGuid,
      "threadOriginatorPart": threadOriginatorPart,
      "hasApplePayloadData": hasApplePayloadData,
      "dateEdited": dateEdited?.millisecondsSinceEpoch,
      "wasDeliveredQuietly": wasDeliveredQuietly,
      "didNotifyRecipient": didNotifyRecipient,
    };
    if (includeObjects) {
      map['attachments'] = (attachments).map((e) => e!.toMap()).toList();
      map['handle'] = handle?.toMap();
      map['attributedBody'] = attributedBody.map((e) => e.toMap()).toList();
      map['messageSummaryInfo'] = messageSummaryInfo.map((e) => e.toJson()).toList();
      map['payloadData'] = payloadData?.toJson();
    }
    return map;
  }
}
