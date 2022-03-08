import 'dart:async';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

String getFullChatTitle(Chat _chat) {
  String? title = "";
  if (isNullOrEmpty(_chat.displayName)!) {
    Chat chat = _chat;
    if (isNullOrEmpty(chat.participants)!) {
      chat = _chat.getParticipants();
    }

    //todo - do we really need this here?
    /*// If there are no participants, try to get them from the server
    if (chat.participants.isEmpty) {
      await ActionHandler.handleChat(chat: chat);
      chat = chat.getParticipants();
    }*/

    List<String> titles = [];
    for (int i = 0; i < chat.participants.length; i++) {
      String? name = ContactManager().getContactTitle(chat.participants[i]);

      if (chat.participants.length > 1 && !name.numericOnly().isPhoneNumber) {
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

/// Async method to get attachments from objectbox
class GetChatAttachments extends AsyncTask<List<dynamic>, List<Attachment>> {
  final List<dynamic> stuff;

  GetChatAttachments(this.stuff);

  @override
  AsyncTask<List<dynamic>, List<Attachment>> instantiate(List<dynamic> parameters,
      [Map<String, SharedData>? sharedData]) {
    return GetChatAttachments(parameters);
  }

  @override
  List<dynamic> parameters() {
    return stuff;
  }

  @override
  FutureOr<List<Attachment>> run() {
    /// Pull args from input and create new instances of store and boxes
    int chatId = stuff[0];
    return store.runInTransaction(TxMode.read, () {
      /// Query the [messageBox] for all the message IDs and order by date
      /// descending
      final query = (messageBox.query()
            ..link(Message_.chat, Chat_.id.equals(chatId))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      final messages = query.find();
      query.close();

      final actualAttachments = <Attachment>[];

      /// Match the attachments to their messages
      for (Message m in messages) {
        m.attachments = List<Attachment>.from(m.dbAttachments.where((element) => element.mimeType != null));
        actualAttachments.addAll((m.attachments).map((e) => e!));
      }

      /// Remove duplicate attachments from the list, just in case
      if (actualAttachments.isNotEmpty) {
        final guids = actualAttachments.map((e) => e.guid).toSet();
        actualAttachments.retainWhere((element) => guids.remove(element.guid));
      }
      return actualAttachments;
    });
  }
}

/// Async method to get messages from objectbox
class GetMessages extends AsyncTask<List<dynamic>, List<Message>> {
  final List<dynamic> stuff;

  GetMessages(this.stuff);

  @override
  AsyncTask<List<dynamic>, List<Message>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return GetMessages(parameters);
  }

  @override
  List<dynamic> parameters() {
    return stuff;
  }

  @override
  FutureOr<List<Message>> run() {
    /// Pull args from input and create new instances of store and boxes
    int chatId = stuff[0];
    int offset = stuff[1];
    int limit = stuff[2];
    bool includeDeleted = stuff[3];
    return store.runInTransaction(TxMode.read, () {
      /// Get the message IDs for the chat by querying the [cmJoinBox]
      final query = (messageBox.query(includeDeleted
              ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull())
              : Message_.dateDeleted.isNull())
            ..link(Message_.chat, Chat_.id.equals(chatId))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      query
        ..limit = limit
        ..offset = offset;
      final messages = query.find();
      query.close();

      /// Fetch and match handles
      final handles =
          handleBox.getMany(messages.map((e) => e.handleId ?? 0).toList()..removeWhere((element) => element == 0));
      for (int i = 0; i < messages.length; i++) {
        Message message = messages[i];
        if (handles.isNotEmpty && message.handleId != 0) {
          Handle? handle = handles.firstWhereOrNull((e) => e?.id == message.handleId);
          if (handle == null && message.originalROWID != null) {
            messages.remove(message);
            i--;
          } else {
            message.handle = handle;
          }
        }
      }
      final messageGuids = messages.map((e) => e.guid!).toList();
      final associatedMessagesQuery =
          (messageBox.query(Message_.associatedMessageGuid.oneOf(messageGuids))..order(Message_.originalROWID)).build();
      List<Message> associatedMessages = associatedMessagesQuery.find();
      associatedMessagesQuery.close();
      associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
      for (Message m in messages) {
        m.attachments = List<Attachment>.from(m.dbAttachments);
        m.associatedMessages = associatedMessages.where((e) => e.associatedMessageGuid == m.guid).toList();
      }
      return messages;
    });
  }
}

/// Async method to add messages to objectbox
class AddMessages extends AsyncTask<List<dynamic>, List<Message>> {
  final List<dynamic> stuff;

  AddMessages(this.stuff);

  @override
  AsyncTask<List<dynamic>, List<Message>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return AddMessages(parameters);
  }

  @override
  List<dynamic> parameters() {
    return stuff;
  }

  @override
  FutureOr<List<Message>> run() {
    /// Pull args from input and create new instances of store and boxes
    List<Message> messages = stuff[0].map((e) => Message.fromMap(e)).toList().cast<Message>();

    /// Save the new messages and their attachments in a write transaction
    final newMessages = store.runInTransaction(TxMode.write, () {
      List<Message> newMessages = Message.bulkSave(messages);
      Attachment.bulkSave(
          Map.fromIterables(newMessages, newMessages.map((e) => (e.attachments).map((e) => e!).toList())));
      return newMessages;
    });

    /// fetch attachments and reactions in a read transaction
    return store.runInTransaction(TxMode.read, () {
      final messageGuids = newMessages.map((e) => e.guid!).toList();

      /// Query the [messageBox] for associated messages (reactions) matching the
      /// message IDs
      final associatedMessagesQuery =
          (messageBox.query(Message_.associatedMessageGuid.oneOf(messageGuids))..order(Message_.originalROWID)).build();
      List<Message> associatedMessages = associatedMessagesQuery.find();
      associatedMessagesQuery.close();
      associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);

      /// Assign the relevant attachments and associated messages to the original
      /// messages
      for (Message m in newMessages) {
        m.attachments = List<Attachment>.from(m.dbAttachments);
        m.associatedMessages = associatedMessages.where((e) => e.associatedMessageGuid == m.guid).toList();
      }
      return newMessages;
    });
  }
}

/// Async method to get chats from objectbox
class GetChats extends AsyncTask<List<dynamic>, List<Chat>> {
  final List<dynamic> stuff;

  GetChats(this.stuff);

  @override
  AsyncTask<List<dynamic>, List<Chat>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return GetChats(parameters);
  }

  @override
  List<dynamic> parameters() {
    return stuff;
  }

  @override
  FutureOr<List<Chat>> run() {
    return store.runInTransaction(TxMode.write, () {
      /// Query the [chatBox] for chats with limit and offset, prioritize pinned
      /// chats and order by latest message date
      final query = (chatBox.query()
            ..order(Chat_.isPinned, flags: Order.descending)
            ..order(Chat_.latestMessageDate, flags: Order.descending))
          .build();
      query
        ..limit = stuff[0]
        ..offset = stuff[1];
      final chats = query.find();
      query.close();

      /// Assign the handles to the chats, deduplicate, and get fake participants
      /// for redacted mode
      for (Chat c in chats) {
        c.participants = List<Handle>.from(c.handles);
        c._deduplicateParticipants();
        if ([c.autoSendReadReceipts, c.autoSendTypingIndicators].contains(null)) {
          c.autoSendReadReceipts ??= true;
          c.autoSendTypingIndicators ??= true;
          c.save(
            updateAutoSendReadReceipts: true,
            updateAutoSendTypingIndicators: true,
          );
        }
      }
      return chats;
    });
  }
}

@Entity()
class Chat {
  int? id;
  int? originalROWID;
  @Unique()
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
  @Transient()
  List<Contact?> fakeParticipants = [];
  Message? latestMessage;
  bool? autoSendReadReceipts = true;
  bool? autoSendTypingIndicators = true;

  final RxnString _customAvatarPath = RxnString();

  String? get customAvatarPath => _customAvatarPath.value;

  set customAvatarPath(String? s) => _customAvatarPath.value = s;

  final RxnInt _pinIndex = RxnInt();

  int? get pinIndex => _pinIndex.value;

  set pinIndex(int? i) => _pinIndex.value = i;

  final handles = ToMany<Handle>();

  @Backlink('chat')
  final messages = ToMany<Message>();

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

    // Map the participant fake names
    fakeParticipants = participants.map((e) => ContactManager().getContact(e.address)).toList();
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

  factory Chat.fromMap(Map<String, dynamic> json) {
    List<Handle> participants = [];
    List<Contact?> fakeParticipants = [];
    if (json.containsKey('participants')) {
      for (dynamic item in (json['participants'] as List<dynamic>)) {
        participants.add(Handle.fromMap(item));
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
      latestMessageText: json.containsKey("latestMessageText")
          ? json["latestMessageText"]
          : message != null
              ? MessageHelper.getNotificationText(message)
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
      fakeParticipants: fakeParticipants,
      autoSendReadReceipts: json.containsKey("autoSendReadReceipts")
          ? (json["autoSendReadReceipts"] is bool)
              ? json['autoSendReadReceipts']
              : ((json['autoSendReadReceipts'] == 1) ? true : false)
          : true,
      autoSendTypingIndicators: json.containsKey("autoSendTypingIndicators")
          ? (json["autoSendTypingIndicators"] is bool)
              ? json['autoSendTypingIndicators']
              : ((json['autoSendTypingIndicators'] == 1) ? true : false)
          : true,
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  /// Save a chat to the DB
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
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      /// Find an existing, and update the ID to the existing ID if necessary
      Chat? existing = Chat.findOne(guid: guid);
      id = existing?.id ?? id;
      if (!updateMuteType) {
        muteType = existing?.muteType ?? muteType;
      }
      if (!updateMuteArgs) {
        muteArgs = existing?.muteArgs ?? muteArgs;
      }
      if (!updateIsPinned) {
        isPinned = existing?.isPinned ?? isPinned;
      }
      if (!updatePinIndex) {
        pinIndex = existing?.pinIndex ?? pinIndex;
      }
      if (!updateIsArchived) {
        isArchived = existing?.isArchived ?? isArchived;
      }
      if (!updateHasUnreadMessage) {
        hasUnreadMessage = existing?.hasUnreadMessage ?? hasUnreadMessage;
      }
      if (!updateAutoSendReadReceipts) {
        autoSendReadReceipts = existing?.autoSendReadReceipts ?? autoSendReadReceipts;
      }
      if (!updateAutoSendTypingIndicators) {
        autoSendTypingIndicators = existing?.autoSendTypingIndicators ?? autoSendTypingIndicators;
      }
      if (!updateCustomAvatarPath) {
        customAvatarPath = existing?.customAvatarPath ?? customAvatarPath;
      }

      /// Save the chat and add the participants
      for (int i = 0; i < participants.length; i++) {
        participants[i] = participants[i].save();
        participants.add(participants[i]);
        _deduplicateParticipants();
      }
      try {
        final difference = participants.where((e) => !handles.map((e) => e.address).contains(e.address));
        if (difference.isNotEmpty) {
          handles.addAll(difference);
        }
        id = chatBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Change a chat's display name
  Chat changeName(String? name) {
    if (kIsWeb) {
      displayName = name;
      return this;
    }
    displayName = name;
    save();
    return this;
  }

  /// Get a chat's title
  String? getTitle() {
    title = getFullChatTitle(this);
    return title;
  }

  /// Get the latest message date as text
  String getDateText() {
    return buildDate(latestMessageDate);
  }

  /// Return whether or not the notification should be muted
  bool shouldMuteNotification(Message? message) {
    /// Filter unknown senders & sender doesn't have a contact, then don't notify
    if (SettingsManager().settings.filterUnknownSenders.value &&
        participants.length == 1 &&
        ContactManager().getContact(participants[0].address) == null) {
      return true;

      /// Check if global text detection is on and notify accordingly
    } else if (SettingsManager().settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = SettingsManager().settings.globalTextDetection.value.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;

      /// Check if muted
    } else if (muteType == "mute") {
      return true;

      /// Check if the sender is muted
    } else if (muteType == "mute_individuals") {
      List<String> individuals = muteArgs!.split(",");
      return individuals.contains(message?.handle?.address ?? "");

      /// Check if the chat is temporarily muted
    } else if (muteType == "temporary_mute") {
      DateTime time = DateTime.parse(muteArgs!);
      bool shouldMute = DateTime.now().toLocal().difference(time).inSeconds.isNegative;
      if (!shouldMute) {
        toggleMute(false);
      }
      return shouldMute;

      /// Check if the chat has specific text detection and notify accordingly
    } else if (muteType == "text_detection") {
      List<String> text = muteArgs!.split(",");
      for (String s in text) {
        if (message?.text?.toLowerCase().contains(s.toLowerCase()) ?? false) {
          return false;
        }
      }
      return true;
    }

    /// If reaction and notify reactions off, then don't notify, otherwise notify
    return !SettingsManager().settings.notifyReactions.value &&
        ReactionTypes.toList().contains(message?.associatedMessageType ?? "");
  }

  /// Delete a chat locally
  static void deleteChat(Chat chat) {
    if (kIsWeb) return;
    List<Message> messages = Chat.getMessages(chat);
    store.runInTransaction(TxMode.write, () {
      /// Remove all references of chat - from chatBox, messageBox,
      /// chJoinBox, and cmJoinBox
      chatBox.remove(chat.id!);
      messageBox.removeMany(messages.map((e) => e.id!).toList());
    });
  }

  Chat toggleHasUnread(bool hasUnread) {
    if (hasUnread) {
      if (ChatManager().isChatActive(this)) {
        return this;
      }
    }

    if (hasUnreadMessage == hasUnread || (recentIntent != null && recentIntent != guid)) return this;

    hasUnreadMessage = hasUnread;
    ChatBloc().chats.firstWhereOrNull((e) => e.guid == guid)?.hasUnreadMessage = hasUnread;
    save(updateHasUnreadMessage: true);

    if (hasUnread) {
      EventDispatcher().emit("add-unread-chat", {"chatGuid": guid});
    } else {
      EventDispatcher().emit("remove-unread-chat", {"chatGuid": guid});
    }

    ChatBloc().updateUnreads();
    return this;
  }

  Future<Chat> addMessage(Message message, {bool changeUnreadStatus = true, bool checkForMessageText = true}) async {
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
      });
    }

    // Save the message
    Message? existing = Message.findOne(guid: message.guid);
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
      if (latestMessageDate == null) {
        isNewer = true;
      } else if (latestMessageDate!.millisecondsSinceEpoch < message.dateCreated!.millisecondsSinceEpoch) {
        isNewer = true;
      }
    }

    if (isNewer && checkForMessageText) {
      latestMessage = message;
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
      } else if (!ChatManager().isChatActive(this)) {
        toggleHasUnread(true);
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

    // Return the current chat instance (with updated vals)
    return this;
  }

  /// Add a lot of messages for the single chat to avoid running [addMessage]
  /// in a loop
  /* Future<List<Message>> bulkAddMessages(List<Message> messages,
      {bool changeUnreadStatus = true, bool checkForMessageText = true}) async {
    for (Message m in messages) {
      // If this is a message preview and we don't already have metadata for this, get it
      if (!m.fullText.replaceAll("\n", " ").hasUrl || MetadataHelper.mapIsNotEmpty(m.metadata)) continue;
      Metadata? meta = await MetadataHelper.fetchMetadata(m);
      if (!MetadataHelper.isNotEmpty(meta)) continue;

      // Save the metadata to the object
      m.metadata = meta!.toJson();

      // If pre-caching is enabled, fetch the image and save it
      if (SettingsManager().settings.preCachePreviewImages.value &&
          m.metadata!.containsKey("image") &&
          !isNullOrEmpty(m.metadata!["image"])!) {
        // Save from URL
        File? newFile = await saveImageFromUrl(m.guid!, m.metadata!["image"]);

        // If we downloaded a file, set the new metadata path
        if (newFile != null && newFile.existsSync()) {
          m.metadata!["image"] = newFile.path;
        }
      }
    }

    // Save to DB
    final newMessages = await compute(addMessagesIsolate,
        [messages.map((e) => e.toMap(includeObjects: true)).toList(), prefs.getString("objectbox-reference")]);
    cmJoinBox.putMany(newMessages.map((e) => ChatMessageJoin(chatId: id!, messageId: e.id!)).toList());

    Message? newer = newMessages
        .where((e) => (latestMessageDate?.millisecondsSinceEpoch ?? 0) < e.dateCreated!.millisecondsSinceEpoch)
        .sorted((a, b) => b.dateCreated!.compareTo(a.dateCreated!))
        .firstOrNull;

    // If the incoming message was newer than the "last" one, set the unread status accordingly
    if (checkForMessageText && changeUnreadStatus && newer != null) {
      // If the message is from me, mark it unread
      // If the message is not from the same chat as the current chat, mark unread
      if (newer.isFromMe!) {
        toggleHasUnread(false);
      } else if (!ChatController.isActive(guid!)) {
        toggleHasUnread(true);
      }
    }

    if (checkForMessageText) {
      // Update the chat position
      ChatBloc().updateChatPosition(this);
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    Message? participantEvent = messages.firstWhereOrNull((element) => isParticipantEvent(element));
    if (participantEvent != null && checkForMessageText) {
      serverSyncParticipants();
    }

    if (newer != null && checkForMessageText) {
      latestMessage = newer;
      latestMessageText = MessageHelper.getNotificationText(newer);
      fakeLatestMessageText = faker.lorem.words((latestMessageText ?? "").split(" ").length).join(" ");
      latestMessageDate = newer.dateCreated;
    }

    save();

    // Return the current chat instance (with updated vals)
    return newMessages;
  }*/

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
        ChatBloc().updateChat(this);
      }
    });
  }

  static int? count() {
    return chatBox.count();
  }

  Future<List<Attachment>> getAttachmentsAsync() async {
    if (kIsWeb || id == null) return [];

    final task = GetChatAttachments([id!, prefs.getString("objectbox-reference")]);
    return (await createAsyncTask<List<Attachment>>(task)) ?? [];
  }

  /// Gets messages synchronously - DO NOT use in performance-sensitive areas,
  /// otherwise prefer [getMessagesAsync]
  static List<Message> getMessages(Chat chat,
      {int offset = 0, int limit = 25, bool includeDeleted = false, bool getDetails = false}) {
    if (kIsWeb || chat.id == null) return [];
    return store.runInTransaction(TxMode.read, () {
      final query = (messageBox.query(includeDeleted
              ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull())
              : Message_.dateDeleted.isNull())
            ..link(Message_.chat, Chat_.id.equals(chat.id!))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      query
        ..limit = limit
        ..offset = offset;
      final messages = query.find();
      query.close();
      final handles =
          handleBox.getMany(messages.map((e) => e.handleId ?? 0).toList()..removeWhere((element) => element == 0));
      for (int i = 0; i < messages.length; i++) {
        Message message = messages[i];
        if (handles.isNotEmpty && message.handleId != 0) {
          Handle? handle = handles.firstWhereOrNull((e) => e?.id == message.handleId);
          if (handle == null) {
            messages.remove(message);
            i--;
          } else {
            message.handle = handle;
          }
        }
      }
      // fetch attachments and reactions if requested
      if (getDetails) {
        final messageGuids = messages.map((e) => e.guid!).toList();
        final associatedMessagesQuery = (messageBox.query(Message_.associatedMessageGuid.oneOf(messageGuids))
              ..order(Message_.originalROWID))
            .build();
        List<Message> associatedMessages = associatedMessagesQuery.find();
        associatedMessagesQuery.close();
        associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
        for (Message m in messages) {
          m.attachments = List<Attachment>.from(m.dbAttachments);
          m.associatedMessages = associatedMessages.where((e) => e.associatedMessageGuid == m.guid).toList();
        }
      }
      return messages;
    });
  }

  /// Fetch messages asynchronously
  static Future<List<Message>> getMessagesAsync(Chat chat,
      {int offset = 0, int limit = 25, bool includeDeleted = false}) async {
    if (kIsWeb || chat.id == null) return [];

    final task = GetMessages([chat.id, offset, limit, includeDeleted, prefs.getString("objectbox-reference")]);
    return (await createAsyncTask<List<Message>>(task)) ?? [];
  }

  Chat getParticipants() {
    if (kIsWeb || id == null) return this;
    store.runInTransaction(TxMode.read, () {
      /// Find the handles themselves
      participants = List<Handle>.from(handles);
    });

    /// Deduplicate and generate fake participants for redacted mode
    _deduplicateParticipants();
    fakeParticipants = participants.map((p) => ContactManager().getContact(p.address)).toList();
    return this;
  }

  Chat addParticipant(Handle participant) {
    if (kIsWeb) {
      participants.add(participant);
      _deduplicateParticipants();
      return this;
    }
    // Save participant and add to list
    participant = participant.save();
    if (participant.id == null) return this;

    try {
      handles.add(participant);
      save();
    } catch (_) {}

    // Add to the class and deduplicate
    participants.add(participant);
    _deduplicateParticipants();
    return this;
  }

  Chat removeParticipant(Handle participant) {
    if (kIsWeb) {
      participants.removeWhere((element) => participant.id == element.id);
      _deduplicateParticipants();
      return this;
    }

    // find the join item and delete it
    store.runInTransaction(TxMode.write, () {
      handles.removeWhere((element) => element.address == participant.address);
      save();
    });

    // Second, remove from this object instance
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
    save(updateIsPinned: true, updatePinIndex: true);
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleMute(bool isMuted) {
    if (id == null) return this;
    muteType = isMuted ? "mute" : null;
    muteArgs = null;
    save(updateMuteType: true, updateMuteArgs: true);
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleArchived(bool isArchived) {
    if (id == null) return this;
    this.isArchived = isArchived;
    save(updateIsArchived: true);
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleAutoRead(bool autoSendReadReceipts) {
    if (id == null) return this;
    this.autoSendReadReceipts = autoSendReadReceipts;
    save(updateAutoSendReadReceipts: true);
    if (autoSendReadReceipts) {
      SocketManager().sendMessage("mark-chat-read", {"chatGuid": guid}, (data) {});
    }
    ChatBloc().updateChat(this);
    return this;
  }

  Chat toggleAutoType(bool autoSendTypingIndicators) {
    if (id == null) return this;
    this.autoSendTypingIndicators = autoSendTypingIndicators;
    save(updateAutoSendTypingIndicators: true);
    if (!autoSendTypingIndicators) {
      SocketManager().sendMessage("stopped-typing", {"chatGuid": guid}, (data) {});
    }
    ChatBloc().updateChat(this);
    return this;
  }

  /// Finds a chat - only use this method on Flutter Web!!!
  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async {
    await ChatBloc().chatRequest!.future;
    if (guid != null) {
      return ChatBloc().chats.firstWhere((e) => e.guid == guid);
    } else if (chatIdentifier != null) {
      return ChatBloc().chats.firstWhereOrNull((e) => e.chatIdentifier == chatIdentifier);
    }
    return null;
  }

  /// Finds a chat - DO NOT use this method on Flutter Web!! Prefer [findOneWeb]
  /// instead!!
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

  static Future<List<Chat>> getChats({int limit = 15, int offset = 0}) async {
    if (kIsWeb) throw Exception("Use socket to get chats on Web!");

    final task = GetChats([limit, offset]);
    return (await createAsyncTask<List<Chat>>(task)) ?? [];
  }

  bool isGroup() {
    return participants.length > 1;
  }

  void clearTranscript() {
    if (kIsWeb) return;
    store.runInTransaction(TxMode.write, () {
      final toDelete = List<Message>.from(messages);
      for (Message element in toDelete) {
        element.dateDeleted = DateTime.now().toUtc();
      }
      messageBox.putMany(toDelete);
    });
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
        "participants": participants.map((item) => item.toMap()).toList(),
        "hasUnreadMessage": hasUnreadMessage! ? 1 : 0,
        "latestMessageDate": latestMessageDate != null ? latestMessageDate!.millisecondsSinceEpoch : 0,
        "latestMessageText": latestMessageText,
        "_customAvatarPath": _customAvatarPath.value,
        "_pinIndex": _pinIndex.value,
        "autoSendReadReceipts": autoSendReadReceipts! ? 1 : 0,
        "autoSendTypingIndicators": autoSendTypingIndicators! ? 1 : 0,
      };
}
