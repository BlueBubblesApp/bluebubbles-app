import 'dart:async';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/helpers/models/extensions.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/app/widgets/components/reaction.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

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
    int? searchAround = stuff[4];
    return store.runInTransaction(TxMode.read, () {
      /// Get the message IDs for the chat by querying the [cmJoinBox]
      final messages = <Message>[];
      if (searchAround == null) {
        final query = (messageBox.query(includeDeleted
            ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull())
            : Message_.dateDeleted.isNull())
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated, flags: Order.descending))
            .build();
        query
          ..limit = limit
          ..offset = offset;
        messages.addAll(query.find());
        query.close();
      } else {
        final beforeQuery = (messageBox.query(Message_.dateCreated.lessThan(searchAround)
            .and(includeDeleted
            ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull())
            : Message_.dateDeleted.isNull()))
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated, flags: Order.descending))
            .build();
        beforeQuery.limit = limit;
        final before = beforeQuery.find();
        beforeQuery.close();
        final afterQuery = (messageBox.query(Message_.dateCreated.greaterThan(searchAround)
            .and(includeDeleted
            ? Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull())
            : Message_.dateDeleted.isNull()))
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated))
            .build();
        afterQuery.limit = limit;
        final after = afterQuery.find();
        afterQuery.close();
        messages..addAll(before)..addAll(after);
      }

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
      late final QueryBuilder<Chat> queryBuilder;

      // If the 3rd param is available, it's for an ID query.
      // Otherwise, query without any criteria
      if (stuff.length >= 3 && stuff[2] != null && stuff[2] is List) {
        queryBuilder = chatBox.query(Chat_.id.oneOf(stuff[2] as List<int>));
      } else {
        queryBuilder = chatBox.query();
      }

      // Build the query, applying some sorting so we get data in the correct order.
      // As well as some limit and offset parameters
      Query<Chat> query = (queryBuilder
            ..order(Chat_.isPinned, flags: Order.descending)
            ..order(Chat_.latestMessageDate, flags: Order.descending))
          .build()
        ..limit = stuff[0]
        ..offset = stuff[1];

      // Execute the query, then close the DB connection
      final chats = query.find();
      query.close();

      /// Assign the handles to the chats, deduplicate, and get fake participants
      /// for redacted mode
      for (Chat c in chats) {
        c.participants = List<Handle>.from(c.handles);
        c._deduplicateParticipants();
        c.title = c.getTitle();
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
  @Unique()
  String guid;
  String? chatIdentifier;
  bool? isArchived;
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
  Message? latestMessage;
  bool? autoSendReadReceipts = true;
  bool? autoSendTypingIndicators = true;
  String? textFieldText;
  List<String> textFieldAttachments = [];

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
    required this.guid,
    this.chatIdentifier,
    this.isArchived,
    this.isPinned,
    this.muteType,
    this.muteArgs,
    this.hasUnreadMessage,
    this.displayName,
    String? customAvatar,
    int? pinnedIndex,
    this.participants = const [],
    this.latestMessage,
    this.latestMessageDate,
    this.latestMessageText,
    this.fakeLatestMessageText,
    this.autoSendReadReceipts = true,
    this.autoSendTypingIndicators = true,
    this.textFieldText,
    this.textFieldAttachments = const [],
  }) {
    customAvatarPath = customAvatar;
    pinIndex = pinnedIndex;
    if (participants.isEmpty) participants = [];
  }

  factory Chat.fromMap(Map<String, dynamic> json) {
    final message = json['lastMessage'] != null ? Message.fromMap(json['lastMessage']) : null;
    final String? latestText = json["latestMessageText"]
        ?? (message != null ? MessageHelper.getNotificationText(message) : null);

    return Chat(
      id: json["ROWID"] ?? json["id"],
      guid: json["guid"],
      chatIdentifier: json["chatIdentifier"],
      isArchived: json['isArchived'],
      muteType: json["muteType"],
      muteArgs: json["muteArgs"],
      isPinned: json["isPinned"],
      hasUnreadMessage: json["hasUnreadMessage"],
      latestMessage: message,
      latestMessageText: latestText,
      fakeLatestMessageText: faker.lorem.words(latestText?.split(" ").length ?? 1).join(" "),
      latestMessageDate: parseDate(json['latestMessageDate']) ?? message?.dateCreated,
      displayName: json["displayName"],
      customAvatar: json['_customAvatarPath'],
      pinnedIndex: json['_pinIndex'],
      participants: (json['participants'] as List? ?? []).map((e) => Handle.fromMap(e)).toList(),
      autoSendReadReceipts: json["autoSendReadReceipts"],
      autoSendTypingIndicators: json["autoSendTypingIndicators"],
    );
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
    bool updateTextFieldText = false,
    bool updateTextFieldAttachments = false,
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
      if (!updateTextFieldText) {
        textFieldText = existing?.textFieldText ?? textFieldText;
      }
      if (!updateTextFieldAttachments) {
        textFieldAttachments = existing?.textFieldAttachments ?? textFieldAttachments;
      }

      /// Save the chat and add the participants
      for (int i = 0; i < participants.length; i++) {
        participants[i] = participants[i].save();
        _deduplicateParticipants();
      }
      try {
        id = chatBox.put(this);
        if (participants.isNotEmpty && existing?.participants.length != participants.length) {
          final newChat = chatBox.get(id!);
          newChat?.handles.clear();
          newChat?.handles.addAll(participants);
          newChat?.handles.applyToDb();
        }
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
  String getTitle() {
    if (isNullOrEmpty(displayName)!) {
      // generate names for group chats or DMs
      List<String> titles = participants.map((e) => e.displayName.trim().split(isGroup ? " " : String.fromCharCode(65532)).first).toList();
      if (titles.isEmpty) {
        title = chatIdentifier;
      } else if (titles.length == 1) {
        title = titles[0];
      } else if (titles.length <= 4) {
        title = titles.join(", ");
        int pos = title!.lastIndexOf(", ");
        if (pos != -1) title = "${title!.substring(0, pos)} & ${title!.substring(pos + 2)}";
      } else {
        title = titles.take(3).join(", ");
        title = "$title & ${titles.length - 3} others";
      }
    } else {
      title = displayName;
    }
    return title!;
  }

  /// Return whether or not the notification should be muted
  bool shouldMuteNotification(Message? message) {
    /// Filter unknown senders & sender doesn't have a contact, then don't notify
    if (ss.settings.filterUnknownSenders.value &&
        participants.length == 1 &&
        participants.first.contact == null) {
      return true;

      /// Check if global text detection is on and notify accordingly
    } else if (ss.settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = ss.settings.globalTextDetection.value.split(",");
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
    return !ss.settings.notifyReactions.value &&
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

  Chat toggleHasUnread(bool hasUnread, {bool clearLocalNotifications = true}) {
    if ((hasUnread && cm.isChatActive(guid)) || hasUnreadMessage == hasUnread) {
      return this;
    }

    hasUnreadMessage = hasUnread;
    save(updateHasUnreadMessage: true);

    try {
      if (clearLocalNotifications && !hasUnread) {
        mcs.invokeMethod("clear-chat-notifs", {"chatGuid": guid});
      }
      if (ss.settings.enablePrivateAPI.value && ss.settings.privateMarkChatAsRead.value) {
        if (!hasUnread && autoSendReadReceipts!) {
          http.markChatRead(guid);
        } else {
          http.markChatUnread(guid);
        }
      }
    } catch (_) {}

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
        if (ss.settings.preCachePreviewImages.value &&
            message.metadata!.containsKey("image") &&
            !isNullOrEmpty(message.metadata!["image"])!) {
          // Save from URL
          File? newFile = await saveImageFromUrl(message.guid!, message.metadata!["image"]);

          // If we downloaded a file, set the new metadata path
          if (newFile != null && await newFile.exists()) {
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
      } else if (!cm.isChatActive(guid)) {
        toggleHasUnread(true);
      }
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    if (isParticipantEvent(message) && checkForMessageText) {
      serverSyncParticipants();
    }

    // Return the current chat instance (with updated vals)
    return this;
  }

  void serverSyncParticipants() async {
    // Send message to server to get the participants
    final chat = await cm.fetchChat(guid);
    if (chat != null) {
      chat.save();
    }
  }

  static int? count() {
    return chatBox.count();
  }

  Future<List<Attachment>> getAttachmentsAsync() async {
    if (kIsWeb || id == null) return [];

    final task = GetChatAttachments([id!]);
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
      {int offset = 0, int limit = 25, bool includeDeleted = false, int? searchAround}) async {
    if (kIsWeb || chat.id == null) return [];

    final task = GetMessages([chat.id, offset, limit, includeDeleted, searchAround]);
    return (await createAsyncTask<List<Message>>(task)) ?? [];
  }

  Chat getParticipants() {
    if (kIsWeb || id == null) return this;
    store.runInTransaction(TxMode.read, () {
      /// Find the handles themselves
      participants = List<Handle>.from(handles);
    });

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
    chats.updateChat(this);
    chats.sort();
    return this;
  }

  Chat toggleMute(bool isMuted) {
    if (id == null) return this;
    muteType = isMuted ? "mute" : null;
    muteArgs = null;
    save(updateMuteType: true, updateMuteArgs: true);
    return this;
  }

  Chat toggleArchived(bool isArchived) {
    if (id == null) return this;
    this.isArchived = isArchived;
    save(updateIsArchived: true);
    chats.updateChat(this);
    chats.sort();
    return this;
  }

  Chat toggleAutoRead(bool autoSendReadReceipts) {
    if (id == null) return this;
    this.autoSendReadReceipts = autoSendReadReceipts;
    save(updateAutoSendReadReceipts: true);
    if (autoSendReadReceipts) {
      http.markChatRead(guid);
    }
    return this;
  }

  Chat toggleAutoType(bool autoSendTypingIndicators) {
    if (id == null) return this;
    this.autoSendTypingIndicators = autoSendTypingIndicators;
    save(updateAutoSendTypingIndicators: true);
    if (!autoSendTypingIndicators) {
      socket.sendMessage("stopped-typing", {"chatGuid": guid});
    }
    return this;
  }

  /// Finds a chat - only use this method on Flutter Web!!!
  static Future<Chat?> findOneWeb({String? guid, String? chatIdentifier}) async {
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

  static Future<List<Chat>> getChats({int limit = 15, int offset = 0, List<int> ids = const []}) async {
    if (kIsWeb) throw Exception("Use socket to get chats on Web!");

    final task = GetChats([limit, offset, ids.isEmpty ? null : ids]);
    return (await createAsyncTask<List<Chat>>(task)) ?? [];
  }

  static Future<List<Chat>> syncLatestMessages(List<Chat> chats, bool toggleUnread) async {
    if (kIsWeb) throw Exception("Use socket to sync the last message on Web!");

    final task = SyncLastMessages([chats, toggleUnread]);
    return (await createAsyncTask<List<Chat>>(task)) ?? [];
  }

  static Future<List<Chat>> bulkSyncChats(List<Chat> chats) async {
    if (kIsWeb) throw Exception("Web does not support saving chats!");
    if (chats.isEmpty) return [];

    final task = BulkSyncChats([chats]);
    return (await createAsyncTask<List<Chat>>(task)) ?? [];
  }

  static Future<List<Message>> bulkSyncMessages(Chat chat, List<Message> messages) async {
    if (kIsWeb) throw Exception("Web does not support saving messages!");
    if (messages.isEmpty) return [];

    final task = BulkSyncMessages([chat, messages]);
    return (await createAsyncTask<List<Message>>(task)) ?? [];
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

  bool get isTextForwarding => guid.startsWith("SMS");

  bool get isSMS => false;

  bool get isIMessage => !isTextForwarding && !isSMS;

  bool get isGroup => participants.length > 1;

  Message? get latestMessageGetter {
    if (latestMessage != null) return latestMessage!;
    List<Message> latest = Chat.getMessages(this, limit: 1);
    Message? message = latest.firstOrNull;
    latestMessage = message;
    if (message?.hasAttachments ?? false) {
      message?.fetchAttachments();
    }
    return message;
  }

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
    fakeLatestMessageText ??= other.fakeLatestMessageText;
    if (handles.isEmpty) {
      handles.addAll(other.handles);
    }
    hasUnreadMessage ??= other.hasUnreadMessage;
    isArchived ??= other.isArchived;
    isPinned ??= other.isPinned;
    latestMessage ??= other.latestMessage;
    latestMessageDate ??= other.latestMessageDate;
    latestMessageText ??= other.latestMessageText;
    muteArgs ??= other.muteArgs;
    if (participants.isEmpty) {
      participants.addAll(other.participants);
    }
    title ??= other.title;

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
    if ((a.latestMessageDate ?? a.latestMessageGetter?.dateCreated) == null &&
        (b.latestMessageDate ?? b.latestMessageGetter?.dateCreated) == null) return 0;
    if ((a.latestMessageDate ?? a.latestMessageGetter?.dateCreated) == null) return 1;
    if ((b.latestMessageDate ?? b.latestMessageGetter?.dateCreated) == null) return -1;
    return -(a.latestMessageDate ?? a.latestMessageGetter?.dateCreated)!
        .compareTo((b.latestMessageDate ?? b.latestMessageGetter?.dateCreated)!);
  }

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
    "latestMessageDate": latestMessageDate?.millisecondsSinceEpoch ?? 0,
    "latestMessageText": latestMessageText,
    "_customAvatarPath": _customAvatarPath.value,
    "_pinIndex": _pinIndex.value,
    "autoSendReadReceipts": autoSendReadReceipts!,
    "autoSendTypingIndicators": autoSendTypingIndicators!,
  };
}
