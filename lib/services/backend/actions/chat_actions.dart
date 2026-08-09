import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/contact_v2_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

class ChatActions {
  static Future<void> clearNotificationForChat(dynamic data) async {
    if (kIsDesktop || kIsWeb) return;
    final chatId = data['chatId'] as int;

    await MethodChannelSvc.actions.deleteNotification(notificationId: chatId, tag: 'new_message');
  }

  static Future<void> markAllChatsRead(dynamic data) async {
    final chatIds = (data['chatIds'] as List).cast<int>();
    final shouldMarkOnServer = data['shouldMarkOnServer'] as bool;

    final chats = Database.chats.getMany(chatIds).whereType<Chat>().toList();
    for (final c in chats) {
      c.hasUnreadMessage = false;
    }
    Database.runInTransaction(TxMode.write, () {
      Database.chats.putMany(chats);
    });

    if (shouldMarkOnServer &&
        SettingsSvc.settings.enablePrivateAPI.value &&
        SettingsSvc.settings.privateMarkChatAsRead.value) {
      for (final c in chats) {
        await HttpSvc.chat.markRead(c.guid);
      }
    }
  }

  static Future<void> markChatReadUnread(dynamic data) async {
    final chatGuid = data['chatGuid'] as String;
    final markAsRead = data['markAsRead'] as bool;
    final shouldMarkOnServer = data['shouldMarkOnServer'] as bool;

    if (shouldMarkOnServer && SettingsSvc.settings.enablePrivateAPI.value) {
      if (markAsRead) {
        await HttpSvc.chat.markRead(chatGuid);
      } else {
        await HttpSvc.chat.markUnread(chatGuid);
      }
    }
  }

  static Future<void> startTyping(dynamic data) async {
    final chatGuid = data['chatGuid'] as String;
    await HttpSvc.chat.startTyping(chatGuid);
  }

  static Future<void> stopTyping(dynamic data) async {
    final chatGuid = data['chatGuid'] as String;
    await HttpSvc.chat.stopTyping(chatGuid);
  }

  static Future<int?> saveChat(dynamic data) async {
    final guid = data['guid'] as String;
    final updateFlags = (data['updateFlags'] as Map).cast<String, bool>();
    final chatData = data['chatData'] as Map<String, dynamic>;

    // Reconstruct the chat object and format addresses outside transaction
    final inputChat = Chat.fromMap(chatData);
    return Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;

      /// Find an existing chat
      final query = chatBox.query(Chat_.guid.equals(guid)).build();
      final existing = query.findFirst();
      query.close();

      // Use existing chat if found, otherwise create new one from input
      final chat = existing ?? inputChat;
      if (existing == null) {
        chat.id = inputChat.id;
      }

      // Update fields based on flags - use inputChat values when updating
      if (updateFlags['updateMuteType']!) {
        chat.muteType = inputChat.muteType;
      }
      if (updateFlags['updateMuteArgs']!) {
        chat.muteArgs = inputChat.muteArgs;
      }
      if (updateFlags['updateIsPinned']!) {
        chat.isPinned = inputChat.isPinned;
      }
      if (updateFlags['updatePinIndex']!) {
        chat.pinIndex = inputChat.pinIndex;
      }
      if (updateFlags['updateIsArchived']!) {
        chat.isArchived = inputChat.isArchived;
      }
      if (updateFlags['updateHasUnreadMessage']!) {
        chat.hasUnreadMessage = inputChat.hasUnreadMessage;
      }
      if (updateFlags['updateAutoSendReadReceipts']!) {
        chat.autoSendReadReceipts = inputChat.autoSendReadReceipts;
      }
      if (updateFlags['updateAutoSendTypingIndicators']!) {
        chat.autoSendTypingIndicators = inputChat.autoSendTypingIndicators;
      }
      if (updateFlags['updateCustomAvatarPath']!) {
        chat.customAvatarPath = inputChat.customAvatarPath;
      }
      if (updateFlags['updateCustomBackgroundPath']!) {
        chat.customBackgroundPath = inputChat.customBackgroundPath;
      }
      if (updateFlags['updateTextFieldText']!) {
        chat.textFieldText = inputChat.textFieldText;
      }
      if (updateFlags['updateTextFieldAttachments']!) {
        chat.textFieldAttachments = inputChat.textFieldAttachments;
      }
      if (updateFlags['updateDisplayName']!) {
        chat.displayName = inputChat.displayName;
      }
      if (updateFlags['updateDateDeleted']!) {
        chat.dateDeleted = inputChat.dateDeleted;
      }
      if (updateFlags['updateLockChatName']!) {
        chat.lockChatName = inputChat.lockChatName;
      }
      if (updateFlags['updateLockChatIcon']!) {
        chat.lockChatIcon = inputChat.lockChatIcon;
      }
      if (updateFlags['updateLastReadMessageGuid']!) {
        chat.lastReadMessageGuid = inputChat.lastReadMessageGuid;
      }
      if (updateFlags['updateCustomThemes'] == true) {
        chat.customThemeLight = inputChat.customThemeLight;
        chat.customThemeDark = inputChat.customThemeDark;
      }
      if (updateFlags['updateLatestMessage'] == true) {
        final latestMessageId = chatData['dbLatestMessageId'] as int?;
        final latestMessageDateMs = chatData['dbOnlyLatestMessageDate'] as int?;
        if (latestMessageId != null && latestMessageId > 0) {
          chat.dbLatestMessage.targetId = latestMessageId;
        }
        if (latestMessageDateMs != null) {
          chat.dbOnlyLatestMessageDate = DateTime.fromMillisecondsSinceEpoch(latestMessageDateMs);
        }
      }

      try {
        chat.id = chatBox.put(chat);
      } on UniqueViolationException catch (_) {}

      return chat.id;
    });
  }

  static Future<void> deleteChat(dynamic data) async {
    final chatId = data['chatId'] as int;
    final messageIds = (data['messageIds'] as List).cast<int>();
    final handleIds = (data['handleIds'] as List? ?? []).cast<int>();

    Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;
      final messageBox = Database.messages;
      final handleBox = Database.handles;

      /// Remove all references of chat and its messages
      chatBox.remove(chatId);
      messageBox.removeMany(messageIds);
      if (handleIds.isNotEmpty) {
        handleBox.removeMany(handleIds);
      }
    });
  }

  static Future<void> softDeleteChat(dynamic data) async {
    final chatData = data['chatData'] as Map<String, dynamic>;
    final inputChat = Chat.fromMap(chatData);

    Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;

      // Find the chat in the database
      final query = chatBox.query(Chat_.guid.equals(inputChat.guid)).build();
      query.limit = 1;
      final dbChat = query.findFirst();
      query.close();

      if (dbChat != null) {
        dbChat.dateDeleted = DateTime.now().toUtc();
        dbChat.hasUnreadMessage = false;
        chatBox.put(dbChat);
      }
    });
  }

  static Future<void> unDeleteChat(dynamic data) async {
    final chatData = data['chatData'] as Map<String, dynamic>;
    final inputChat = Chat.fromMap(chatData);

    Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;

      // Find the chat in the database
      final query = chatBox.query(Chat_.guid.equals(inputChat.guid)).build();
      query.limit = 1;
      final dbChat = query.findFirst();
      query.close();

      if (dbChat != null) {
        dbChat.dateDeleted = null;
        chatBox.put(dbChat);
      }
    });
  }

  static Future<Map<String, dynamic>> addMessageToChat(dynamic data) async {
    final messageData = data['messageData'] as Map<String, dynamic>;
    final attachmentsData = ((data['attachmentsData'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final chatData = data['chatData'] as Map<String, dynamic>;
    final latestMessageData = data['latestMessageData'] as Map<String, dynamic>;
    final checkForMessageText = data['checkForMessageText'] as bool;

    return Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;
      final attachmentBox = Database.attachments;
      final handleBox = Database.handles;
      final chatBox = Database.chats;

      // Deserialize inputs
      final inputMessage = Message.fromMap(messageData);
      final inputAttachments = attachmentsData.map(Attachment.fromMap).toList();
      final inputChat = Chat.fromMap(chatData);
      final inputLatest = Message.fromMap(latestMessageData);

      // Find existing message
      final msgQuery = messageBox.query(Message_.guid.equals(inputMessage.guid ?? '')).build();
      msgQuery.limit = 1;
      Message? existing = msgQuery.findFirst();
      msgQuery.close();

      if (existing != null) {
        inputMessage.id = existing.id;
        inputMessage.text ??= existing.text;
      }

      // Prepare handle reference (find or create handle, but don't set relation yet).
      // From-me messages have no sender handle to resolve: handleId 0 is Apple's
      // "from me" marker (and fromMap defaults absent handleIds to 0). Attempting
      // resolution for them logged bogus "could not resolve handle" errors and, in
      // 1:1 chats, mislinked the RECIPIENT's handle as the message's sender.
      final bool hasSenderHandle = !(inputMessage.isFromMe ?? false) && (inputMessage.handleId ?? 0) != 0;
      Handle? handleToLink;
      if (inputMessage.handle == null && hasSenderHandle) {
        final handleQuery = handleBox.query(Handle_.originalROWID.equals(inputMessage.handleId!)).build();
        handleQuery.limit = 1;
        handleToLink = handleQuery.findFirst();
        handleQuery.close();

        // Fallback for brand-new chats: bulkSyncChats may have persisted the
        // sender handle without an originalROWID (older payloads). If the chat
        // is a 1:1, we can safely link the message to the sole non-me participant.
        if (handleToLink == null) {
          final chatQuery = chatBox.query(Chat_.guid.equals(inputChat.guid)).build();
          chatQuery.limit = 1;
          final dbChat = chatQuery.findFirst();
          chatQuery.close();
          final chatHandles = dbChat?.handles.toList() ?? const <Handle>[];
          if (chatHandles.length == 1) {
            handleToLink = chatHandles.first;
            Logger.warn(
              'Linked message ${inputMessage.guid} to sole participant ${handleToLink.address} '
              '(originalROWID lookup for handleId=${inputMessage.handleId} failed)',
              tag: 'ChatActions',
            );
          } else {
            Logger.error(
              'Could not resolve handle for message ${inputMessage.guid} in chat ${inputChat.guid} '
              '(handleId=${inputMessage.handleId}, chatHandles=${chatHandles.length}) — '
              'notification will be skipped',
              tag: 'ChatActions',
            );
          }
        }
      } else if (inputMessage.handle != null) {
        // Try and find existing handle by unique address
        final existingHandleQuery = handleBox
            .query(Handle_.uniqueAddressAndService.equals(inputMessage.handle!.uniqueAddressAndService))
            .build();
        existingHandleQuery.limit = 1;
        final existingHandle = existingHandleQuery.findFirst();
        existingHandleQuery.close();

        if (existingHandle != null) {
          handleToLink = existingHandle;
        } else {
          // Save new handle
          final handleId = handleBox.put(inputMessage.handle!);
          inputMessage.handle!.id = handleId;
          handleToLink = inputMessage.handle;
        }
      }

      // Handle associated messages (reactions)
      if (inputMessage.associatedMessageType != null && inputMessage.associatedMessageGuid != null) {
        final assocQuery = messageBox.query(Message_.guid.equals(inputMessage.associatedMessageGuid!)).build();
        assocQuery.limit = 1;
        final associatedMessage = assocQuery.findFirst();
        assocQuery.close();

        if (associatedMessage != null) {
          associatedMessage.hasReactions = true;
          messageBox.put(associatedMessage);
        }
      } else if (!inputMessage.hasReactions) {
        final reactionQuery = messageBox.query(Message_.associatedMessageGuid.equals(inputMessage.guid ?? '')).build();
        reactionQuery.limit = 1;
        final reaction = reactionQuery.findFirst();
        reactionQuery.close();

        if (reaction != null) {
          inputMessage.hasReactions = true;
        }
      }

      // Link chat to message
      final chatQuery = chatBox.query(Chat_.guid.equals(inputChat.guid)).build();
      chatQuery.limit = 1;
      final dbChat = chatQuery.findFirst();
      chatQuery.close();

      if (dbChat != null) {
        inputMessage.chat.target = dbChat;
      }

      // Save the message
      int? messageId;
      try {
        messageId = messageBox.put(inputMessage);
        inputMessage.id = messageId;
      } on UniqueViolationException catch (_) {
        // If unique violation, try to find the message again
        final retryQuery = messageBox.query(Message_.guid.equals(inputMessage.guid ?? '')).build();
        retryQuery.limit = 1;
        final retryResult = retryQuery.findFirst();
        retryQuery.close();
        inputMessage.id = retryResult?.id;
        messageId = retryResult?.id;
      } catch (e, s) {
        Logger.error('[addMessageToChat] Failed to save message!', error: e, trace: s);
      }

      // Fetch the DB-connected message object once to set all relationships
      if (messageId != null) {
        final dbMessage = messageBox.get(messageId);
        if (dbMessage != null) {
          bool needsUpdate = false;

          // Set handle relationship if needed
          if (handleToLink != null && dbMessage.handleRelation.target == null) {
            dbMessage.handleRelation.target = handleToLink;
            needsUpdate = true;
          }

          // Process and link attachments if present
          if (inputAttachments.isNotEmpty) {
            for (final attachment in inputAttachments) {
              // Find existing attachment
              final attachQuery = attachmentBox.query(Attachment_.guid.equals(attachment.guid ?? '')).build();
              attachQuery.limit = 1;
              final existingAttach = attachQuery.findFirst();
              attachQuery.close();

              if (existingAttach != null) {
                attachment.id = existingAttach.id;
              }

              // Link the DB-connected message to attachment
              attachment.message.target = dbMessage;

              try {
                attachmentBox.put(attachment);
              } on UniqueViolationException catch (_) {
                Logger.warn('[addMessageToChat] UniqueViolationException for attachment ${attachment.guid}');
              } catch (e, s) {
                Logger.error('[addMessageToChat] Failed to save attachment!', error: e, trace: s);
              }
            }

            // Populate the ToMany relationship so getNotificationText() immediately
            // sees the attachments without waiting for lazy-load
            dbMessage.dbAttachments.addAll(inputAttachments.where((a) => a.id != null));
            dbMessage.dbAttachments.applyToDb();
            needsUpdate = true;
          }

          // Single final put if any relationships were modified
          if (needsUpdate) {
            messageBox.put(dbMessage);
          }
        }
      }

      // Calculate if message is newer
      bool isNewerInIsolate = false;
      if ((messageId != null || kIsWeb) && checkForMessageText) {
        isNewerInIsolate = inputMessage.dateCreated!.isAfter(inputLatest.dateCreated!) ||
            (inputMessage.guid != inputLatest.guid && inputMessage.dateCreated == inputLatest.dateCreated);
      }

      return <String, dynamic>{
        'messageId': messageId,
        'isNewer': isNewerInIsolate,
      };
    });
  }

  static Future<List<int>> loadSupplementalData(dynamic data) async {
    final messageGuids = (data['messageGuids'] as List).cast<String>();

    return Database.runInTransaction(TxMode.read, () {
      final messageBox = Database.messages;

      // Query reactions and return just their IDs
      final reactionsQuery =
          (messageBox.query(Message_.associatedMessageGuid.oneOf(messageGuids))..order(Message_.originalROWID)).build();
      final reactions = reactionsQuery.find();
      reactionsQuery.close();

      // Return just the reaction message IDs
      // Hydration will happen on the main thread with proper DB connection
      return reactions.map((e) => e.id!).toList();
    });
  }

  static Future<List<int>> syncLatestMessages(dynamic data) async {
    final chatGuids = (data['chatGuids'] as List).cast<String>();
    final toggleUnread = data['toggleUnread'] as bool;

    return Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;
      final messageBox = Database.messages;

      // Get the latest versions of the chats
      final chatQuery = chatBox.query(Chat_.guid.oneOf(chatGuids)).build();
      List<Chat> existingChats = chatQuery.find();
      chatQuery.close();

      if (existingChats.isEmpty) return <int>[];

      // Pull the latest message for all of the chats
      List<int> chatIds = existingChats.map((e) => e.id!).toList();
      List<Chat> updatedChats = [];

      for (int chatId in chatIds) {
        // Fetch latest message for the chat
        final latestMsgQuery = (messageBox.query(Message_.dateCreated.notNull())
              ..link(Message_.chat, Chat_.id.equals(chatId))
              ..order(Message_.dateCreated, flags: Order.descending))
            .build();
        latestMsgQuery.limit = 1;
        final latestMessages = latestMsgQuery.find();
        latestMsgQuery.close();

        Message? latestMessage = latestMessages.firstOrNull;
        if (latestMessage?.handle == null && latestMessage?.handleId != null && latestMessage?.handleId != 0) {
          final handleQuery = Database.handles.query(Handle_.originalROWID.equals(latestMessage!.handleId!)).build();
          handleQuery.limit = 1;
          latestMessage.handle = handleQuery.findFirst();
          handleQuery.close();
        }

        Chat current = existingChats.firstWhere((element) => element.id == chatId);

        // Try and update the last message info
        bool didUpdate = _tryUpdateLastMessage(current, latestMessage, toggleUnread);
        if (didUpdate) {
          updatedChats.add(current);
        }
      }

      // If we have updates to make, apply them
      if (updatedChats.isNotEmpty) {
        chatBox.putMany(updatedChats, mode: PutMode.update);
      }

      // Return just the IDs for efficient transfer across isolates
      return existingChats.map((e) => e.id!).toList();
    });
  }

  static bool _tryUpdateLastMessage(Chat chat, Message? lastMessage, bool toggleUnread) {
    // If we don't even have a last message, return false
    if (lastMessage == null || lastMessage.dateCreated == null) return false;

    bool didUpdate = false;
    bool checkMessageText = false;

    int currentMs = chat.dbOnlyLatestMessageDate?.millisecondsSinceEpoch ?? 0;
    int lastMs = lastMessage.dateCreated!.millisecondsSinceEpoch;
    if (currentMs <= lastMs) {
      didUpdate = true;

      if (currentMs == lastMs) {
        checkMessageText = true;
      }
    }

    // If we plan to update the message, but the dates are the same,
    if (didUpdate && checkMessageText) {
      if ((chat.dbLatestMessage.target?.getNotificationText() ?? '') == lastMessage.getNotificationText()) {
        didUpdate = false;
      }
    }

    // If we still want to update the info, do so
    if (didUpdate) {
      chat.setLatestMessage(lastMessage);

      // Mark the chat as unread if we updated the last message & it's not from us
      if (toggleUnread && !(lastMessage.isFromMe ?? false)) {
        chat.toggleHasUnreadAsync(true);
      }
    }

    return didUpdate;
  }

  static Future<Map<String, dynamic>> bulkSyncChats(dynamic data) async {
    final chatsData = (data['chatsData'] as List).cast<Map<String, dynamic>>();
    final inputChats = chatsData.map((e) => Chat.fromMap(e)).toList();

    // Tracks handles that did not exist in the DB before this sync.
    // Contact matching is attempted for these after the main transaction.
    final List<Handle> brandNewHandles = [];

    // 1. Extract all unique handles from the input chats
    final Map<String, Handle> inputHandlesMap = {};
    for (final chat in inputChats) {
      // Use participants here because handles will be empty on inputChat.
      // This is because handles are a ToMany relation that isn't passed across isolates
      if (chat.participants.isNotEmpty) {
        for (final participant in chat.participants) {
          if (!inputHandlesMap.containsKey(participant.uniqueAddressAndService)) {
            inputHandlesMap[participant.uniqueAddressAndService] = participant;
          }
        }
      } else if (chat.guid.contains(';-;')) {
        // Basic check to see if it's a DM with an address in the GUID
        // If the participants list is empty, try and extract the handle from the chat's GUID
        final address = chat.guid.split(';-;').lastOrNull;

        // If we have an address, try finding a handle for it and add it to the map if found
        if (address != null) {
          final handleQuery = Database.handles.query(Handle_.address.equals(address)).build();
          handleQuery.limit = 1;
          final handle = handleQuery.findFirst();
          handleQuery.close();

          if (handle != null) {
            inputHandlesMap[handle.uniqueAddressAndService] = handle;
          }
        }
      }
    }

    // 2. Update formatted addresses for all handles (Async, outside transaction)
    for (final handle in inputHandlesMap.values) {
      await handle.updateFormattedAddress();
    }

    final chatIds = Database.runInTransaction(TxMode.write, () {
      final chatBox = Database.chats;
      final handleBox = Database.handles;

      // 3. Sync Handles
      // Get all existing handles that match our input handles
      final inputAddresses = inputHandlesMap.keys.toList();
      final existingHandlesQuery = handleBox.query(Handle_.uniqueAddressAndService.oneOf(inputAddresses)).build();
      final existingHandles = existingHandlesQuery.find();
      existingHandlesQuery.close();

      // Map existing handles for easy lookup
      final Map<String, Handle> existingHandlesMap = {};
      for (final h in existingHandles) {
        existingHandlesMap[h.uniqueAddressAndService] = h;
      }

      // Prepare handles to save
      final List<Handle> handlesToSave = [];
      for (final inputHandle in inputHandlesMap.values) {
        final existing = existingHandlesMap[inputHandle.uniqueAddressAndService];
        if (existing != null) {
          inputHandle.id = existing.id;
          handlesToSave.add(inputHandle);
        } else {
          // Brand-new handle — track it so we can attempt contact matching after the transaction.
          brandNewHandles.add(inputHandle);
          handlesToSave.add(inputHandle);
        }
      }

      // Save handles to DB
      handleBox.putMany(handlesToSave);

      // Re-map valid handles with IDs for linking
      final Map<String, Handle> validHandles = {};
      for (final h in handlesToSave) {
        validHandles[h.uniqueAddressAndService] = h;
      }

      // 4. Sync Chats
      final inputChatGuids = inputChats.map((e) => e.guid).toList();
      final existingChatsQuery = chatBox.query(Chat_.guid.oneOf(inputChatGuids)).build();
      final existingChats = existingChatsQuery.find();
      existingChatsQuery.close();

      final Map<String, Chat> existingChatsMap = {};
      for (final c in existingChats) {
        existingChatsMap[c.guid] = c;
      }

      // Create map of input chats for easy lookup
      final Map<String, Chat> inputChatsMap = {};
      for (final c in inputChats) {
        inputChatsMap[c.guid] = c;
      }

      final List<Chat> chatsToSave = [];
      final Map<String, List<Handle>> chatHandlesMap = {};

      for (final inputChat in inputChats) {
        final existing = existingChatsMap[inputChat.guid];

        // Use existing DB record as the base so that user-local fields
        // (pin, archive, mute, custom avatar, etc.) are preserved.
        Chat chatToSave = existing ?? inputChat;

        // Apply server-controlled fields onto the existing record so that
        // changes originating on the server (e.g. a group name change) are
        // persisted.  User-preference fields are intentionally left alone.
        if (existing != null) {
          if (!chatToSave.lockChatName) {
            chatToSave.displayName = inputChat.displayName;
          }
        }

        // Prepare handles to link (collect them for later)
        final handlesToLink = <Handle>[];
        // Use participants here because handles will be empty on inputChat.
        // This is because handles are a ToMany relation that isn't passed across isolates
        for (final participant in inputChat.participants) {
          final validHandle = validHandles[participant.uniqueAddressAndService];
          if (validHandle != null) {
            handlesToLink.add(validHandle);
          }
        }

        chatHandlesMap[inputChat.guid] = handlesToLink;
        chatsToSave.add(chatToSave);
      }

      // Save chats first
      chatBox.putMany(chatsToSave);

      // Now link handles to chats using fresh DB copies
      for (final chatToSave in chatsToSave) {
        final handlesToLink = chatHandlesMap[chatToSave.guid];
        if (handlesToLink != null && handlesToLink.isNotEmpty) {
          final freshChat = chatBox.get(chatToSave.id!);
          if (freshChat != null) {
            freshChat.handles.clear();
            freshChat.handles.addAll(handlesToLink);
            freshChat.handles.applyToDb();
          }
        }
      }

      // Return just the IDs for efficient transfer across isolates
      return chatsToSave.map((e) => e.id!).toList();
    });

    // 5. For any brand-new handles, attempt to find and link a matching ContactV2.
    //    This runs after the write transaction so we can open a separate write tx per match.
    //    Guards against web (no ObjectBox) and against an empty contacts DB (desktop).
    final List<int> affectedHandleIds = [];
    if (brandNewHandles.isNotEmpty && !kIsWeb) {
      for (final handle in brandNewHandles) {
        if (handle.id == null) continue;
        final contact = await ContactV2Interface.getContactByAddress(address: handle.address);
        if (contact == null) continue;

        Database.runInTransaction(TxMode.write, () {
          contact.handles.add(handle);
          Database.contactsV2.put(contact);
        });

        affectedHandleIds.add(handle.id!);
        Logger.info(
          'Linked new handle ${handle.address} to contact ${contact.computedDisplayName}',
          tag: 'ChatActions',
        );
      }
    }

    return {'chatIds': chatIds, 'affectedHandleIds': affectedHandleIds};
  }

  static Future<List<int>> getMessagesAsync(dynamic data) async {
    final chatId = data['chatId'] as int;
    final participantsData = (data['participantsData'] as List).cast<Map<String, dynamic>>();
    final offset = data['offset'] as int? ?? 0;
    final limit = data['limit'] as int? ?? 25;
    final includeDeleted = data['includeDeleted'] as bool? ?? false;
    final searchAround = data['searchAround'] as int?;

    return Database.runInTransaction(TxMode.read, () {
      final participants = participantsData.map((e) => Handle.fromMap(e)).toList();
      final messageBox = Database.messages;
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
        messages.addAll(beforeQuery.find());
        beforeQuery.close();

        final afterQuery = (messageBox.query(Message_.dateCreated.greaterThan(searchAround).and(includeDeleted
                ? Message_.dateCreated.notNull().and(Message_.dateDeleted.isNull().or(Message_.dateDeleted.notNull()))
                : Message_.dateDeleted.isNull().and(Message_.dateCreated.notNull())))
              ..link(Message_.chat, Chat_.id.equals(chatId))
              ..order(Message_.dateCreated))
            .build();
        afterQuery.limit = limit;
        messages.addAll(afterQuery.find());
        afterQuery.close();
      }

      // Handle matching - filter out messages that don't match participant requirements
      for (int i = 0; i < messages.length; i++) {
        Message message = messages[i];
        if (participants.isNotEmpty && !message.isFromMe! && message.handleId != null && message.handleId != 0) {
          Handle? handle =
              participants.firstWhereOrNull((e) => e.originalROWID == message.handleId) ?? message.getHandle();
          if (handle == null && message.originalROWID != null) {
            messages.remove(message);
            i--;
          }
        }
      }

      // Return only message IDs
      return messages.map((e) => e.id!).toList();
    });
  }

  static Future<List<int>> getParticipantsAsync(dynamic data) async {
    final chatId = data['chatId'] as int;

    return Database.runInTransaction(TxMode.read, () {
      final query = Database.chats.query(Chat_.id.equals(chatId)).build();
      final chat = query.findFirst();
      query.close();

      if (chat == null) return <int>[];

      // Return only handle IDs
      return List<Handle>.from(chat.handles).map((e) => e.id!).toList();
    });
  }

  static Future<void> clearTranscriptAsync(dynamic data) async {
    final chatId = data['chatId'] as int;

    Database.runInTransaction(TxMode.write, () {
      final query = Database.chats.query(Chat_.id.equals(chatId)).build();
      final chat = query.findFirst();
      query.close();

      if (chat == null) return;

      final toDelete = List<Message>.from(chat.messages);
      for (Message element in toDelete) {
        element.dateDeleted = DateTime.now().toUtc();
      }
      Database.messages.putMany(toDelete);
    });
  }

  static Future<List<int>> getChatsAsync(dynamic data) async {
    final limit = data['limit'] as int? ?? 15;
    final offset = data['offset'] as int? ?? 0;
    final ids = (data['ids'] as List?)?.cast<int>() ?? const <int>[];

    // Fetch chat IDs in a read transaction
    return Database.runInTransaction(TxMode.read, () {
      final chatBox = Database.chats;
      late final QueryBuilder<Chat> queryBuilder;

      // If IDs are provided, query by IDs. Otherwise, query non-deleted chats
      // ordered by dbOnlyLatestMessageDate so chats arrive roughly pre-sorted,
      // reducing binary-search work in _insertChatSorted (pins are reordered there).
      if (ids.isNotEmpty) {
        queryBuilder = chatBox.query(Chat_.id.oneOf(ids));
      } else {
        queryBuilder = chatBox.query(Chat_.dateDeleted.isNull())
          ..order(Chat_.dbOnlyLatestMessageDate, flags: Order.descending);
      }

      // Build the query with limit and offset
      final query = queryBuilder.build()
        ..limit = limit
        ..offset = offset;

      // Execute the query and return just the IDs
      final result = query.find();
      query.close();

      // Return just the IDs for efficient transfer across isolates
      return result.map((e) => e.id!).toList();
    });
  }
}
