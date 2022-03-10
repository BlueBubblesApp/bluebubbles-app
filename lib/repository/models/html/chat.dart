import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/html/attachment.dart';
import 'package:bluebubbles/repository/models/html/handle.dart';
import 'package:bluebubbles/repository/models/html/message.dart';
import 'package:bluebubbles/repository/models/models.dart' show Contact;
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:universal_io/io.dart';

String getFullChatTitle(Chat _chat) {
  String? title = "";
  if (isNullOrEmpty(_chat.displayName)!) {
    Chat chat = _chat.getParticipants();

    //todo - do we really need this here?
    /*// If there are no participants, try to get them from the server
    if (chat.participants.isEmpty) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      await ActionHandler.handleChat(chat: chat);
      chat = chat.getParticipants();
    }*/

    List<String> titles = [];
    for (int i = 0; i < chat.participants.length; i++) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      String? name = ContactManager().getContactTitle(chat.participants[i]);

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
  int? originalROWID;
  String guid;
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
  List<Contact?> fakeParticipants = [];
  Message? latestMessage;
  final RxnString _customAvatarPath = RxnString();
  String? get customAvatarPath => _customAvatarPath.value;
  set customAvatarPath(String? s) => _customAvatarPath.value = s;
  final RxnInt _pinIndex = RxnInt();
  int? get pinIndex => _pinIndex.value;
  set pinIndex(int? i) => _pinIndex.value = i;
  bool? autoSendReadReceipts = true;
  bool? autoSendTypingIndicators = true;

  final List<Handle> handles = [];

  Chat({
    this.id,
    this.originalROWID,
    required this.guid,
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
    this.autoSendReadReceipts = true,
    this.autoSendTypingIndicators = true,
  }) {
    customAvatarPath = customAvatar;
    pinIndex = pinnedIndex;
  }

  factory Chat.fromMap(Map<String, dynamic> json) {
    List<Handle> participants = [];
    List<String> fakeParticipants = [];
    if (json.containsKey('participants')) {
      for (dynamic item in (json['participants'] as List<dynamic>)) {
        participants.add(Handle.fromMap(item));
        fakeParticipants.add(ContactManager().getContact(participants.last.address)?.fakeName ?? "Unknown");
      }
    }
    Message? message;
    if (json['lastMessage'] != null) {
      message = Message.fromMap(json['lastMessage']);
    }
    var data = Chat(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      guid: json["guid"],
      style: json['style'],
      chatIdentifier: json.containsKey("chatIdentifier") ? json["chatIdentifier"] : null,
      isArchived: (json["isArchived"] is bool) ? json['isArchived'] : ((json['isArchived'] == 1) ? true : false),
      isFiltered: json.containsKey("isFiltered")
          ? (json["isFiltered"] is bool)
              ? json['isFiltered']
              : ((json['isFiltered'] == 1) ? true : false)
          : false,
      muteType: json["muteType"],
      muteArgs: json["muteArgs"],
      isPinned: json.containsKey("isPinned")
          ? (json["isPinned"] is bool)
              ? json['isPinned']
              : ((json['isPinned'] == 1) ? true : false)
          : false,
      hasUnreadMessage: json.containsKey("hasUnreadMessage")
          ? (json["hasUnreadMessage"] is bool)
              ? json['hasUnreadMessage']
              : ((json['hasUnreadMessage'] == 1) ? true : false)
          : false,
      latestMessage: message,
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      latestMessageText: json.containsKey("latestMessageText")
          ? json["latestMessageText"]
          : message != null
              ? null// ? MessageHelper.getNotificationText(message)
              : null,
      fakeLatestMessageText: json.containsKey("latestMessageText")
          ? faker.lorem.words((json["latestMessageText"] ?? "").split(" ").length).join(" ")
          : null,
      latestMessageDate: json.containsKey("latestMessageDate") && json['latestMessageDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['latestMessageDate'] as int)
          : message?.dateCreated,
      displayName: json.containsKey("displayName") ? json["displayName"] : null,
      customAvatar: json['_customAvatarPath'],
      pinnedIndex: json['_pinIndex'],
      participants: participants,
      fakeParticipants: [],
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
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
  }) {
    return this;
  }

  Chat changeName(String? name) {
    displayName = name;
    return this;
  }

  String? getTitle() {
    title = getFullChatTitle(this);
    return title;
  }

  String getDateText() {
    return buildDate(latestMessageDate);
  }

  bool shouldMuteNotification(Message? message) {
    if (SettingsManager().settings.filterUnknownSenders.value &&
        participants.length == 1 &&
        ContactManager().getContact(participants[0].address) == null) {
      return true;
    } else if (SettingsManager().settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = SettingsManager().settings.globalTextDetection.value.split(",");
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
    return !SettingsManager().settings.notifyReactions.value &&
        ReactionTypes.toList().contains(message?.associatedMessageType ?? "");
  }

  static void deleteChat(Chat chat) {
    return;
  }

  Chat toggleHasUnread(bool hasUnread) {
    if (hasUnread) {
      if (ChatManager().isChatActiveByGuid(guid)) {
        return this;
      }
    }

    hasUnreadMessage = hasUnread;
    ChatBloc().chats.firstWhereOrNull((e) => e.guid == guid)?.hasUnreadMessage = hasUnread;
    save();

    if (hasUnread) {
      EventDispatcher().emit("add-unread-chat", {"chatGuid": guid});
    } else {
      EventDispatcher().emit("remove-unread-chat", {"chatGuid": guid});
    }

    ChatBloc().updateUnreads();
    return this;
  }

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus = true, bool checkForMessageText = true}) async {
    //final Database? db = await DBProvider.db.database;

    // Save the message
    Message? existing = Message.findOne(guid: message.guid);
    Message? newMessage;

    try {
      newMessage = message.save();
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
    if ((newMessage!.id != null || kIsWeb) && checkForMessageText) {
      if (latestMessageDate == null) {
        isNewer = true;
      } else if (latestMessageDate!.millisecondsSinceEpoch < message.dateCreated!.millisecondsSinceEpoch) {
        isNewer = true;
      }
    }

    if (isNewer && checkForMessageText) {
      latestMessage = message;
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      latestMessageText = MessageHelper.getNotificationText(message);
      fakeLatestMessageText = faker.lorem.words((latestMessageText ?? "").split(" ").length).join(" ");
      latestMessageDate = message.dateCreated;
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
    if (checkForMessageText && changeUnreadStatus && isNewer && existing == null) {
      // If the message is from me, mark it unread
      // If the message is not from the same chat as the current chat, mark unread
      if (message.isFromMe!) {
        toggleHasUnread(false);
      } else if (!ChatManager().isChatActiveByGuid(guid)) {
        toggleHasUnread(true);
      }
    }

    if (checkForMessageText) {
      // Update the chat position
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      ChatBloc().updateChatPosition(this);
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    if (isParticipantEvent(message) && checkForMessageText) {
      serverSyncParticipants();
    }

    // If this is a message preview and we don't already have metadata for this, get it
    if (message.fullText.replaceAll("\n", " ").hasUrl && !MetadataHelper.mapIsNotEmpty(message.metadata)) {
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      MetadataHelper.fetchMetadata(message).then((Metadata? meta) async {
        // If the metadata is empty, don't do anything
        if (!MetadataHelper.isNotEmpty(meta)) return;

        // Save the metadata to the object
        message.metadata = meta!.toJson();

        // If pre-caching is enabled, fetch the image and save it
        if (SettingsManager().settings.preCachePreviewImages.value &&
            message.metadata!.containsKey("image") &&
            !isNullOrEmpty(message.metadata!["image"])!) {
          // Save from URL
          File? newFile = await saveImageFromUrl(message.guid!, message.metadata!["image"]);

          // If we downloaded a file, set the new metadata path
          if (newFile != null && newFile.existsSync()) {
            message.metadata!["image"] = newFile.path;
          }
        }

        message.save();
      });
    }

    // Return the current chat instance (with updated vals)
    return this;
  }

  Future<List<Message>> bulkAddMessages(List<Message> messages,
      {bool changeUnreadStatus = true, bool checkForMessageText = true}) async {
    return [];
  }

  void serverSyncParticipants() {
    // Send message to server to get the participants
    SocketManager().sendMessage("get-participants", {"identifier": guid}, (response) {
      if (response["status"] == 200) {
        // Get all the participants from the server
        List data = response["data"];
        List<Handle> handles = data.map((e) => Handle.fromMap(e)).toList();

        // Make sure that all participants for our local chat are fetched
        getParticipants();

        // We want to determine all the participants that exist in the response that are not already in our locally saved chat (AKA all the new participants)
        List<Handle> newParticipants =
            handles.where((a) => (participants.where((b) => b.address == a.address).toList().isEmpty)).toList();

        // We want to determine all the participants that exist in the locally saved chat that are not in the response (AKA all the removed participants)
        List<Handle> removedParticipants =
            participants.where((a) => (handles.where((b) => b.address == a.address).toList().isEmpty)).toList();

        // Add all participants that are missing from our local db
        for (Handle newParticipant in newParticipants) {
          addParticipant(newParticipant);
        }

        // Remove all extraneous participants from our local db
        for (Handle removedParticipant in removedParticipants) {
          removedParticipant.save();
          removeParticipant(removedParticipant);
        }

        // Sync all changes with the chatbloc
        // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
        ChatBloc().updateChat(this);
      }
    });
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
      {int offset = 0, int limit = 25, bool includeDeleted = false, bool getDetails = false}) async {
    return [];
  }

  Chat getParticipants() {
    return this;
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
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleMute(bool isMuted) {
    if (id == null) return this;
    muteType = isMuted ? "mute" : null;
    muteArgs = null;
    save();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleArchived(bool isArchived) {
    if (id == null) return this;
    this.isArchived = isArchived;
    save();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleAutoRead(bool autoSendReadReceipts) {
    return this;
  }

  Chat toggleAutoType(bool autoSendTypingIndicators) {
    return this;
  }

  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async {
    await ChatBloc().chatRequest!.future;
    if (guid != null) {
      return ChatBloc().chats.firstWhere((e) => e.guid == guid) as Chat;
    } else if (chatIdentifier != null) {
      return ChatBloc().chats.firstWhereOrNull((e) => e.chatIdentifier == chatIdentifier) as Chat;
    }
    return null;
  }

  static Chat? findOne({String? guid, String? chatIdentifier}) {
    return null;
  }

  static List<Chat> getChats({int limit = 15, int offset = 0}) {
    throw Exception("Use socket to get chats on Web!");
  }

  bool isGroup() {
    return participants.length > 1;
  }

  void clearTranscript() {
    return;
  }

  bool get isTextForwarding => guid.startsWith("SMS");

  bool get isSMS => false;

  bool get isIMessage => !isTextForwarding && !isSMS;

  List<String> get fakeNames {
    if (fakeParticipants.whereNotNull().length == fakeParticipants.length) {
      return fakeParticipants.map((p) => p!.fakeName ?? "Unknown").toList();
    }

    fakeParticipants =
        participants.mapIndexed((i, e) => fakeParticipants[i] ?? ContactManager().getContact(e.address)).toList();

    return fakeParticipants.map((p) => p?.fakeName ?? "Unknown").toList();
  }

  Message? get latestMessageGetter {
    if (latestMessage != null) return latestMessage!;
    List<Message> latest = Chat.getMessages(this, limit: 1);
    if (latest.isEmpty) return null;

    Message message = latest.first;
    latestMessage = message;
    if (message.hasAttachments) {
      message.fetchAttachments();
    }
    return message;
  }

  static int sort(Chat? a, Chat? b) {
    if (a!._pinIndex.value != null && b!._pinIndex.value != null) {
      return a._pinIndex.value!.compareTo(b._pinIndex.value!);
    }
    if (b!._pinIndex.value != null) return 1;
    if (a._pinIndex.value != null) return -1;
    if (!a.isPinned! && b.isPinned!) return 1;
    if (a.isPinned! && !b.isPinned!) return -1;
    if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
    if (a.latestMessageDate == null) return 1;
    if (b.latestMessageDate == null) return -1;
    return -a.latestMessageDate!.compareTo(b.latestMessageDate!);
  }

  static void flush() {
    return;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "guid": guid,
        "style": style,
        "chatIdentifier": chatIdentifier,
        "isArchived": isArchived! ? 1 : 0,
        "isFiltered": isFiltered! ? 1 : 0,
        "muteType": muteType,
        "muteArgs": muteArgs,
        "isPinned": isPinned! ? 1 : 0,
        "displayName": displayName,
        "participants": participants.map((item) => item.toMap()),
        "hasUnreadMessage": hasUnreadMessage! ? 1 : 0,
        "latestMessageDate": latestMessageDate != null ? latestMessageDate!.millisecondsSinceEpoch : 0,
        "latestMessageText": latestMessageText,
        "_customAvatarPath": _customAvatarPath,
        "_pinIndex": _pinIndex.value,
      };
}
