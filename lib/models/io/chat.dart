import 'dart:async';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

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
            ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
            : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull()))
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated, flags: Order.descending))
            .build();
        query
          ..limit = limit
          ..offset = offset;
        messages.addAll(query.find());
        query.close();
      } else {
        final beforeQuery = (messageBox.query(Message_.dateCreated.lessThan(searchAround).and(includeDeleted
            ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
            : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull())))
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated, flags: Order.descending))
            .build();
        beforeQuery.limit = limit;
        final before = beforeQuery.find();
        beforeQuery.close();
        final afterQuery = (messageBox.query(Message_.dateCreated.greaterThan(searchAround).and(includeDeleted
            ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
            : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull())))
          ..link(Message_.chat, Chat_.id.equals(chatId))
          ..order(Message_.dateCreated))
            .build();
        afterQuery.limit = limit;
        final after = afterQuery.find();
        afterQuery.close();
        messages..addAll(before)..addAll(after);
      }

      /// Fetch and match handles
      final chat = chatBox.get(chatId);
      for (int i = 0; i < messages.length; i++) {
        Message message = messages[i];
        if (chat!.participants.isNotEmpty && !message.isFromMe! && message.handleId != null && message.handleId != 0) {
          Handle? handle = chat.participants.firstWhereOrNull((e) => e.originalROWID == message.handleId) ?? message.getHandle();
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
      for (Message m in associatedMessages) {
        if (m.associatedMessageType != "sticker") continue;
        m.attachments = List<Attachment>.from(m.dbAttachments);
      }
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
      for (Message m in associatedMessages) {
        if (m.associatedMessageType != "sticker") continue;
        m.attachments = List<Attachment>.from(m.dbAttachments);
      }
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
        queryBuilder = chatBox.query(Chat_.dateDeleted.isNull());
      }

      // Build the query, applying some sorting so we get data in the correct order.
      // As well as some limit and offset parameters
      Query<Chat> query = (queryBuilder
            ..order(Chat_.isPinned, flags: Order.descending)
            ..order(Chat_.dbOnlyLatestMessageDate, flags: Order.descending))
          .build()
        ..limit = stuff[0]
        ..offset = stuff[1];

      // Execute the query, then close the DB connection
      final chats = query.find();
      query.close();

      /// Assign the handles to the chats, deduplicate, and get fake participants
      /// for redacted mode
      for (Chat c in chats) {
        c._participants = List<Handle>.from(c.handles);
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
  Message get dbLatestMessage {
    _latestMessage = Chat.getMessages(this, limit: 1, getDetails: true).firstOrNull ?? Message(
      dateCreated: DateTime.fromMillisecondsSinceEpoch(0),
      guid: guid,
    );
    return _latestMessage!;
  }
  set latestMessage(Message m) => _latestMessage = m;
  @Property(uid: 526293286661780207)
  DateTime? dbOnlyLatestMessageDate;
  DateTime? dateDeleted;
  int? style;

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
    bool updateDisplayName = false,
    bool updateDateDeleted = false,
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
      if (!updateDisplayName) {
        displayName = existing?.displayName ?? displayName;
      }
      if (!updateDateDeleted) {
        dateDeleted = existing?.dateDeleted;
      }

      /// Save the chat and add the participants
      for (int i = 0; i < participants.length; i++) {
        participants[i] = participants[i].save();
        _deduplicateParticipants();
      }
      dbOnlyLatestMessageDate = dbLatestMessage.dateCreated!;
      try {
        id = chatBox.put(this);
        // make sure to add participant relation if its a new chat
        if (existing == null && participants.isNotEmpty) {
          final toSave = chatBox.get(id!);
          toSave!.handles.clear();
          toSave.handles.addAll(participants);
          toSave.handles.applyToDb();
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
    save(updateDisplayName: true);
    return this;
  }

  /// Get a chat's title
  String getTitle() {
    if (isNullOrEmpty(displayName)!) {
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

  /// Delete a chat locally. Prefer using softDelete so the chat doesn't come back
  static void deleteChat(Chat chat) async {
    if (kIsWeb) return;
    // close the convo view page if open and wait for it to be disposed before deleting
    if (cm.activeChat?.chat.guid == chat.guid) {
      ns.closeAllConversationView(Get.context!);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    List<Message> messages = Chat.getMessages(chat);
    store.runInTransaction(TxMode.write, () {
      /// Remove all references of chat and its messages
      chatBox.remove(chat.id!);
      messageBox.removeMany(messages.map((e) => e.id!).toList());
    });
  }

  static void softDelete(Chat chat) async {
    if (kIsWeb) return;
    // close the convo view page if open and wait for it to be disposed before deleting
    if (cm.activeChat?.chat.guid == chat.guid) {
      ns.closeAllConversationView(Get.context!);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    store.runInTransaction(TxMode.write, () {
      chat.dateDeleted = DateTime.now().toUtc();
      chat.hasUnreadMessage = false;
      chat.save(updateDateDeleted: true, updateHasUnreadMessage: true);
      chat.clearTranscript();
    });
  }

  Chat toggleHasUnread(bool hasUnread, {bool force = false, bool clearLocalNotifications = true, bool privateMark = true}) {
    if (hasUnreadMessage == hasUnread && !force) return this;
    if (!cm.isChatActive(guid) || !hasUnread || force) {
      hasUnreadMessage = hasUnread;
      save(updateHasUnreadMessage: true);
    }
    if (cm.isChatActive(guid) && hasUnread) {
      hasUnread = false;
      clearLocalNotifications = false;
    }

    if (kIsDesktop && !hasUnread) {
      notif.clearDesktopNotificationsForChat(guid);
    }

    try {
      if (clearLocalNotifications && !hasUnread && !ls.isBubble) {
        mcs.invokeMethod("clear-chat-notifs", {"chatGuid": guid});
      }
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
    // If this is a message preview and we don't already have metadata for this, get it
    if (message.fullText.replaceAll("\n", " ").hasUrl && !MetadataHelper.mapIsNotEmpty(message.metadata) && !message.hasApplePayloadData) {
      MetadataHelper.fetchMetadata(message).then((Metadata? meta) async {
        // If the metadata is empty, don't do anything
        if (!MetadataHelper.isNotEmpty(meta)) return;

        // Save the metadata to the object
        message.metadata = meta!.toJson();
      });
    }

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
    // Save any attachments
    for (Attachment? attachment in message.attachments) {
      attachment!.save(newMessage);
    }
    bool isNewer = false;

    // If the message was saved correctly, update this chat's latestMessage info,
    // but only if the incoming message's date is newer
    if ((newMessage?.id != null || kIsWeb) && checkForMessageText) {
      isNewer = message.dateCreated!.isAfter(latest.dateCreated!)
          || (message.guid != latest.guid && message.dateCreated == latest.dateCreated);
      if (isNewer) {
        _latestMessage = message;
        if (dateDeleted != null) {
          dateDeleted = null;
          save(updateDateDeleted: true);
          chats.addChat(this);
        }
      }
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
        toggleHasUnread(false, clearLocalNotifications: clearNotificationsIfFromMe);
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
  static List<Message> getMessages(Chat chat, {int offset = 0, int limit = 25, bool includeDeleted = false, bool getDetails = false}) {
    if (kIsWeb || chat.id == null) return [];
    return store.runInTransaction(TxMode.read, () {
      final query = (messageBox.query(includeDeleted
              ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
              : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull()))
            ..link(Message_.chat, Chat_.id.equals(chat.id!))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      query
        ..limit = limit
        ..offset = offset;
      final messages = query.find();
      query.close();
      for (int i = 0; i < messages.length; i++) {
        Message message = messages[i];
        if (chat.participants.isNotEmpty && !message.isFromMe! && message.handleId != null && message.handleId != 0) {
          Handle? handle = chat.participants.firstWhereOrNull((e) => e.originalROWID == message.handleId) ?? message.getHandle();
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
      _participants = List<Handle>.from(handles);
    });

    _deduplicateParticipants();
    return this;
  }

  void _deduplicateParticipants() {
    if (_participants.isEmpty) return;
    final ids = _participants.map((e) => e.uniqueAddressAndService).toSet();
    _participants.retainWhere((element) => ids.remove(element.uniqueAddressAndService));
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
    isPinned = false;
    this.isArchived = isArchived;
    save(updateIsPinned: true, updateIsArchived: true);
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
  };
}
