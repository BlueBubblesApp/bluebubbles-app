import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/html/attachment.dart';
import 'package:bluebubbles/models/html/chat.dart';
import 'package:bluebubbles/models/html/handle.dart';
import 'package:bluebubbles/models/html/objectbox.dart';
import 'package:bluebubbles/models/models.dart' show AttributedBody, MessageSummaryInfo, PayloadData;
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

enum LineType { meToMe, otherToMe, meToOther, otherToOther }

class Message {
  int? id;
  int? originalROWID;
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

  final chat = ToOne<Chat>();
  final dbAttachments = <Attachment>[];

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
      error: json["_error"] ?? 0,
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
    );
  }

  Message save({Chat? chat}) {
    return this;
  }

  static Future<List<Message>> bulkSaveNewMessages(Chat chat, List<Message> messages) async {
    return [];
  }

  static List<Message> bulkSave(List<Message> messages) {
    return [];
  }

  static Future<Message> replaceMessage(String? oldGuid, Message newMessage, {bool awaitNewMessageEvent = true, Chat? chat}) async {
    return newMessage;
  }

  Message updateMetadata(Metadata? metadata) {
    return this;
  }

  Message setPlayedDate({ DateTime? timestamp }) {
    datePlayed = timestamp ?? DateTime.now().toUtc();
    return this;
  }

  List<Attachment?>? fetchAttachments({ChatLifecycleManager? currentChat}) {
    return attachments;
  }

  Chat? getChat() {
    return null;
  }

  Message fetchAssociatedMessages({MessagesService? service, bool shouldRefresh = false}) {
    associatedMessages = (service?.struct.reactions.where((element) => element.associatedMessageGuid == guid).toList() ?? []).cast<Message>();
    if (threadOriginatorGuid != null) {
      final existing = service?.struct.getMessage(threadOriginatorGuid!);
      final threadOriginator = existing;
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      threadOriginator?.handle ??= Handle.findOne(originalROWID: threadOriginator.handleId);
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      if (threadOriginator != null) associatedMessages.add(threadOriginator);
      if (existing == null && threadOriginator != null) service?.struct.addThreadOriginator(threadOriginator);
    }
    associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));
    return this;
  }

  Handle? getHandle() {
    return null;
  }

  static Message? findOne({String? guid, String? associatedMessageGuid}) {
    return null;
  }

  static List<Message> find() {
    return [];
  }

  static void delete(String guid) {
    return;
  }

  static void softDelete(String guid) {
    return;
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
      other = Handle.findOne(id: otherHandle)?.displayName;
    }

    if (itemType == 1 && groupActionType == 1) {
      text = "$name removed $other from the conversation";
    } else if (itemType == 1 && groupActionType == 0) {
      text = "$name added $other to the conversation";
    } else if (itemType == 3 && (groupActionType ?? 0) > 0) {
      text = "$name changed the group photo";
    } else if (itemType == 3) {
      text = "$name left the conversation";
    } else if (itemType == 2 && groupTitle != null) {
      text = "$name named the conversation \"$groupTitle\"";
    } else if (itemType == 6) {
      text = "$name started a FaceTime call";
    } else if (itemType == 4 && groupActionType == 0) {
      text = "$name shared ${name == "You" ? "your" : "their"} location";
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

  static int? countForChat(Chat? chat) {
    return 0;
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
    // 2) part of the thread
    // OR
    // 1) It is the thread originator but the part is not the last part of the older message
    // 2) It is part of the thread but has multiple parts
    return (olderMessage.guid != threadOriginatorGuid && olderMessage.threadOriginatorGuid != threadOriginatorGuid)
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
      "handle": handle?.toMap(),
      "hasAttachments": hasAttachments,
      "hasReactions": hasReactions,
      "dateDeleted": dateDeleted?.millisecondsSinceEpoch,
      "metadata": jsonEncode(metadata),
      "threadOriginatorGuid": threadOriginatorGuid,
      "threadOriginatorPart": threadOriginatorPart,
      "hasApplePayloadData": hasApplePayloadData,
      "dateEdited": dateEdited,
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
