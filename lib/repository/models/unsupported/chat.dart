import 'dart:async';
import 'package:get/get.dart';
import '../models.dart';
import 'handle.dart';
import 'message.dart';

Future<String> getFullChatTitle(Chat _chat) async => throw Exception("Unsupported Platform");

class Chat {
  int? id;
  int? originalROWID;
  String? guid;
  int? style;
  String? chatIdentifier;
  bool? isArchived;
  bool? isFiltered;
  String? muteType;
  String? muteArgs;
  bool? isPinned;
  bool? hasUnreadMessage;
  DateTime? latestMessageDate;
  String? latestMessageText;
  String? fakeLatestMessageText;
  String? title;
  String? displayName;
  List<Handle> participants = [];
  List<String> fakeParticipants = [];
  Message? latestMessage;
  final RxnString _customAvatarPath = RxnString();
  String? get customAvatarPath => _customAvatarPath.value;
  set customAvatarPath(String? s) => _customAvatarPath.value = s;
  final RxnInt _pinIndex = RxnInt();
  int? get pinIndex => _pinIndex.value;
  set pinIndex(int? i) => _pinIndex.value = i;

  Chat({
    this.id,
    this.originalROWID,
    this.guid,
    this.style,
    this.chatIdentifier,
    this.isArchived,
    this.isFiltered,
    this.isPinned,
    this.muteType,
    this.muteArgs,
    this.hasUnreadMessage,
    this.displayName,
    String? customAvatar,
    int? pinnedIndex,
    this.participants = const [],
    this.fakeParticipants = const [],
    this.latestMessage,
    this.latestMessageDate,
    this.latestMessageText,
    this.fakeLatestMessageText,
  }) {
    customAvatarPath = customAvatar;
    pinIndex = pinnedIndex;
  }

  factory Chat.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  Chat save() => throw Exception("Unsupported Platform");

  Chat changeName(String? name) => throw Exception("Unsupported Platform");

  Future<String?> getTitle() async => throw Exception("Unsupported Platform");

  bool shouldMuteNotification(Message? message) => throw Exception("Unsupported Platform");

  static void deleteChat(Chat chat) => throw Exception("Unsupported Platform");

  Chat toggleHasUnread(bool hasUnread) => throw Exception("Unsupported Platform");

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus: true, bool checkForMessageText = true}) async => throw Exception("Unsupported Platform");

  void serverSyncParticipants() => throw Exception("Unsupported Platform");

  static int? count() => throw Exception("Unsupported Platform");

  static List<Attachment> getAttachments(Chat chat, {int offset = 0, int limit = 25}) => throw Exception("Unsupported Platform");

  static List<Message> getMessages(Chat chat, {int offset = 0, int limit = 25, bool includeDeleted: false}) => throw Exception("Unsupported Platform");

  Chat getParticipants() => throw Exception("Unsupported Platform");

  Chat addParticipant(Handle participant) => throw Exception("Unsupported Platform");

  Chat removeParticipant(Handle participant) => throw Exception("Unsupported Platform");

  void _deduplicateParticipants() => throw Exception("Unsupported Platform");

  Chat togglePin(bool isPinned) => throw Exception("Unsupported Platform");

  Chat toggleMute(bool isMuted) => throw Exception("Unsupported Platform");

  Chat toggleArchived(bool isArchived) => throw Exception("Unsupported Platform");

  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async => throw Exception("Unsupported Platform");

  static Chat? findOne({String? guid, String? chatIdentifier}) => throw Exception("Unsupported Platform");

  static List<Chat> getChats({int limit = 15, int offset = 0}) => throw Exception("Unsupported Platform");

  bool isGroup() => throw Exception("Unsupported Platform");

  void clearTranscript() => throw Exception("Unsupported Platform");

  Message get latestMessageGetter => throw Exception("Unsupported Platform");

  static int sort(Chat? a, Chat? b) => throw Exception("Unsupported Platform");

  static void flush() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
