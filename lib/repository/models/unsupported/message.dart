import 'dart:async';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import '../models.dart';
import 'chat.dart';
import 'handle.dart';

class Message {
  int? id;
  int? originalROWID;
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

  String get fullText => throw Exception("Unsupported Platform");

  factory Message.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  Message save() => throw Exception("Unsupported Platform");

  static Future<Message?> replaceMessage(String? oldGuid, Message? newMessage,
      {bool awaitNewMessageEvent = true, Chat? chat}) async => throw Exception("Unsupported Platform");

  Message updateMetadata(Metadata? metadata) => throw Exception("Unsupported Platform");

  List<Attachment?>? fetchAttachments({CurrentChat? currentChat}) => throw Exception("Unsupported Platform");

  static Chat? getChat(Message message) => throw Exception("Unsupported Platform");

  Message fetchAssociatedMessages({MessageBloc? bloc}) => throw Exception("Unsupported Platform");

  Handle? getHandle() => throw Exception("Unsupported Platform");

  static Message? findOne({String? guid, String? associatedMessageGuid}) => throw Exception("Unsupported Platform");

  static DateTime? lastMessageDate() => throw Exception("Unsupported Platform");

  static List<Message> find() => throw Exception("Unsupported Platform");

  static void delete(String guid) => throw Exception("Unsupported Platform");

  static void softDelete(String guid) => throw Exception("Unsupported Platform");

  static void flush() => throw Exception("Unsupported Platform");

  bool isUrlPreview() => throw Exception("Unsupported Platform");

  String? getUrl() => throw Exception("Unsupported Platform");

  bool isInteractive() => throw Exception("Unsupported Platform");

  bool hasText({stripWhitespace = false}) => throw Exception("Unsupported Platform");

  bool isGroupEvent() => throw Exception("Unsupported Platform");

  bool isBigEmoji() => throw Exception("Unsupported Platform");

  List<Attachment?> getRealAttachments() => throw Exception("Unsupported Platform");

  List<Attachment?> getPreviewAttachments() => throw Exception("Unsupported Platform");

  List<Message> getReactions() => throw Exception("Unsupported Platform");

  void generateTempGuid() => throw Exception("Unsupported Platform");

  static int? countForChat(Chat? chat) => throw Exception("Unsupported Platform");

  void merge(Message otherMessage) => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
