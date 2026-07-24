import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/message_interface.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Condition;
import 'package:metadata_fetch/metadata_fetch.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class Message {
  int? id;
  int? originalROWID;

  @Index(type: IndexType.value)
  @Unique()
  String? guid;

  int? handleId;
  int? otherHandle;
  String? text;
  String? subject;
  String? country;

  @Index()
  DateTime? dateCreated;

  bool? isFromMe;
  // Data detector results
  bool? hasDdResults;
  DateTime? datePlayed;
  bool hasEffectPlayed;
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

  // Phase 1: Add ToOne relationship for Handle
  // This will eventually replace the embedded Handle object above
  final handleRelation = ToOne<Handle>();
  DateTime? dateDeleted;
  Map<String, dynamic>? metadata;
  String? threadOriginatorGuid;
  String? threadOriginatorPart;

  List<Message> associatedMessages = [];
  bool? bigEmoji;
  List<AttributedBody> attributedBody;
  List<MessageSummaryInfo> messageSummaryInfo;
  PayloadData? payloadData;
  bool hasApplePayloadData;
  bool wasDeliveredQuietly;
  bool didNotifyRecipient;
  bool isBookmarked;

  final RxInt _error = RxInt(0);
  int get error => _error.value;
  set error(int i) => _error.value = i;

  /// Human-readable description of the send error. Populated by the client
  /// for client-side failures and by [serverErrorMessage] for server-side ones.
  String? errorMessage;

  final Rxn<DateTime> _dateRead = Rxn<DateTime>();
  DateTime? get dateRead => _dateRead.value;
  set dateRead(DateTime? d) => _dateRead.value = d;

  final Rxn<DateTime> _dateDelivered = Rxn<DateTime>();
  DateTime? get dateDelivered => _dateDelivered.value;
  set dateDelivered(DateTime? d) => _dateDelivered.value = d;

  final RxBool _isDelivered = RxBool(false);
  bool get isDelivered => (dateDelivered != null) ? true : _isDelivered.value;
  set isDelivered(bool b) => _isDelivered.value = b;

  final Rxn<DateTime> _dateEdited = Rxn<DateTime>();
  DateTime? get dateEdited => _dateEdited.value;
  set dateEdited(DateTime? d) => _dateEdited.value = d;

  /// Parts that have been unsent/retracted, as reported by [messageSummaryInfo].
  List<int> get retractedParts => messageSummaryInfo.firstOrNull?.retractedParts ?? [];

  /// True when this message has at least one retracted part.
  bool get hasUnsentParts => dateEdited != null && retractedParts.isNotEmpty;

  @Backlink('message')
  final dbAttachments = ToMany<Attachment>();

  final chat = ToOne<Chat>();

  String? get dbAttributedBody => jsonEncode(attributedBody.map((e) => e.toMap()).toList());
  set dbAttributedBody(String? json) => attributedBody =
      json == null ? <AttributedBody>[] : (jsonDecode(json) as List).map((e) => AttributedBody.fromMap(e)).toList();

  String? get dbMessageSummaryInfo => jsonEncode(messageSummaryInfo.map((e) => e.toJson()).toList());
  set dbMessageSummaryInfo(String? json) => messageSummaryInfo = json == null
      ? <MessageSummaryInfo>[]
      : (jsonDecode(json) as List).map((e) => MessageSummaryInfo.fromJson(e)).toList();

  String? get dbPayloadData => payloadData == null ? null : jsonEncode(payloadData!.toJson());
  set dbPayloadData(String? json) => payloadData = json == null ? null : PayloadData.fromJson(jsonDecode(json));

  String? get dbMetadata => metadata == null ? null : jsonEncode(metadata);
  set dbMetadata(String? json) => metadata = json == null ? null : jsonDecode(json) as Map<String, dynamic>;

  @Transient()
  bool get isKeptAudio => itemType == 5 && subject != null;

  // It's outgoing from this device is the guid starts with "temp" and isFromMe is true.
  // A temp GUID is only assigned to outgoing messages before they are sent to the server.
  @Transient()
  bool get isSending => isFromMe == true && guid != null && guid!.startsWith("temp");

  @Transient()
  bool get isSticker => associatedMessageType == "sticker" && associatedMessageGuid != null;

  @Transient()
  bool get isNameChange => itemType == 2;

  @Transient()
  bool get isGroupPhotoEvent => itemType == 3 && (groupActionType ?? 0) > 0;

  @Transient()
  bool get isGroupPhotoChanged => itemType == 3 && groupActionType == 1;

  @Transient()
  bool get isGroupPhotoRemoved => itemType == 3 && groupActionType == 2;

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
    this.errorMessage,
    this.dateCreated,
    DateTime? dateRead,
    DateTime? dateDelivered,
    bool? isDelievered,
    this.isFromMe = true,
    this.hasDdResults = false,
    this.datePlayed,
    this.hasEffectPlayed = false,
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
    this.isBookmarked = false,
  }) {
    if (error != null) _error.value = error;
    if (dateRead != null) _dateRead.value = dateRead;
    if (dateDelivered != null) _dateDelivered.value = dateDelivered;
    if (dateEdited != null) _dateEdited.value = dateEdited;
    if (isDelievered != null) _isDelivered.value = isDelievered;
    if (associatedMessages.isEmpty) associatedMessages = [];
    if (attributedBody.isEmpty) attributedBody = [];
    if (messageSummaryInfo.isEmpty) messageSummaryInfo = [];
  }

  factory Message.fromMap(Map<String, dynamic> json) {
    List<AttributedBody> attributedBody = [];
    if (json["attributedBody"] != null) {
      if (json['attributedBody'] is Map) {
        json['attributedBody'] = [json['attributedBody']!.cast<String, Object>()];
      }
      try {
        attributedBody =
            (json['attributedBody'] as List).map((a) => AttributedBody.fromMap(a!.cast<String, Object>())).toList();
      } catch (e, stack) {
        Logger.error('Failed to parse attributed body!', error: e, trace: stack);
      }
    }

    Map<String, dynamic> metadata = {};
    if (!isNullOrEmpty(json["metadata"])) {
      if (json["metadata"] is String) {
        try {
          metadata = jsonDecode(json["metadata"]);
        } catch (_) {}
      } else {
        metadata = json["metadata"]?.cast<String, Object>();
      }
    }

    List<MessageSummaryInfo> msi = [];
    try {
      msi = (json['messageSummaryInfo'] as List? ?? [])
          .map((e) => MessageSummaryInfo.fromJson(e!.cast<String, Object>()))
          .toList();
    } catch (e, stack) {
      Logger.error('Failed to parse summary info!', error: e, trace: stack);
    }

    PayloadData? payloadData;
    try {
      payloadData = json['payloadData'] == null ? null : PayloadData.fromJson(json['payloadData']);
    } catch (e, s) {
      Logger.error('Failed to parse payload data!', error: e, trace: s);
    }

    return Message(
      id: json["ROWID"] ?? json['id'],
      originalROWID: json["originalROWID"],
      guid: json["guid"],
      handleId: json["handleId"] ?? 0,
      otherHandle: json["otherHandle"],
      text: sanitizeString(attributedBody.firstOrNull?.string ?? json["text"]),
      subject: json["subject"],
      country: json["country"],
      error: json["error"] ?? json["_error"] ?? 0,
      errorMessage: json['errorMessage'] as String?,
      dateCreated: parseDate(json["dateCreated"]),
      dateRead: parseDate(json["dateRead"]),
      dateDelivered: parseDate(json["dateDelivered"]),
      isDelievered: json["isDelivered"] ?? false,
      isFromMe: json['isFromMe'] == true,
      hasDdResults: json['hasDdResults'] == true,
      datePlayed: parseDate(json["datePlayed"]),
      itemType: json["itemType"],
      groupTitle: json["groupTitle"],
      groupActionType: json["groupActionType"] ?? 0,
      balloonBundleId: json["balloonBundleId"],
      associatedMessageGuid: json["associatedMessageGuid"]?.toString().replaceAll("bp:", "").split("/").last,
      associatedMessagePart: json["associatedMessagePart"] ??
          int.tryParse(json["associatedMessageGuid"].toString().replaceAll("p:", "").split("/").first),
      associatedMessageType: json["associatedMessageType"],
      expressiveSendStyleId: json["expressiveSendStyleId"],
      handle: json['handle'] != null ? Handle.fromMap(json['handle']!.cast<String, Object>()) : null,
      hasAttachments: (json['attachments'] as List? ?? []).isNotEmpty || json['hasAttachments'] == true,
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
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }

  /// Save a single message - prefer [bulkSave] for multiple messages rather
  /// than iterating through them
  Message save({Chat? chat, bool updateIsBookmarked = false}) {
    if (kIsWeb) return this;
    Database.runInTransaction(TxMode.write, () {
      Message? existing = Message.findOne(guid: guid);
      if (existing != null) {
        id = existing.id;
        text ??= existing.text;

        // Phase 2: Preserve the handle relationship from existing message
        if (existing.handleRelation.hasValue) {
          handleRelation.target = existing.handleRelation.target;
        }

        // Preserve the chat relationship from the existing message
        if (chat == null && !this.chat.hasValue && existing.chat.hasValue) {
          this.chat.target = existing.chat.target;
        }
      }

      // Phase 2: Set up handle relationship if we have a handle
      if (handle != null && !handleRelation.hasValue) {
        if (handle!.id != null) {
          handleRelation.targetId = handle!.id!;
        } else if (handleId != null) {
          final foundHandle = Handle.findOne(originalROWID: handleId);
          if (foundHandle != null) {
            handleRelation.target = foundHandle;
          }
        }
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
      if (!updateIsBookmarked) {
        isBookmarked = existing?.isBookmarked ?? isBookmarked;
      }

      try {
        if (chat != null) this.chat.target = chat;

        // CRITICAL: Preserve dbAttachments ToMany relationship
        // ObjectBox will clear ToMany relationships on put() if not explicitly preserved
        final attachmentsToPreserve = List<Attachment>.from(dbAttachments);

        id = Database.messages.put(this);

        // Restore attachments after put
        if (attachmentsToPreserve.isNotEmpty) {
          dbAttachments.clear();
          dbAttachments.addAll(attachmentsToPreserve);
          dbAttachments.applyToDb();
        }
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  Future<Message> saveAsync({Chat? chat, bool updateIsBookmarked = false}) async {
    if (kIsWeb) return this;

    final result = await MessageInterface.saveMessageAsync(
      messageData: toMap(),
      chatData: chat?.toMap(),
      updateIsBookmarked: updateIsBookmarked,
    );

    if (result != null) {
      id = result.id;
    }
    return this;
  }

  /// Replace a temp message with the message from the server
  static Future<Message> replaceMessage(String? oldGuid, Message newMessage) async {
    if (kIsWeb) throw Exception("Web does not support replacing messages!");

    return await MessageInterface.replaceMessage(
      oldGuid: oldGuid,
      newMessageData: newMessage.toMap(),
    );
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

  Message setEffectPlayed() {
    hasEffectPlayed = true;
    save();
    return this;
  }

  /// Fetch reactions
  Future<Message> fetchAssociatedMessages({MessagesService? service, bool shouldRefresh = false}) async {
    if (kIsWeb) return this;

    final result = await MessageInterface.fetchAssociatedMessagesAsync(
      messageGuid: guid!,
      messageId: id,
      threadOriginatorGuid: threadOriginatorGuid,
    );

    final associatedMessagesData = (result['associatedMessages'] as List).cast<Map<String, dynamic>>();
    associatedMessages = associatedMessagesData.map((e) => Message.fromMap(e)).toList();

    // Check if we need to add the thread originator from the service's struct
    if (threadOriginatorGuid != null) {
      final existing = service?.struct.getMessage(threadOriginatorGuid!);
      if (existing != null && !associatedMessages.any((m) => m.guid == threadOriginatorGuid)) {
        associatedMessages.add(existing);
      } else if (existing == null && associatedMessages.any((m) => m.guid == threadOriginatorGuid)) {
        final threadOriginator = associatedMessages.firstWhere((m) => m.guid == threadOriginatorGuid);
        service?.struct.addThreadOriginator(threadOriginator);
      }
    }

    return this;
  }

  Handle? getHandle() {
    // Phase 2: Prefer ToOne relationship if available
    if (handleRelation.target != null) return handleRelation.target;

    // Fallback to manual lookup for backward compatibility
    if (kIsWeb || handleId == 0 || handleId == null) return null;
    return Handle.findOne(originalROWID: handleId!);
  }

  static Message? findOne({String? guid, String? associatedMessageGuid}) {
    if (kIsWeb) return null;
    if (guid != null) {
      final query = Database.messages.query(Message_.guid.equals(guid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (associatedMessageGuid != null) {
      final query = Database.messages.query(Message_.associatedMessageGuid.equals(associatedMessageGuid)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static Future<Message?> findOneAsync({String? guid, String? associatedMessageGuid}) async {
    if (kIsWeb) return null;

    final result = await MessageInterface.findOneAsync(
      guid: guid,
      associatedMessageGuid: associatedMessageGuid,
    );

    return result;
  }

  /// Find a list of messages by the specified condition, or return all messages
  /// when no condition is specified
  static List<Message> find({Condition<Message>? cond}) {
    final query = Database.messages.query(cond).build();
    return query.find();
  }

  static Future<List<Message>> findAsync({Condition<Message>? cond}) async {
    if (kIsWeb) return [];

    // Note: For now, we pass null for conditionJson since serializing ObjectBox Condition
    // is complex. This will return all messages. Future enhancement can add condition serialization.
    return await MessageInterface.findAsync(
      conditionJson: null,
    );
  }

  /// Delete a message and remove all instances of that message in the DB
  static Future<void> delete(String guid) async {
    if (kIsWeb) return;
    await MessageInterface.deleteMessage(guid: guid);
  }

  static Future<void> softDelete(String guid) async {
    if (kIsWeb) return;
    await MessageInterface.softDeleteMessage(guid: guid);
  }

  /// This is purely because some Macs incorrectly report the dateCreated time
  static int sort(Message a, Message b, {bool descending = true}) {
    late DateTime aDateToUse;

    if (a.dateDelivered == null) {
      aDateToUse = a.dateCreated!;
    } else {
      aDateToUse = a.dateCreated!.isBefore(a.dateDelivered!) ? a.dateCreated! : a.dateDelivered!;
    }

    late DateTime bDateToUse;
    if (b.dateDelivered == null) {
      bDateToUse = b.dateCreated!;
    } else {
      bDateToUse = b.dateCreated!.isBefore(b.dateDelivered!) ? b.dateCreated! : b.dateDelivered!;
    }

    return descending ? bDateToUse.compareTo(aDateToUse) : aDateToUse.compareTo(bDateToUse);
  }

  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)).join("\n"));

  // first condition is for macOS < 11 and second condition is for macOS >= 11
  bool get isLegacyUrlPreview =>
      (balloonBundleId == "com.apple.messages.URLBalloonProvider" && hasDdResults!) ||
      ((hasDdResults! || isFromMe!) && (text ?? "").trim().isURL);

  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);

  bool get isInteractive => balloonBundleId != null && !isLegacyUrlPreview;

  String get interactiveText {
    String text = "";

    if (payloadData?.urlData != null && payloadData!.urlData!.isNotEmpty && payloadData?.urlData?.first.url != null) {
      final uri = Uri.parse(payloadData!.urlData!.first.url!);
      return "Website: ${payloadData!.urlData!.first.title} (${uri.host.replaceFirst('www.', '')})";
    }

    final temp =
        balloonBundleIdMap[balloonBundleId?.split(":").first] ?? (balloonBundleId?.split(":").first ?? "Unknown");
    if (temp is Map) {
      text = temp[balloonBundleId?.split(":").last] ?? ((balloonBundleId?.split(":").last ?? "Unknown"));
    } else {
      text = temp.toString();
    }
    return text;
  }

  String? get interactiveMediaPath {
    final extension = balloonBundleId!.contains("com.apple.Digital")
        ? ".mov"
        : balloonBundleId!.contains("com.apple.Handwriting")
            ? ".png"
            : null;
    return "${FilesystemSvc.messagesPath}/$guid/embedded-media/$balloonBundleId$extension";
  }

  bool get isGroupEvent => groupTitle != null || (itemType ?? 0) > 0 || (groupActionType ?? 0) > 0;

  /// Resolved sender name for the group event — prefers [handleRelation.target]
  /// over the transient [handle] field since ObjectBox hydrates the relation, not
  /// the transient field.
  String get groupEventText {
    final h = handle ?? handleRelation.target;
    final name = h?.displayName ?? (isFromMe! || handleRelation.target == null ? 'You' : 'Unknown');
    return buildGroupEventText(name);
  }

  /// Build the group-event description string with a pre-resolved [senderName].
  /// Call this from the UI with a reactive name (e.g. from [HandleState.displayName])
  /// so that contact-sync updates are reflected without rebuilding the whole tree.
  String buildGroupEventText(String senderName) {
    String text = "Unknown group event";
    final name = senderName;

    String? other = "someone";
    if (otherHandle != null && isParticipantEvent) {
      // Keep the "someone" fallback if the handle isn't in the DB yet.
      other = Handle.findOne(originalROWID: otherHandle)?.displayName ?? other;
    }

    if (itemType == 1) {
      if (groupActionType == 0) {
        text = "$name added $other to the conversation.";
      } else if (groupActionType == 1) {
        text = "$name removed $other from the conversation.";
      }
    } else if (itemType == 2) {
      if (groupTitle != null) {
        text = "$name named the conversation \"$groupTitle\".";
      } else {
        text = "$name removed the name from the conversation.";
      }
    } else if (itemType == 3) {
      if (groupActionType == null || groupActionType == 0) {
        text = "$name left the conversation.";
      } else if (groupActionType == 1) {
        text = "$name changed the group photo.";
      } else if (groupActionType == 2) {
        text = "$name removed the group photo.";
      }
    } else if (itemType == 4 && groupActionType == 0) {
      text = "$name shared ${name == "You" ? "your" : "their"} location.";
    } else if (itemType == 5) {
      text = "$name kept an audio message.";
    } else if (itemType == 6) {
      text = "$name started a FaceTime call.";
    }

    return text;
  }

  bool get isParticipantEvent =>
      isGroupEvent && ((itemType == 1 && [0, 1].contains(groupActionType)) || [2, 3].contains(itemType));

  bool get isBigEmoji => bigEmoji ?? MessageHelper.shouldShowBigEmoji(fullText);

  List<Attachment> get realAttachments => dbAttachments.where((e) => e.mimeType != null).toList();

  List<Attachment> get previewAttachments => dbAttachments.where((e) => e.mimeType == null).toList();

  List<Message> get reactions => associatedMessages
      .where((item) => ReactionTypes.toList().contains(item.associatedMessageType?.replaceAll("-", "")))
      .toList();

  MessageStatusIndicator get indicatorToShow {
    if (!isFromMe!) return MessageStatusIndicator.NONE;
    if (dateRead != null) return MessageStatusIndicator.READ;
    if (isDelivered) return MessageStatusIndicator.DELIVERED;
    if (dateDelivered != null) return MessageStatusIndicator.DELIVERED;
    if (dateCreated != null) return MessageStatusIndicator.SENT;
    return MessageStatusIndicator.NONE;
  }

  bool get hasAudioTranscript => attributedBody.any((i) => i.runs.any((e) => e.attributes?.audioTranscript != null));

  bool showTail(Message? newer) {
    // if there is no newer, or if the newer is a different sender
    if (newer == null || !sameSender(newer) || newer.isGroupEvent) return true;
    // if newer is over a minute newer
    return newer.dateCreated!.difference(dateCreated!).inMinutes.abs() > 1;
  }

  bool sameSender(Message? other) {
    return (isFromMe! && isFromMe == other?.isFromMe) ||
        (!isFromMe! && !(other?.isFromMe ?? true) && handleId == other?.handleId);
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
        getLineType(olderMessage, threadOriginator) == LineType.otherToOther) {
      return false;
    }
    // if the lower message isn't from me, then draw the connecting line
    // (if the message is from me, that message will draw a connecting line up
    // rather than this message drawing one downwards).
    return isFromMe != newerMessage.isFromMe;
  }

  int get normalizedThreadPart => threadOriginatorPart == null ? 0 : int.parse(threadOriginatorPart![0]);

  bool connectToUpper() => threadOriginatorGuid != null;

  bool showUpperMessage(Message olderMessage) {
    // find the part count of the older message
    final olderPartCount = chat.target?.guid != null
        ? maybeFindMessagesSvc(chat.target!.guid)?.getMessageStateIfExists(olderMessage.guid!)?.parts.length ?? 1
        : 1;
    // make sure the older message is none of the following:
    // 1) thread originator
    // 2) part of the thread with the same thread partIndex
    // OR
    // 1) It is the thread originator but the part is not the last part of the older message
    // 2) It is part of the thread but has multiple parts
    return (olderMessage.guid != threadOriginatorGuid &&
            (olderMessage.threadOriginatorGuid != threadOriginatorGuid ||
                olderMessage.normalizedThreadPart != normalizedThreadPart)) ||
        (olderMessage.guid == threadOriginatorGuid && normalizedThreadPart != olderPartCount - 1) ||
        (olderMessage.threadOriginatorGuid == threadOriginatorGuid && olderPartCount > 1);
  }

  bool connectToLower(Message newerMessage) {
    final thisPartCount = chat.target?.guid != null
        ? maybeFindMessagesSvc(chat.target!.guid)?.getMessageStateIfExists(guid!)?.parts.length ?? 1
        : 1;
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
        getLineType(olderMessage, threadOriginator) == LineType.otherToMe) {
      return true;
    }
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
    if (fullText.isEmpty && dbAttachments.isNotEmpty) {
      return Size(
          dbAttachments
              .map((e) => e.width)
              .fold(0, (p, e) => max(p, (e ?? NavigationSvc.width(context) / 2).toDouble()) + 28),
          dbAttachments
              .map((e) => e.height)
              .fold(0, (p, e) => max(p, (e ?? NavigationSvc.width(context) / 2).toDouble())));
    }
    // initialize constraints for text rendering
    final fontSizeFactor = isBigEmoji ? bigEmojiScaleFactor : 1.0;
    final constraints = BoxConstraints(
      maxWidth: maxWidthOverride ?? NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 30,
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
      size = Size(NavigationSvc.width(context) * 2 / 3 - 30, size.height);
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

    // Update is delivered
    if (existing._isDelivered.value != newMessage._isDelivered.value) {
      existing._isDelivered.value = newMessage._isDelivered.value;
    }

    // Update date read
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

    // Also update attributedBody / messageSummaryInfo when the existing record
    // has no data but the incoming message does (independent of edit date).
    if (!isNullOrEmpty(newMessage.attributedBody)) {
      existing.attributedBody = newMessage.attributedBody;
    }
    if (!isNullOrEmpty(newMessage.messageSummaryInfo)) {
      existing.messageSummaryInfo = newMessage.messageSummaryInfo;
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

    // Update handle relationship
    if (!existing.handleRelation.hasValue && newMessage.handleRelation.hasValue) {
      existing.handleRelation.target = newMessage.handleRelation.target;
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

    existing.isBookmarked = newMessage.isBookmarked;

    // Update attachments
    if (existing.dbAttachments.isEmpty && newMessage.dbAttachments.isNotEmpty) {
      existing.dbAttachments.addAll(newMessage.dbAttachments);
    }

    return existing;
  }

  String getLastUpdate() {
    if (dateEdited != null) {
      return "Edited at $dateEdited";
    } else if (datePlayed != null) {
      return "Played at $datePlayed";
    } else if (dateRead != null) {
      return "Read at $dateRead";
    } else if (dateDelivered != null) {
      return "Delivered at $dateDelivered";
    } else if (isDelivered) {
      return "Delivered";
    } else {
      return "Sent at $dateCreated";
    }
  }

  bool isNewerThan(Message other) {
    // If the other message has an error, we want to show that.
    if (error == 0 && other.error != 0) return false;

    // Check null dates in order of what should be filled in first -> last
    if (dateCreated == null && other.dateCreated != null) return false;
    if (dateCreated != null && other.dateCreated == null) return true;
    if (!isDelivered && other.isDelivered) return false;
    if (isDelivered && !other.isDelivered) return true;
    if (dateDelivered == null && other.dateDelivered != null) return false;
    if (dateDelivered != null && other.dateDelivered == null) return true;
    if (dateRead == null && other.dateRead != null) return false;
    if (dateRead != null && other.dateRead == null) return true;
    if (datePlayed == null && other.datePlayed != null) return false;
    if (datePlayed != null && other.datePlayed == null) return true;
    if (dateEdited == null && other.dateEdited != null) return false;
    if (dateEdited != null && other.dateEdited == null) return true;

    // Once we verify that all aren't null, we can start comparing dates.
    // Compare the dates in the opposite order of what should be filled in last -> first
    if (dateEdited != null && other.dateEdited != null) {
      return dateEdited!.millisecondsSinceEpoch > other.dateEdited!.millisecondsSinceEpoch;
    } else if (datePlayed != null && other.datePlayed != null) {
      return datePlayed!.millisecondsSinceEpoch > other.datePlayed!.millisecondsSinceEpoch;
    } else if (dateRead != null && other.dateRead != null) {
      return dateRead!.millisecondsSinceEpoch > other.dateRead!.millisecondsSinceEpoch;
    } else if (dateDelivered != null && other.dateDelivered != null) {
      return dateDelivered!.millisecondsSinceEpoch > other.dateDelivered!.millisecondsSinceEpoch;
    } else if (dateCreated != null && other.dateCreated != null) {
      return dateCreated!.millisecondsSinceEpoch > other.dateCreated!.millisecondsSinceEpoch;
    }

    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      "ROWID": id,
      "originalROWID": originalROWID,
      "guid": guid,
      "handleId": handleId,
      "otherHandle": otherHandle,
      "text": sanitizeString(text),
      "subject": subject,
      "country": country,
      "_error": _error.value,
      "errorMessage": errorMessage,
      "dateCreated": dateCreated?.millisecondsSinceEpoch,
      "dateRead": _dateRead.value?.millisecondsSinceEpoch,
      "dateDelivered": _dateDelivered.value?.millisecondsSinceEpoch,
      "isDelivered": _isDelivered.value,
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
      "handle": getHandle()?.toMap(),
      "hasAttachments": hasAttachments,
      "attachments": dbAttachments.map((a) => a.toMap()).toList(),
      "hasReactions": hasReactions,
      "dateDeleted": dateDeleted?.millisecondsSinceEpoch,
      "metadata": jsonEncode(metadata),
      "threadOriginatorGuid": threadOriginatorGuid,
      "threadOriginatorPart": threadOriginatorPart,
      "hasApplePayloadData": hasApplePayloadData,
      "dateEdited": dateEdited?.millisecondsSinceEpoch,
      "wasDeliveredQuietly": wasDeliveredQuietly,
      "didNotifyRecipient": didNotifyRecipient,
      "isBookmarked": isBookmarked,
      "attributedBody": attributedBody.map((e) => e.toMap()).toList(),
      "messageSummaryInfo": messageSummaryInfo.map((e) => e.toJson()).toList(),
      "payloadData": payloadData?.toJson(),
    };
  }
}
