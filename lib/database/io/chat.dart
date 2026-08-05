import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:dio/dio.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:bluebubbles/models/models.dart' show MessageSaveResult;
import 'package:get/get.dart' hide Response;
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:universal_io/io.dart';

@Entity()
class Chat {
  int? id;

  @Index(type: IndexType.value)
  @Unique()
  String guid;

  String? chatIdentifier;
  bool? isArchived;
  String? muteType;
  String? muteArgs;
  bool? isPinned;
  bool? hasUnreadMessage;

  String? displayName;
  bool? autoSendReadReceipts;
  bool? autoSendTypingIndicators;
  String? textFieldText;
  List<String> textFieldAttachments = [];

  /// ObjectBox ToOne relation to the latest message for O(1) lookup.
  /// Keep [dbOnlyLatestMessageDate] in sync via [setLatestMessage].
  final dbLatestMessage = ToOne<Message>();

  @Property(uid: 526293286661780207)
  DateTime? dbOnlyLatestMessageDate;

  /// Update the latest-message relation and its sort-key in one step.
  /// Persists both fields to the DB asynchronously (fire-and-forget).
  void setLatestMessage(Message m) {
    dbLatestMessage.target = m;
    dbOnlyLatestMessageDate = m.dateCreated;
    unawaited(saveAsync(updateLatestMessage: true));
  }

  DateTime? dateDeleted;
  int? style;
  bool lockChatName;
  bool lockChatIcon;
  String? lastReadMessageGuid;
  String? customThemeLight;
  String? customThemeDark;

  final RxnString _customAvatarPath = RxnString();
  String? get customAvatarPath => _customAvatarPath.value;
  set customAvatarPath(String? s) => _customAvatarPath.value = s;

  final RxnString _customBackgroundPath = RxnString();
  String? get customBackgroundPath => _customBackgroundPath.value;
  set customBackgroundPath(String? s) => _customBackgroundPath.value = s;

  final RxnInt _pinIndex = RxnInt();
  int? get pinIndex => _pinIndex.value;
  set pinIndex(int? i) => _pinIndex.value = i;

  @Transient()
  RxDouble sendProgress = 0.0.obs;

  final handles = ToMany<Handle>();

  // Do not use this field directly, use the handles ToMany relation instead.
  // This should only really be used for serialization/deserialization purposes.
  @Transient()
  List<Handle> participants = [];

  @Backlink('chat')
  final messages = ToMany<Message>();

  @Backlink('chats')
  final customGroups = ToMany<CustomGroup>();

  @Transient()
  String? _fakeName;

  @Transient()
  String get fakeName {
    if (_fakeName != null) return _fakeName!;
    final color = faker.color.color();
    final animal = faker.animal.name();
    _fakeName = "${color.capitalize} ${animal.capitalize}";
    return _fakeName!;
  }

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
    String? customBackground,
    int? pinnedIndex,
    Message? latestMessage,
    this.participants = const [],
    this.autoSendReadReceipts,
    this.autoSendTypingIndicators,
    this.textFieldText,
    this.textFieldAttachments = const [],
    this.dateDeleted,
    this.style,
    this.lockChatName = false,
    this.lockChatIcon = false,
    this.lastReadMessageGuid,
    this.customThemeLight,
    this.customThemeDark,
  }) {
    customAvatarPath = customAvatar;
    customBackgroundPath = customBackground;
    pinIndex = pinnedIndex;
    if (textFieldAttachments.isEmpty) textFieldAttachments = [];
    if (latestMessage != null) dbOnlyLatestMessageDate ??= latestMessage.dateCreated;
  }

  factory Chat.fromMap(Map<String, dynamic> json) {
    final message = json['lastMessage'] != null ? Message.fromMap(json['lastMessage']!.cast<String, Object>()) : null;
    return Chat(
      id: json["ROWID"] ?? json["id"],
      guid: json["guid"],
      chatIdentifier: json["chatIdentifier"],
      participants:
          (json['participants'] as List? ?? []).map((e) => Handle.fromMap(e!.cast<String, Object>())).toList(),
      isArchived: json['isArchived'] ?? false,
      muteType: json["muteType"],
      muteArgs: json["muteArgs"],
      isPinned: json["isPinned"] ?? false,
      hasUnreadMessage: json["hasUnreadMessage"] ?? false,
      latestMessage: message,
      displayName: json["displayName"],
      customAvatar: json['_customAvatarPath'],
      customBackground: json['_customBackgroundPath'],
      pinnedIndex: json['_pinIndex'],
      autoSendReadReceipts: json["autoSendReadReceipts"],
      autoSendTypingIndicators: json["autoSendTypingIndicators"],
      dateDeleted: parseDate(json["dateDeleted"]),
      style: json["style"],
      lockChatName: json["lockChatName"] ?? false,
      lockChatIcon: json["lockChatIcon"] ?? false,
      lastReadMessageGuid: json["lastReadMessageGuid"],
      customThemeLight: json["customThemeLight"],
      customThemeDark: json["customThemeDark"],
      textFieldText: json["textFieldText"],
      textFieldAttachments: (json["textFieldAttachments"] as List?)?.cast<String>() ?? const [],
    );
  }

  /// Save a chat to the DB asynchronously (non-blocking)
  Future<Chat> saveAsync({
    bool updateMuteType = false,
    bool updateMuteArgs = false,
    bool updateIsPinned = false,
    bool updatePinIndex = false,
    bool updateIsArchived = false,
    bool updateHasUnreadMessage = false,
    bool updateAutoSendReadReceipts = false,
    bool updateAutoSendTypingIndicators = false,
    bool updateCustomAvatarPath = false,
    bool updateCustomBackgroundPath = false,
    bool updateTextFieldText = false,
    bool updateTextFieldAttachments = false,
    bool updateDisplayName = false,
    bool updateDateDeleted = false,
    bool updateLockChatName = false,
    bool updateLockChatIcon = false,
    bool updateLastReadMessageGuid = false,
    bool updateLatestMessage = false,
    bool updateCustomThemes = false,
  }) async {
    if (kIsWeb) return this;

    await ChatInterface.saveChat(
      guid: guid,
      chatData: toMap(),
      updateFlags: {
        'updateMuteType': updateMuteType,
        'updateMuteArgs': updateMuteArgs,
        'updateIsPinned': updateIsPinned,
        'updatePinIndex': updatePinIndex,
        'updateIsArchived': updateIsArchived,
        'updateHasUnreadMessage': updateHasUnreadMessage,
        'updateAutoSendReadReceipts': updateAutoSendReadReceipts,
        'updateAutoSendTypingIndicators': updateAutoSendTypingIndicators,
        'updateCustomAvatarPath': updateCustomAvatarPath,
        'updateCustomBackgroundPath': updateCustomBackgroundPath,
        'updateTextFieldText': updateTextFieldText,
        'updateTextFieldAttachments': updateTextFieldAttachments,
        'updateDisplayName': updateDisplayName,
        'updateDateDeleted': updateDateDeleted,
        'updateLockChatName': updateLockChatName,
        'updateLockChatIcon': updateLockChatIcon,
        'updateLastReadMessageGuid': updateLastReadMessageGuid,
        'updateLatestMessage': updateLatestMessage,
        'updateCustomThemes': updateCustomThemes,
      },
    );

    return this;
  }

  /// Change a chat's display name
  Future<Chat> changeNameAsync(String? name) async {
    if (kIsWeb) {
      displayName = name;
      return this;
    }
    displayName = name;
    await saveAsync(updateDisplayName: true);
    return this;
  }

  /// Get a chat's title
  String getTitle() => isNullOrEmpty(displayName) ? getChatCreatorSubtitle() : displayName!;

  /// Get a chat's title
  String getChatCreatorSubtitle() {
    final count = handles.length;
    if (count == 0) {
      if (chatIdentifier!.startsWith("urn:biz")) {
        return "Business Chat";
      }
      return chatIdentifier!;
    } else if (count == 1) {
      return handles.first.displayName;
    }

    if (count <= 4) {
      final buffer = StringBuffer();
      for (int i = 0; i < count; i++) {
        if (i > 0) buffer.write(i == count - 1 ? ' & ' : ', ');
        buffer.write(handles[i].shortName);
      }
      return buffer.toString();
    } else {
      final buffer = StringBuffer();
      for (int i = 0; i < 3; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write(handles[i].shortName);
      }
      buffer.write(' & ${count - 3} others');
      return buffer.toString();
    }
  }

  /// Return whether or not the notification should be muted
  bool shouldMuteNotification(Message? message) {
    /// Filter unknown senders & sender doesn't have a contact, then don't notify
    if (SettingsSvc.settings.filterUnknownSenders.value && handles.length == 1 && handles.first.contactsV2.isEmpty) {
      return true;

      /// Check if global text detection is on and notify accordingly
    } else if (SettingsSvc.settings.globalTextDetection.value.isNotEmpty) {
      List<String> text = SettingsSvc.settings.globalTextDetection.value.split(",");
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
      return individuals.contains(message?.handleRelation.target?.address ?? "");

      /// Check if the chat is temporarily muted
    } else if (muteType == "temporary_mute") {
      DateTime time = DateTime.parse(muteArgs!);
      bool shouldMute = DateTime.now().toLocal().difference(time).inSeconds.isNegative;
      if (!shouldMute) {
        toggleMuteAsync(false);
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
    return !SettingsSvc.settings.notifyReactions.value &&
        ReactionTypes.toList().contains(message?.associatedMessageType ?? "");
  }

  /// Toggle unread status - pure DB operation
  /// Note: For full unread toggle with active chat awareness, use ChatsSvc.toggleChatHasUnread
  Future<Chat> toggleHasUnreadAsync(bool hasUnread,
      {bool force = false, bool clearLocalNotifications = true, bool privateMark = true}) async {
    if (kIsDesktop && !hasUnread) {
      NotificationsSvc.clearDesktopNotificationsForChat(guid);
    }

    if (hasUnreadMessage == hasUnread && !force) return this;
    hasUnreadMessage = hasUnread;
    await saveAsync(updateHasUnreadMessage: true);

    try {
      if (clearLocalNotifications && !hasUnread) {
        ChatInterface.clearNotificationForChat(
          chatId: id!,
          chatGuid: guid,
        );
      }
      if (privateMark && (autoSendReadReceipts ?? SettingsSvc.settings.privateMarkChatAsRead.value)) {
        ChatInterface.markChatReadUnread(
          chatGuid: guid,
          markAsRead: !hasUnread,
          shouldMarkOnServer: true,
        );
      }
    } catch (e, s) {
      Logger.warn("Failed to mark chat as read on message add", error: e, trace: s, tag: 'Chat');
    }

    return this;
  }

  /// Add message to chat - pure DB operation
  /// Note: For full message add with service updates, use ChatsSvc.addMessageToChat
  Future<MessageSaveResult> addMessage(Message message,
      {bool changeUnreadStatus = true,
      bool checkForMessageText = true,
      bool clearNotificationsIfFromMe = true,
      List<Attachment> attachments = const []}) async {
    // Save the message using the interface
    Message? latest = dbLatestMessage.target;
    Message? newMessage;
    bool isNewer = false;

    try {
      final result = await ChatInterface.addMessageToChat(
        messageData: message.toMap(),
        attachmentsData: attachments.map((e) => e.toMap()).toList(),
        chatData: toMap(),
        latestMessageData: (latest ?? Message(dateCreated: DateTime.fromMillisecondsSinceEpoch(0), guid: guid)).toMap(),
        checkForMessageText: checkForMessageText,
      );

      // Extract from MessageSaveResult
      newMessage = result.message;
      isNewer = result.isNewer;
    } catch (ex, stacktrace) {
      newMessage = Message.findOne(guid: message.guid);
      if (newMessage == null) {
        Logger.error("Failed to add message (GUID: ${message.guid}) to chat (GUID: $guid)",
            error: ex, trace: stacktrace);
      }
    }

    // Handle post-save operations on main thread
    if (isNewer) {
      // Link the saved (DB-hydrated) message so a freshly-added chat's tile is
      // built with its subtitle populated on first paint.
      setLatestMessage(newMessage ?? message);
      if (dateDeleted != null) {
        dateDeleted = null;
        await saveAsync(updateDateDeleted: true);
      }
      if (isArchived! && !message.isFromMe! && SettingsSvc.settings.unarchiveOnNewMessage.value) {
        await toggleArchivedAsync(false);
      }
    }

    // Save the chat.
    // This will update the latestMessage info as well as update some
    // other fields that we want to "mimic" from the server
    await saveAsync();

    // If the incoming message was newer than the "last" one, set the unread status accordingly
    if (checkForMessageText && changeUnreadStatus && isNewer) {
      // Simple logic: mark read if from me, mark unread if not
      if (message.isFromMe!) {
        await toggleHasUnreadAsync(false, clearLocalNotifications: clearNotificationsIfFromMe, privateMark: false);
      } else {
        await toggleHasUnreadAsync(true, privateMark: false);
      }
    }

    // If the message is for adding or removing participants,
    // we need to ensure that all of the chat participants are correct by syncing with the server
    if (message.isParticipantEvent && checkForMessageText) {
      serverSyncParticipantsAsync();
    }

    // Return the saved message and isNewer flag
    return MessageSaveResult(newMessage ?? message, isNewer);
  }

  Future<void> serverSyncParticipantsAsync() async {
    // Sync participants from server - delegates to service layer
    // Note: For full sync with service updates, this is called by ChatsSvc.addMessageToChat
    try {
      final response = await HttpSvc.chat.fetchOne(guid, withQuery: "participants");
      if (response.statusCode == 200 && response.data["data"] != null) {
        final chatData = response.data["data"];
        final updatedChat = (await ChatInterface.bulkSyncChats(chatsData: [chatData])).chats;
        if (updatedChat.isNotEmpty) {
          await updatedChat.first.saveAsync();
        }
      }
    } catch (ex, stacktrace) {
      Logger.error("Failed to sync participants", error: ex, trace: stacktrace);
    }
  }

  // count() method moved to ChatsService

  Future<List<Attachment>> getAttachmentsAsync({bool fetchDeleted = false}) async {
    if (kIsWeb || id == null) return [];

    final stopwatch = Stopwatch()..start();

    /// Query the messages for this chat using ObjectBox's async API
    final messageQuery = (Database.messages.query(fetchDeleted
            ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
            : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull()))
          ..link(Message_.chat, Chat_.id.equals(id!))
          ..order(Message_.dateCreated, flags: Order.descending))
        .build();

    // Execute query in worker isolate
    final messages = await messageQuery.findAsync();
    messageQuery.close();

    if (messages.isEmpty) {
      stopwatch.stop();
      Logger.debug("Fetched 0 messages for chat $guid in ${stopwatch.elapsedMilliseconds} ms");
      return [];
    }

    // Get all message IDs to query attachments
    final messageIds = messages.map((e) => e.id!).toList();

    // Query attachments linked to these messages asynchronously
    final attachmentQuery = (Database.attachments.query(Attachment_.mimeType.notNull())
          ..link(Attachment_.message, Message_.id.oneOf(messageIds)))
        .build();

    final attachments = await attachmentQuery.findAsync();
    attachmentQuery.close();

    // Remove duplicate attachments from the list, just in case
    if (attachments.isNotEmpty) {
      final guids = attachments.map((e) => e.guid).toSet();
      attachments.retainWhere((element) => guids.remove(element.guid));
    }

    stopwatch.stop();
    Logger.debug("Fetched ${attachments.length} attachments for chat $guid in ${stopwatch.elapsedMilliseconds} ms");
    return attachments;
  }

  /// Gets messages synchronously - DO NOT use in performance-sensitive areas,
  /// otherwise prefer [getMessagesAsync]
  static List<Message> getMessages(Chat chat,
      {int offset = 0, int limit = 25, bool includeDeleted = false, bool getDetails = false}) {
    if (kIsWeb || chat.id == null) return [];
    return Database.runInTransaction(TxMode.read, () {
      final query = (Database.messages.query(includeDeleted
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
        if (chat.handles.isNotEmpty && !message.isFromMe! && message.handleId != null && message.handleId != 0) {
          Handle? handle = chat.handles.firstWhereOrNull((e) => e.originalROWID == message.handleId) ??
              message.handleRelation.target;
          if (handle == null) {
            messages.remove(message);
            i--;
          }
        }
      }
      // fetch attachments and reactions if requested
      if (getDetails) {
        final messageGuids = messages.map((e) => e.guid!).toList();
        final associatedMessagesQuery = (Database.messages.query(Message_.associatedMessageGuid.oneOf(messageGuids))
              ..order(Message_.originalROWID))
            .build();
        List<Message> associatedMessages = associatedMessagesQuery.find();
        associatedMessagesQuery.close();
        associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);
        for (Message m in messages) {
          m.associatedMessages = associatedMessages.where((e) => e.associatedMessageGuid == m.guid).toList();
        }
      }
      return messages;
    });
  }

  /// Fetch messages asynchronously with progressive loading
  /// Returns messages with attachments, then loads reactions in background
  static Future<List<Message>> getMessagesAsync(Chat chat,
      {int offset = 0,
      int limit = 25,
      bool includeDeleted = false,
      int? searchAround,
      Function? onSupplementalDataLoaded}) async {
    if (kIsWeb || chat.id == null) return [];

    final totalStopwatch = Stopwatch()..start();

    // PHASE 1: Query messages with attachments using interface/actions pattern
    final messages = await ChatInterface.getMessagesAsync(
      chatId: chat.id!,
      chatGuid: chat.guid,
      participantsData: chat.handles.map((e) => e.toMap()).toList(),
      offset: offset,
      limit: limit,
      includeDeleted: includeDeleted,
      searchAround: searchAround,
    );

    if (messages.isEmpty) {
      return messages;
    }

    // PHASE 2: Load reactions in background (non-blocking)
    final messageGuids = messages.map((e) => e.guid!).toList();

    // Don't await - let this run in background and call callback when done
    _loadSupplementalDataAsync(messages, messageGuids, totalStopwatch, onSupplementalDataLoaded);

    totalStopwatch.stop();
    Logger.debug("[getMessagesAsync] RETURNED (Phase 1 complete): ${totalStopwatch.elapsedMilliseconds}ms");

    // Return messages immediately (reactions/attachments will be added later)
    return messages;
  }

  /// Load reactions in background and append to messages
  static Future<void> _loadSupplementalDataAsync(
    List<Message> messages,
    List<String> messageGuids,
    Stopwatch totalStopwatch,
    Function? onComplete,
  ) async {
    final supplementalStopwatch = Stopwatch()..start();

    try {
      var associatedMessages = await ChatInterface.loadSupplementalData(
        messageGuids: messageGuids,
      );

      Logger.debug("[getMessagesAsync] Phase 2 - Supplemental query: ${supplementalStopwatch.elapsedMilliseconds}ms");

      // Normalize reactions
      associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);

      // Append reactions to original messages
      int messagesWithReactions = 0;
      for (Message m in messages) {
        final messageReactions = associatedMessages.where((e) => e.associatedMessageGuid == m.guid).toList();
        m.associatedMessages = messageReactions;
        if (messageReactions.isNotEmpty) {
          messagesWithReactions++;
          Logger.debug("[getMessagesAsync] Phase 2 - Added ${messageReactions.length} reactions to message ${m.guid}",
              tag: "MessageReactivity");
        }
      }

      supplementalStopwatch.stop();
      Logger.debug(
          "[getMessagesAsync] Phase 2 - COMPLETE: ${supplementalStopwatch.elapsedMilliseconds}ms (${associatedMessages.length} reactions on $messagesWithReactions messages)");

      // Notify caller that supplemental data has been loaded
      if (onComplete != null) {
        Logger.debug("[getMessagesAsync] Phase 2 - Calling onComplete callback", tag: "MessageReactivity");
        onComplete();
      } else {
        Logger.warn("[getMessagesAsync] Phase 2 - No onComplete callback provided!", tag: "MessageReactivity");
      }
    } catch (ex, stacktrace) {
      Logger.error("Failed to load supplemental data for messages", error: ex, trace: stacktrace);
    }
  }

  void webSyncParticipants() {}

  /// Toggle pin status - pure DB operation
  /// Note: For full pin toggle with service updates, use ChatsSvc.toggleChatPin
  Future<Chat> togglePinAsync(bool isPinned) async {
    if (id == null) return this;
    this.isPinned = isPinned;
    _pinIndex.value = null;
    await saveAsync(updateIsPinned: true, updatePinIndex: true);
    return this;
  }

  Future<Chat> toggleMuteAsync(bool isMuted) async {
    if (id == null) return this;
    muteType = isMuted ? "mute" : null;
    muteArgs = null;
    await saveAsync(updateMuteType: true, updateMuteArgs: true);
    return this;
  }

  /// Toggle archive status - pure DB operation
  /// Note: For full archive toggle with service updates, use ChatsSvc.toggleChatArchive
  Future<Chat> toggleArchivedAsync(bool isArchived) async {
    if (id == null) return this;
    isPinned = false;
    this.isArchived = isArchived;
    await saveAsync(updateIsPinned: true, updateIsArchived: true);
    return this;
  }

  Future<Chat> toggleAutoReadAsync(bool? autoSendReadReceipts) async {
    if (id == null) return this;
    this.autoSendReadReceipts = autoSendReadReceipts;
    await saveAsync(updateAutoSendReadReceipts: true);
    if (autoSendReadReceipts ?? SettingsSvc.settings.privateMarkChatAsRead.value) {
      HttpSvc.chat.markRead(guid);
    }
    return this;
  }

  Future<Chat> toggleAutoTypeAsync(bool? autoSendTypingIndicators) async {
    if (id == null) return this;
    this.autoSendTypingIndicators = autoSendTypingIndicators;
    await saveAsync(updateAutoSendTypingIndicators: true);
    if (!(autoSendTypingIndicators ?? SettingsSvc.settings.privateSendTypingIndicators.value)) {
      unawaited(ChatInterface.stopTyping(chatGuid: guid));
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
      final query = Database.chats.query(Chat_.guid.equals(guid)).build();
      final result = query.findFirst();
      query.close();
      return result;
    } else if (chatIdentifier != null) {
      final query = Database.chats.query(Chat_.chatIdentifier.equals(chatIdentifier)).build();
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static Future<List<Chat>> getChatsAsync({int limit = 15, int offset = 0, List<int> ids = const []}) async {
    if (kIsWeb) throw Exception("Use socket to get chats on Web!");

    final chats = await ChatInterface.getChatsAsync(
      limit: limit,
      offset: offset,
      ids: ids,
    );

    // Populate contact name cache on main thread for ALL chats in one transaction
    // The cache populated in the isolate doesn't transfer through JSON serialization
    // Database.runInTransaction(TxMode.read, () {
    //   for (Chat c in chats) {
    //     // Re-fetch handles from ObjectBox to get proper instances with relationships
    //     if (c._participants.isNotEmpty) {
    //       final handleIds = c._participants.map((h) => h.id).whereType<int>().where((id) => id != 0).toList();
    //       if (handleIds.isNotEmpty) {
    //         final handlesBox = Database.handles;
    //         final fetchedHandles = handlesBox.getMany(handleIds).whereType<Handle>().toList();
    //         c._participants = fetchedHandles;

    //         // Cache contact names while in transaction
    //         for (final handle in c._participants) {
    //           Logger.debug('[TEST] Handle has formatted address: ${handle.formattedAddress}');
    //           final contactCount = handle.contactsV2.length;
    //           if (contactCount > 0) {
    //             handle.cachedContactName = handle.contactsV2.first.displayName;
    //           } else {
    //             handle.cachedContactName = null;
    //           }
    //         }
    //       }
    //     }
    //   }
    // });

    return chats;
  }

  static Future<List<Chat>> bulkSyncChats(List<Chat> chats) async {
    if (kIsWeb) throw Exception("Web does not support saving chats!");
    if (chats.isEmpty) return [];

    return (await ChatInterface.bulkSyncChats(
      chatsData: chats.map((e) => e.toMap()).toList(),
    ))
        .chats;
  }

  void clearTranscript() {
    if (kIsWeb) return;
    Database.runInTransaction(TxMode.write, () {
      final toDelete = List<Message>.from(messages);
      for (Message element in toDelete) {
        element.dateDeleted = DateTime.now().toUtc();
      }
      Database.messages.putMany(toDelete);
    });
  }

  Future<void> clearTranscriptAsync() async {
    if (kIsWeb || id == null) return;

    await ChatInterface.clearTranscriptAsync(
      chatId: id!,
      chatGuid: guid,
    );
  }

  /// The messaging service this chat belongs to, derived from the GUID prefix.
  ChatServiceType get service => ChatServiceType.fromGuid(guid);

  bool get isTextForwarding => service == ChatServiceType.sms;

  bool get isSMS => service == ChatServiceType.sms;

  bool get isIMessage => service == ChatServiceType.iMessage;

  // Check style first so handles isn't required to be evaluated, which will incur a DB lookup.
  bool get isGroup => style == 43 || handles.length > 1;

  Chat merge(Chat other) {
    id ??= other.id;
    _customAvatarPath.value ??= other._customAvatarPath.value;
    _customBackgroundPath.value ??= other._customBackgroundPath.value;
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
    if (dbLatestMessage.target == null && other.dbLatestMessage.target != null) {
      setLatestMessage(other.dbLatestMessage.target!);
    }
    muteArgs ??= other.muteArgs;
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
    if (b!.isPinned! && b.pinIndex != null && (!a.isPinned! || a.pinIndex == null)) {
      return 1;
    }
    // If a is pinned & ordered, but b isn't either pinned or ordered, return accordingly
    if (a.isPinned! && a.pinIndex != null && (!b.isPinned! || b.pinIndex == null)) {
      return -1;
    }

    // Compare when one is pinned and the other isn't
    if (!a.isPinned! && b.isPinned!) {
      return 1;
    }
    if (a.isPinned! && !b.isPinned!) {
      return -1;
    }

    // Compare the last message dates (negate to sort newest first)
    final aDate = a.dbOnlyLatestMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.dbOnlyLatestMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return -aDate.compareTo(bDate);
  }

  static Future<void> getIcon(Chat c, {bool force = false}) async {
    if (!force && c.lockChatIcon) return;
    final response = await HttpSvc.chat.getIcon(c.guid).catchError((err, stack) async {
      Logger.error("Failed to get chat icon for chat ${c.getTitle()}", error: err, trace: stack);
      return Response(statusCode: 500, requestOptions: RequestOptions(path: ""));
    });
    if (response.statusCode != 200 || isNullOrEmpty(response.data)) {
      if (c.customAvatarPath != null) {
        await File(c.customAvatarPath!).delete(recursive: true);
        c.customAvatarPath = null;
        await c.saveAsync(updateCustomAvatarPath: true);
      }
    } else {
      Logger.debug("Got chat icon for chat ${c.getTitle()}");
      final file = File(FilesystemSvc.chatAvatarPath(c.guid));
      await file.create(recursive: true);
      await file.writeAsBytes(response.data);
      c.customAvatarPath = file.path;
      await c.saveAsync(updateCustomAvatarPath: true);
    }
  }

  Map<String, dynamic> toMap() {
    final participants = handles.isEmpty ? this.participants : handles.toList();
    return {
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
      "_customBackgroundPath": _customBackgroundPath.value,
      "_pinIndex": _pinIndex.value,
      "autoSendReadReceipts": autoSendReadReceipts,
      "autoSendTypingIndicators": autoSendTypingIndicators,
      "dateDeleted": dateDeleted?.millisecondsSinceEpoch,
      "style": style,
      "lockChatName": lockChatName,
      "lockChatIcon": lockChatIcon,
      "lastReadMessageGuid": lastReadMessageGuid,
      "customThemeLight": customThemeLight,
      "customThemeDark": customThemeDark,
      "textFieldText": textFieldText,
      "textFieldAttachments": textFieldAttachments,
      "dbOnlyLatestMessageDate": dbOnlyLatestMessageDate?.millisecondsSinceEpoch,
      "dbLatestMessageId": dbLatestMessage.targetId,
    };
  }
}
