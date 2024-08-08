import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/html/attachment.dart';
import 'package:bluebubbles/models/html/handle.dart';
import 'package:bluebubbles/models/html/message.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

String getFullChatTitle(Chat _chat) {
  String? title = "";
  if (isNullOrEmpty(_chat.displayName)) {
    Chat chat = _chat.getParticipants();

    List<String> titles = [];
    for (int i = 0; i < chat.participants.length; i++) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      String? name = chat.participants[i].displayName;

      if (chat.participants.length > 1 && !name.isPhoneNumber) {
        name = name.trim().split(" ")[0];
      } else {
        name = name.trim();
      }

      titles.add(name);
    }

    if (titles.isEmpty) {
      title = _chat.chatIdentifier;
    } else if (titles.length == 1) {
      title = titles[0];
    } else if (titles.length <= 4) {
      title = titles.join(", ");
      int pos = title.lastIndexOf(", ");
      if (pos != -1) title = "${title.substring(0, pos)} & ${title.substring(pos + 2)}";
    } else {
      title = titles.sublist(0, 3).join(", ");
      title = "$title & ${titles.length - 3} others";
    }
  } else {
    title = _chat.displayName;
  }

  return title!;
}

class Chat {
  int? id;
  String guid;
  String? chatIdentifier;
  bool? isArchived;
  String? muteType;
  String? muteArgs;
  bool? isPinned;
  bool? hasUnreadMessage;
  String? title;
  String get properTitle {
    if (ss.settings.redactedMode.value && ss.settings.hideContactInfo.value) {
      return getTitle();
    }
    title ??= getTitle();
    return title!;
  }
  String? displayName;
  List<Handle> _participants = [];
  List<Handle> get participants {
    if (_participants.isEmpty) {
      getParticipants();
    }
    return _participants;
  }
  bool? autoSendReadReceipts = true;
  bool? autoSendTypingIndicators = true;
  String? textFieldText;
  List<String> textFieldAttachments = [];
  Message? _latestMessage;
  Message get latestMessage {
    if (_latestMessage != null) return _latestMessage!;
    _latestMessage = Chat.getMessages(this, limit: 1, getDetails: true).firstOrNull ?? Message(
      dateCreated: DateTime.fromMillisecondsSinceEpoch(0),
      guid: guid,
    );
    return _latestMessage!;
  }
  set latestMessage(Message m) => _latestMessage = m;
  DateTime? dbOnlyLatestMessageDate;
  DateTime? dateDeleted;
  int? style;
  bool lockChatName;
  bool lockChatIcon;
  String? lastReadMessageGuid;

  final RxnString _customAvatarPath = RxnString();
  String? get customAvatarPath => _customAvatarPath.value;
  set customAvatarPath(String? s) => _customAvatarPath.value = s;
  void refreshCustomAvatar(String s) {
    _customAvatarPath.value = null;
    _customAvatarPath.value = s;
  }

  final RxnInt _pinIndex = RxnInt();
  int? get pinIndex => _pinIndex.value;
  set pinIndex(int? i) => _pinIndex.value = i;

  final List<Handle> handles = [];

  Chat({
    this.id,
    required this.guid,
    this.chatIdentifier,
    this.isArchived = false,
    this.isPinned = false,
    this.muteType,
    this.muteArgs,
    this.hasUnreadMessage = false,
    this.displayName,
    String? customAvatar,
    int? pinnedIndex,
    List<Handle>? participants,
    Message? latestMessage,
    this.autoSendReadReceipts = true,
    this.autoSendTypingIndicators = true,
    this.textFieldText,
    this.textFieldAttachments = const [],
    this.dateDeleted,
    this.style,
    this.lockChatName = false,
    this.lockChatIcon = false,
    this.lastReadMessageGuid,
  }) {
    customAvatarPath = customAvatar;
    pinIndex = pinnedIndex;
    if (textFieldAttachments.isEmpty) textFieldAttachments = [];
    _participants = participants ?? [];
    _latestMessage = latestMessage;
  }

  factory Chat.fromMap(Map<String, dynamic> json) {
    final message = json['lastMessage'] != null ? Message.fromMap(json['lastMessage']) : null;
    return Chat(
      id: json["ROWID"] ?? json["id"],
      guid: json["guid"],
      chatIdentifier: json["chatIdentifier"],
      isArchived: json['isArchived'] ?? false,
      muteType: json["muteType"],
      muteArgs: json["muteArgs"],
      isPinned: json["isPinned"] ?? false,
      hasUnreadMessage: json["hasUnreadMessage"] ?? false,
      latestMessage: message,
      displayName: json["displayName"],
      customAvatar: json['_customAvatarPath'],
      pinnedIndex: json['_pinIndex'],
      participants: (json['participants'] as List? ?? []).map((e) => Handle.fromMap(e)).toList(),
      autoSendReadReceipts: json["autoSendReadReceipts"],
      autoSendTypingIndicators: json["autoSendTypingIndicators"],
      dateDeleted: parseDate(json["dateDeleted"]),
      style: json["style"],
      lockChatName: json["lockChatName"] ?? false,
      lockChatIcon: json["lockChatIcon"] ?? false,
      lastReadMessageGuid: json["lastReadMessageGuid"],
    );
  }

  Chat save({
    bool updateMuteType = false,
    bool updateMuteArgs = false,
    bool updateIsPinned = false,
    bool updatePinIndex = false,
    bool updateIsArchived = false,
    bool updateHasUnreadMessage = false,
    bool updateAutoSendReadReceipts = false,
    bool updateAutoSendTypingIndicators = false,
    bool updateCustomAvatarPath = false,
    bool updateTextFieldText = false,
    bool updateTextFieldAttachments = false,
    bool updateDisplayName = false,
    bool updateDateDeleted = false,
    bool updateLockChatName = false,
    bool updateLockChatIcon = false,
    bool updateLastReadMessageGuid = false,
  }) {
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    WebListeners.notifyChat(this);
    return this;
  }

  Chat changeName(String? name) {
    displayName = name;
    return this;
  }

  /// Get a chat's title
  String getTitle() {
    if (isNullOrEmpty(displayName)) {
      title = getChatCreatorSubtitle();
    } else {
      title = displayName;
    }
    return title!;
  }

  /// Get a chat's title
  String getChatCreatorSubtitle() {
    // generate names for group chats or DMs
    List<String> titles = participants.map((e) => e.displayName.trim().split(isGroup && e.contact != null ? " " : String.fromCharCode(65532)).first).toList();
    if (titles.isEmpty) {
      if (chatIdentifier!.startsWith("urn:biz")) {
        return "Business Chat";
      }
      return chatIdentifier!;
    } else if (titles.length == 1) {
      return titles[0];
    } else if (titles.length <= 4) {
      final _title = titles.join(", ");
      int pos = _title.lastIndexOf(", ");
      if (pos != -1) {
        return "${_title.substring(0, pos)} & ${_title.substring(pos + 2)}";
      } else {
        return _title;
      }
    } else {
      final _title = titles.take(3).join(", ");
      return "$_title & ${titles.length - 3} others";
    }
  }

  bool shouldMuteNotification(Message? message) {
    if (ss.settings.filterUnknownSenders.value &&
        participants.length == 1 &&
        participants[0].contact == null) {
      return true;
    } else if (ss.settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = ss.settings.globalTextDetection.value.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;
    } else if (muteType == "mute") {
      return true;
    } else if (muteType == "mute_individuals") {
      List<String> individuals = muteArgs!.split(",");
      return individuals.contains(message?.handle?.address ?? "");
    } else if (muteType == "temporary_mute") {
      DateTime time = DateTime.parse(muteArgs!);
      bool shouldMute = DateTime.now().toLocal().difference(time).inSeconds.isNegative;
      if (!shouldMute) {
        toggleMute(false);
        muteType = null;
        muteArgs = null;
        save();
      }
      return shouldMute;
    } else if (muteType == "text_detection") {
      List<String> text = muteArgs!.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;
    }
    return !ss.settings.notifyReactions.value &&
        ReactionTypes.toList().contains(message?.associatedMessageType ?? "");
  }

  static void unDelete(Chat chat) {
    return;
  }

  static void softDelete(Chat chat) {
    return;
  }

  Chat toggleHasUnread(bool hasUnread, {bool force = false, bool clearLocalNotifications = true, bool privateMark = true}) {
    if (hasUnreadMessage == hasUnread && !force) return this;
    if (!cm.isChatActive(guid) || !hasUnread || force) {
      hasUnreadMessage = hasUnread;
      save(updateHasUnreadMessage: true);
    }

    try {
      if (privateMark && ss.settings.enablePrivateAPI.value && ss.settings.privateMarkChatAsRead.value) {
        if (!hasUnread && autoSendReadReceipts!) {
          http.markChatRead(guid);
        } else if (hasUnread) {
          http.markChatUnread(guid);
        }
      }
    } catch (_) {}

    return this;
  }

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus = true, bool checkForMessageText = true, bool clearNotificationsIfFromMe = true}) async {
    // Save the message
    Message? latest = latestMessage;
    Message? newMessage;

    try {
      newMessage = message.save(chat: this);
    } catch (ex, stacktrace) {
      newMessage = Message.findOne(guid: message.guid);
      if (newMessage == null) {
        Logger.error(ex.toString());
        Logger.error(stacktrace.toString());
      }
    }
    bool isNewer = false;

    // If the message was saved correctly, update this chat's latestMessage info,
    // but only if the incoming message's date is newer
    if ((newMessage?.id != null || kIsWeb) && checkForMessageText) {
      isNewer = message.dateCreated!.isAfter(latest.dateCreated!)
          || (message.guid != latest.guid && message.dateCreated == latest.dateCreated);
      if (isNewer) {
        _latestMessage = message;
        dateDeleted = null;
        // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
        await chats.addChat(this);
      }
    }

    // Save any attachments
    for (Attachment? attachment in message.attachments) {
      attachment!.save(newMessage);
    }

    // Save the chat.
    // This will update the latestMessage info as well as update some
    // other fields that we want to "mimic" from the server
    save();

    // If the incoming message was newer than the "last" one, set the unread status accordingly
    if (checkForMessageText && changeUnreadStatus && isNewer) {
      // If the message is from me, mark it unread
      // If the message is not from the same chat as the current chat, mark unread
      if (message.isFromMe!) {
        toggleHasUnread(false, clearLocalNotifications: clearNotificationsIfFromMe, force: cm.isChatActive(guid));
      } else if (!cm.isChatActive(guid)) {
        toggleHasUnread(true);
      }
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    if (message.isParticipantEvent && checkForMessageText) {
      serverSyncParticipants();
    }

    // Return the current chat instance (with updated vals)
    return this;
  }

  void serverSyncParticipants() async {
    // Send message to server to get the participants
    // Send message to server to get the participants
    final chat = await cm.fetchChat(guid);
    if (chat != null) {
      chat.save();
    }
  }

  static int? count() {
    return null;
  }

  static List<Attachment> getAttachments(Chat chat, {int offset = 0, int limit = 25}) {
    return [];
  }

  Future<List<Attachment>> getAttachmentsAsync() async {
    return [];
  }

  static List<Message> getMessages(Chat chat,
      {int offset = 0, int limit = 25, bool includeDeleted = false, bool getDetails = false}) {
    return [];
  }

  static Future<List<Message>> getMessagesAsync(Chat chat,
      {int offset = 0, int limit = 25, bool includeDeleted = false, int? searchAround}) async {
    return [];
  }

  Chat getParticipants() {
    return this;
  }

  void webSyncParticipants() {
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    _participants = chats.webCachedHandles.where((e) => _participants.map((e2) => e2.address).contains(e.address)).toList();
  }

  Chat addParticipant(Handle participant) {
    participants.add(participant);
    _deduplicateParticipants();
    return this;
  }

  Chat removeParticipant(Handle participant) {
    participants.removeWhere((element) => participant.id == element.id);
    _deduplicateParticipants();
    return this;
  }

  void _deduplicateParticipants() {
    if (participants.isEmpty) return;
    final ids = participants.map((e) => e.address).toSet();
    participants.retainWhere((element) => ids.remove(element.address));
  }

  Chat togglePin(bool isPinned) {
    if (id == null) return this;
    this.isPinned = isPinned;
    _pinIndex.value = null;
    save();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    chats.updateChat(this);
    chats.sort();
    return this;
  }

  Chat toggleMute(bool isMuted) {
    if (id == null) return this;
    muteType = isMuted ? "mute" : null;
    muteArgs = null;
    save();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    chats.updateChat(this);
    chats.sort();
    return this;
  }

  Chat toggleArchived(bool isArchived) {
    if (id == null) return this;
    this.isArchived = isArchived;
    save();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    chats.updateChat(this);
    chats.sort();
    return this;
  }

  Chat toggleAutoRead(bool? autoSendReadReceipts) {
    if (id == null) return this;
    this.autoSendReadReceipts = autoSendReadReceipts;
    save(updateAutoSendReadReceipts: true);
    if (autoSendReadReceipts ?? ss.settings.privateMarkChatAsRead.value) {
      http.markChatRead(guid);
    }
    return this;
  }

  Chat toggleAutoType(bool? autoSendTypingIndicators) {
    if (id == null) return this;
    this.autoSendTypingIndicators = autoSendTypingIndicators;
    save(updateAutoSendTypingIndicators: true);
    if (!(autoSendTypingIndicators ?? ss.settings.privateSendTypingIndicators.value)) {
      socket.sendMessage("stopped-typing", {"chatGuid": guid});
    }
    return this;
  }

  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async {
    if (guid != null) {
      return chats.chats.firstWhereOrNull((e) => e.guid == guid) as Chat;
    } else if (chatIdentifier != null) {
      return chats.chats.firstWhereOrNull((e) => e.chatIdentifier == chatIdentifier) as Chat;
    }
    return null;
  }

  static Chat? findOne({String? guid, String? chatIdentifier}) {
    return null;
  }

  static List<Chat> getChats({int limit = 15, int offset = 0}) {
    throw Exception("Use socket to get chats on Web!");
  }

  static Future<List<Chat>> syncLatestMessages(List<Chat> chats, bool toggleUnread) async {
    return chats;
  }

  static Future<List<Chat>> bulkSyncChats(List<Chat> chats) async {
    return chats;
  }

  static Future<List<Message>> bulkSyncMessages(Chat chat, List<Message> messages) async {
    return messages;
  }

  void clearTranscript() {
    return;
  }

  bool get isTextForwarding => guid.startsWith("SMS");

  bool get isSMS => false;

  bool get isIMessage => !isTextForwarding && !isSMS;

  bool get isGroup => participants.length > 1 || style == 43;

  Chat merge(Chat other) {
    id ??= other.id;
    _customAvatarPath.value ??= other._customAvatarPath.value;
    _pinIndex.value ??= other._pinIndex.value;
    autoSendReadReceipts ??= other.autoSendReadReceipts;
    autoSendTypingIndicators ??= other.autoSendTypingIndicators;
    textFieldText ??= other.textFieldText;
    if (textFieldAttachments.isEmpty) {
      textFieldAttachments.addAll(other.textFieldAttachments);
    }
    chatIdentifier ??= other.chatIdentifier;
    displayName ??= other.displayName;
    if (handles.isEmpty) {
      handles.addAll(other.handles);
    }
    if (_participants.isEmpty) {
      _participants.addAll(other._participants);
    }
    hasUnreadMessage ??= other.hasUnreadMessage;
    isArchived ??= other.isArchived;
    isPinned ??= other.isPinned;
    _latestMessage ??= other.latestMessage;
    muteArgs ??= other.muteArgs;
    title ??= other.title;
    dateDeleted ??= other.dateDeleted;
    style ??= other.style;
    return this;
  }

  static int sort(Chat? a, Chat? b) {
    // If they both are pinned & ordered, reflect the order
    if (a!.isPinned! && b!.isPinned! && a.pinIndex != null && b.pinIndex != null) {
      return a.pinIndex!.compareTo(b.pinIndex!);
    }

    // If b is pinned & ordered, but a isn't either pinned or ordered, return accordingly
    if (b!.isPinned! && b.pinIndex != null && (!a.isPinned! || a.pinIndex == null)) return 1;
    // If a is pinned & ordered, but b isn't either pinned or ordered, return accordingly
    if (a.isPinned! && a.pinIndex != null && (!b.isPinned! || b.pinIndex == null)) return -1;

    // Compare when one is pinned and the other isn't
    if (!a.isPinned! && b.isPinned!) return 1;
    if (a.isPinned! && !b.isPinned!) return -1;

    // Compare the last message dates
    return -(a.latestMessage.dateCreated)!.compareTo(b.latestMessage.dateCreated!);
  }

  static Future<void> getIcon(Chat c, {bool force = false}) async {}

  Map<String, dynamic> toMap() => {
    "ROWID": id,
    "guid": guid,
    "chatIdentifier": chatIdentifier,
    "isArchived": isArchived!,
    "muteType": muteType,
    "muteArgs": muteArgs,
    "isPinned": isPinned!,
    "displayName": displayName,
    "participants": participants.map((item) => item.toMap()).toList(),
    "hasUnreadMessage": hasUnreadMessage!,
    "_customAvatarPath": _customAvatarPath.value,
    "_pinIndex": _pinIndex.value,
    "autoSendReadReceipts": autoSendReadReceipts!,
    "autoSendTypingIndicators": autoSendTypingIndicators!,
    "dateDeleted": dateDeleted?.millisecondsSinceEpoch,
    "style": style,
    "lockChatName": lockChatName,
    "lockChatIcon": lockChatIcon,
    "lastReadMessageGuid": lastReadMessageGuid,
  };
}
