import 'dart:async';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/join_tables.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:get/get.dart';
import 'package:faker/faker.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import '../../helpers/utils.dart';
import 'handle.dart';
import 'message.dart';

Future<String> getFullChatTitle(Chat _chat) async {
  String? title = "";
  if (isNullOrEmpty(_chat.displayName)!) {
    Chat chat = _chat.getParticipants();

    // If there are no participants, try to get them from the server
    if (chat.participants.isEmpty) {
      await ActionHandler.handleChat(chat: chat);
      chat = chat.getParticipants();
    }

    List<String> titles = [];
    for (int i = 0; i < chat.participants.length; i++) {
      String? name = await ContactManager().getContactTitle(chat.participants[i]);

      if (chat.participants.length > 1 && !name!.isPhoneNumber) {
        name = name.trim().split(" ")[0];
      } else {
        name = name!.trim();
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

@Entity()
class Chat {
  int? id;
  int? originalROWID;
  @Unique()
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

  factory Chat.fromMap(Map<String, dynamic> json) {
    List<Handle> participants = [];
    List<String> fakeParticipants = [];
    if (json.containsKey('participants')) {
      (json['participants'] as List<dynamic>).forEach((item) {
        participants.add(Handle.fromMap(item));
        fakeParticipants.add(ContactManager().handleToFakeName[participants.last.address] ?? "Unknown");
      });
    }
    Message? message;
    if (json['lastMessage'] != null) {
      message = Message.fromMap(json['lastMessage']);
    }
    var data = new Chat(
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
      latestMessageText: json.containsKey("latestMessageText") ? json["latestMessageText"] : message != null ? MessageHelper.getNotificationTextSync(message) : null,
      fakeLatestMessageText: json.containsKey("latestMessageText")
          ? faker.lorem.words((json["latestMessageText"] ?? "").split(" ").length).join(" ")
          : null,
      latestMessageDate: json.containsKey("latestMessageDate") && json['latestMessageDate'] != null
          ? new DateTime.fromMillisecondsSinceEpoch(json['latestMessageDate'] as int)
          : message?.dateCreated,
      displayName: json.containsKey("displayName") ? json["displayName"] : null,
      customAvatar: json['_customAvatarPath'],
      pinnedIndex: json['_pinIndex'],
      participants: participants,
      fakeParticipants: fakeParticipants,
    );

    // Adds fallback getter for the ID
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Chat save() {
    if (kIsWeb) return this;
    Chat? existing = Chat.findOne(guid: this.guid);
    this.id = existing?.id ?? this.id;
    try {
      chatBox.put(this);
    } on UniqueViolationException catch (_) {}
    // Save participants to the chat
    for (int i = 0; i < this.participants.length; i++) {
      this.addParticipant(this.participants[i]);
    }

    return this;
  }

  Chat changeName(String? name) {
    if (kIsWeb) {
      this.displayName = name;
      return this;
    }
    this.displayName = name;
    chatBox.put(this);
    return this;
  }

  Future<String?> getTitle() async {
    this.title = await getFullChatTitle(this);
    return this.title;
  }

  String getDateText() {
    return buildDate(this.latestMessageDate);
  }

  bool shouldMuteNotification(Message? message) {
    if (SettingsManager().settings.filterUnknownSenders.value
        && this.participants.length == 1
        && ContactManager().handleToContact[this.participants[0].address] == null) {
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
        this.toggleMute(false);
        this.muteType = null;
        this.muteArgs = null;
        this.save();
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
    if (kIsWeb) return;
    List<Message> messages = Chat.getMessages(chat);
    chatBox.remove(chat.id!);
    messageBox.removeMany(messages.map((e) => e.id!).toList());
    final query = chJoinBox.query(ChatHandleJoin_.chatId.equals(chat.id!)).build();
    final results = query.property(ChatHandleJoin_.id).find();
    query.close();
    chJoinBox.removeMany(results);
    final query2 = cmJoinBox.query(ChatMessageJoin_.chatId.equals(chat.id!)).build();
    final results2 = query2.property(ChatMessageJoin_.id).find();
    query2.close();
    cmJoinBox.removeMany(results2);
  }

  Chat toggleHasUnread(bool hasUnread) {
    if (hasUnread) {
      if (CurrentChat.isActive(this.guid!)) {
        return this;
      }
    }

    this.hasUnreadMessage = hasUnread;
    this.save();

    if (hasUnread) {
      EventDispatcher().emit("add-unread-chat", {"chatGuid": this.guid});
    } else {
      EventDispatcher().emit("remove-unread-chat", {"chatGuid": this.guid});
    }

    ChatBloc().updateUnreads();
    return this;
  }

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus: true, bool checkForMessageText = true}) async {
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
      if (this.latestMessageDate == null) {
        isNewer = true;
      } else if (this.latestMessageDate!.millisecondsSinceEpoch < message.dateCreated!.millisecondsSinceEpoch) {
        isNewer = true;
      }
    }

    if (isNewer && checkForMessageText) {
      this.latestMessage = message;
      this.latestMessageText = await MessageHelper.getNotificationText(message);
      this.fakeLatestMessageText = faker.lorem.words((this.latestMessageText ?? "").split(" ").length).join(" ");
      this.latestMessageDate = message.dateCreated;
    }

    // Save any attachments
    for (Attachment? attachment in message.attachments ?? []) {
      attachment!.save(newMessage);
    }

    // Save the chat.
    // This will update the latestMessage info as well as update some
    // other fields that we want to "mimic" from the server
    this.save();

    try {
      // Add the relationship
      cmJoinBox.put(ChatMessageJoin(chatId: this.id!, messageId: message.id!));
    } catch (ex) {
      // Don't do anything if it already exists
    }

    // If the incoming message was newer than the "last" one, set the unread status accordingly
    if (checkForMessageText && changeUnreadStatus && isNewer && existing == null) {
      // If the message is from me, mark it unread
      // If the message is not from the same chat as the current chat, mark unread
      if (message.isFromMe!) {
        this.toggleHasUnread(false);
      } else if (!CurrentChat.isActive(this.guid!)) {
        this.toggleHasUnread(true);
      }
    }

    if (checkForMessageText) {
      // Update the chat position
      ChatBloc().updateChatPosition(this);
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    if (isParticipantEvent(message) && checkForMessageText) {
      serverSyncParticipants();
    }

    // If this is a message preview and we don't already have metadata for this, get it
    if (message.fullText.replaceAll("\n", " ").hasUrl && !MetadataHelper.mapIsNotEmpty(message.metadata)) {
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

  void serverSyncParticipants() {
    // Send message to server to get the participants
    SocketManager().sendMessage("get-participants", {"identifier": this.guid}, (response) {
      if (response["status"] == 200) {
        // Get all the participants from the server
        List data = response["data"];
        List<Handle> handles = data.map((e) => Handle.fromMap(e)).toList();

        // Make sure that all participants for our local chat are fetched
        this.getParticipants();

        // We want to determine all the participants that exist in the response that are not already in our locally saved chat (AKA all the new participants)
        List<Handle> newParticipants = handles
            .where((a) => (this.participants.where((b) => b.address == a.address).toList().length == 0))
            .toList();

        // We want to determine all the participants that exist in the locally saved chat that are not in the response (AKA all the removed participants)
        List<Handle> removedParticipants = this
            .participants
            .where((a) => (handles.where((b) => b.address == a.address).toList().length == 0))
            .toList();

        // Add all participants that are missing from our local db
        for (Handle newParticipant in newParticipants) {
          this.addParticipant(newParticipant);
        }

        // Remove all extraneous participants from our local db
        for (Handle removedParticipant in removedParticipants) {
          removedParticipant.save();
          this.removeParticipant(removedParticipant);
        }

        // Sync all changes with the chatbloc
        ChatBloc().updateChat(this);
      }
    });
  }

  static int? count() {
    return chatBox.count();
  }

  static List<Attachment> getAttachments(Chat chat, {int offset = 0, int limit = 25}) {
    if (kIsWeb || chat.id == null) return [];
    final amJoinValues = amJoinBox.getAll();
    final cmJoinValues = cmJoinBox.getAll().where((element) => element.chatId == chat.id).map((e) => e.messageId).toList();
    final query2 = (messageBox.query(Message_.id.oneOf(cmJoinValues))..order(Message_.dateCreated, flags: Order.descending)).build();
    final messages = query2.find();
    final attachmentIds = amJoinValues.where((element) => cmJoinValues.contains(element.messageId)).map((e) => e.attachmentId).toList();
    final query = attachmentBox.query(Attachment_.id.oneOf(attachmentIds)).build();
    query
      ..limit = limit
      ..offset = offset;
    final attachments = query.find()..removeWhere((element) => element.mimeType == null);
    final actualAttachments = <Attachment>[];
    for (Message m in messages) {
      m.attachments = m.fetchAttachments();
      for (Attachment a in attachments) {
        if (m.attachments?.map((e) => e!.guid).contains(a.guid) ?? false) {
          actualAttachments.add(a);
        }
      }
    }
    if (actualAttachments.length > 0) {
      final guids = actualAttachments.map((e) => e.guid).toSet();
      actualAttachments.retainWhere((element) => guids.remove(element.guid));
    }
    query.close();
    return actualAttachments;
  }

  static List<Message> getMessages(Chat chat, {int offset = 0, int limit = 25, bool includeDeleted: false}) {
    if (kIsWeb || chat.id == null) return [];
    final messageIds = cmJoinBox.getAll().where((element) => element.chatId == chat.id).map((e) => e.messageId).toList();
    final query = (messageBox.query(Message_.id.oneOf(messageIds)
        .and(includeDeleted ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()) : Message_.dateDeleted.isNull()))
      ..order(Message_.dateCreated, flags: Order.descending)).build();
    query
      ..limit = limit
      ..offset = offset;
    final messages = query.find();
    query.close();
    final handles = handleBox.getMany(messages.map((e) => e.handleId!).toList()..removeWhere((element) => element == 0));
    messages.forEach((element) {
      if (handles.isNotEmpty && element.handleId != 0)
        element.handle = handles.firstWhere((e) => e?.id == element.handleId);
    });
    return messages;
  }

  Chat getParticipants() {
    if (kIsWeb || this.id == null) return this;
    final handleIds = chJoinBox.getAll().where((element) => element.chatId == this.id).map((e) => e.handleId);
    final handles = handleBox.getMany(handleIds.toList(), growableResult: true)..retainWhere((e) => e != null);
    final nonNullHandles = List<Handle>.from(handles);
    this.participants = nonNullHandles;
    this._deduplicateParticipants();
    this.fakeParticipants = this.participants.map((p) => ContactManager().handleToFakeName[p.address] ?? "Unknown").toList();
    return this;
  }

  Chat addParticipant(Handle participant) {
    if (kIsWeb) {
      this.participants.add(participant);
      this._deduplicateParticipants();
      return this;
    }
    // Save participant and add to list
    participant.save();
    if (participant.id == null) return this;

    try {
      chJoinBox.put(ChatHandleJoin(chatId: this.id!, handleId: participant.id!));
    } catch (ex) {}

    // Add to the class and deduplicate
    this.participants.add(participant);
    this._deduplicateParticipants();
    return this;
  }

  Chat removeParticipant(Handle participant) {
    if (kIsWeb) {
      this.participants.removeWhere((element) => participant.id == element.id);
      this._deduplicateParticipants();
      return this;
    }

    // find the join item and delete it
    final query = chJoinBox.query(ChatHandleJoin_.handleId.equals(participant.id!).and(ChatHandleJoin_.chatId.equals(this.id!))).build();
    final result = query.find().first;
    query.close();
    chJoinBox.remove(result.id!);

    // Second, remove from this object instance
    this.participants.removeWhere((element) => participant.id == element.id);
    this._deduplicateParticipants();
    return this;
  }

  void _deduplicateParticipants() {
    if (this.participants.length == 0) return;
    final ids = this.participants.map((e) => e.address).toSet();
    this.participants.retainWhere((element) => ids.remove(element.address));
  }

  Chat togglePin(bool isPinned) {
    if (this.id == null) return this;
    this.isPinned = isPinned;
    this._pinIndex.value = null;
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleMute(bool isMuted) {
    if (this.id == null) return this;
    this.muteType = isMuted ? "mute" : null;
    this.muteArgs = null;
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleArchived(bool isArchived) {
    if (this.id == null) return this;
    this.isArchived = isArchived;
    this.save();
    ChatBloc().updateChat(this);
    return this;
  }

  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async {
    await ChatBloc().chatRequest!.future;
    if (guid != null) {
      return ChatBloc().chats.firstWhere((e) => e.guid == guid);
    } else if (chatIdentifier != null) {
      return ChatBloc().chats.firstWhereOrNull((e) => e.chatIdentifier == chatIdentifier);
    }
    return null;
  }

  static Chat? findOne({String? guid, String? chatIdentifier}) {
    if (guid != null) {
      final query = chatBox.query(Chat_.guid.equals(guid)).build();
      final result = query.findFirst();
      query.close();
      return result;
    } else if (chatIdentifier != null) {
      final query = chatBox.query(Chat_.chatIdentifier.equals(chatIdentifier)).build();
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static List<Chat> getChats({int limit = 15, int offset = 0}) {
    if (kIsWeb) throw Exception("Use socket to get chats on Web!");
    final query = (chatBox.query()..order(Chat_.isPinned, flags: Order.descending)..order(Chat_.latestMessageDate, flags: Order.descending)).build();
    query
      ..limit = limit
      ..offset = offset;
    final chats = query.find();
    query.close();
    return chats;
  }

  bool isGroup() {
    return this.participants.length > 1;
  }

  void clearTranscript() {
    if (kIsWeb) return;
    final messageIds = cmJoinBox.getAll().where((element) => element.chatId == this.id!).map((e) => e.messageId);
    final messages = messageBox.getAll().where((element) => messageIds.contains(element.id)).toList();
    messages.forEach((element) {
      element.dateDeleted = DateTime.now().toUtc();
    });
    messageBox.putMany(messages);
  }

  Message get latestMessageGetter {
    if (latestMessage != null) return latestMessage!;
    List<Message> latest = Chat.getMessages(this, limit: 1);
    Message message = latest.first;
    latestMessage = message;
    if (message.hasAttachments) {
      message.fetchAttachments();
    }
    return message;
  }

  static int sort(Chat? a, Chat? b) {
    if (a!._pinIndex.value != null && b!._pinIndex.value != null) return a._pinIndex.value!.compareTo(b._pinIndex.value!);
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
    if (kIsWeb) return;
    chatBox.removeAll();
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
