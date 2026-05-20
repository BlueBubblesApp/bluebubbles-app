import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';

class MessageActions {
  static Future<List<Message>?> getMessages() async {
    // Fetch a message with a limit of 1 using ObjectBox
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    final messages = (await Database.messages
        .query(Message_.dateCreated.greaterThan(oneDayAgo.millisecondsSinceEpoch))
        .build()
        .findAsync());
    if (messages.isNotEmpty) {
      return messages;
    }
    return null;
  }

  static Future<List<int>> bulkSaveNewMessages(dynamic data) async {
    final chatData = data['chatData'] as Map<String, dynamic>;
    final messagesData = (data['messagesData'] as List).cast<Map<String, dynamic>>();

    return Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;
      final attachmentBox = Database.attachments;
      final handleBox = Database.handles;

      final inputChat = Chat.fromMap(chatData);
      final inputMessages = messagesData.map((e) => Message.fromMap(e)).toList();
      final messageAttachmentsData = <String, List<Map<String, dynamic>>>{};
      for (final raw in messagesData) {
        final guid = raw['guid'] as String?;
        if (guid == null) continue;
        final attachments =
            ((raw['attachments'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        if (attachments.isNotEmpty) {
          messageAttachmentsData[guid] = attachments;
        }
      }
      final inputMessageGuids = inputMessages.map((element) => element.guid!).toList();

      // 0. Create map for the messages and attachments to save
      Map<String, Attachment> attachmentsToSave = {};
      Map<String, List<String>> messageAttachments = {};
      for (final msg in inputMessages) {
        final rawAttachments = messageAttachmentsData[msg.guid] ?? const <Map<String, dynamic>>[];
        for (final raw in rawAttachments) {
          final a = Attachment.fromMap(raw);
          if (!attachmentsToSave.containsKey(a.guid)) {
            attachmentsToSave[a.guid!] = a;
          }

          if (!messageAttachments.containsKey(msg.guid)) {
            messageAttachments[msg.guid!] = [];
          }

          if (!messageAttachments[msg.guid]!.contains(a.guid)) {
            messageAttachments[msg.guid]?.add(a.guid!);
          }
        }
      }

      // 1. Check for existing attachments and save new ones
      Map<String, Attachment> attachmentMap = {};
      if (attachmentsToSave.isNotEmpty) {
        List<String> inputAttachmentGuids = attachmentsToSave.values.map((e) => e.guid).nonNulls.toList();
        final attachmentQuery = attachmentBox.query(Attachment_.guid.oneOf(inputAttachmentGuids)).build();
        List<String> existingAttachmentGuids = attachmentQuery.find().map((e) => e.guid).nonNulls.toList();
        attachmentQuery.close();

        // Insert the attachments that don't yet exist
        List<Attachment> attachmentsToInsert = attachmentsToSave.values
            .where((element) => !existingAttachmentGuids.contains(element.guid))
            .nonNulls
            .toList();
        attachmentBox.putMany(attachmentsToInsert);

        // 2. Fetch all inserted/existing attachments based on input
        final attachmentQuery2 = attachmentBox.query(Attachment_.guid.oneOf(inputAttachmentGuids)).build();
        List<Attachment> attachments = attachmentQuery2.find().nonNulls.toList();
        attachmentQuery2.close();

        // 3. Create map of inserted/existing attachments
        for (final a in attachments) {
          attachmentMap[a.guid!] = a;
        }
      }

      // 4. Check for existing messages & create map of existing messages by GUID
      final messageQuery = messageBox.query(Message_.guid.oneOf(inputMessageGuids)).build();
      List<Message> existingMessages = messageQuery.find();
      messageQuery.close();

      // Create a map of existing messages by GUID for quick lookup
      Map<String, Message> existingMessageMap = {};
      for (final existingMsg in existingMessages) {
        existingMessageMap[existingMsg.guid!] = existingMsg;
      }

      final newMessages = inputMessages.where((element) => !existingMessageMap.containsKey(element.guid)).toList();

      // 5. Fetch all handles and map the old handle ROWIDs from each message to the new ones based on the original ROWID
      List<Handle> handles = handleBox.getAll();

      for (final msg in newMessages) {
        msg.chat.target = inputChat;

        // For new messages from isolate, handleRelation won't be set due to serialization
        // Look up by handleId and establish the relationship
        if (msg.handleId != null && msg.handleId! > 0) {
          final foundHandle = handles.firstWhereOrNull((e) => e.originalROWID == msg.handleId);
          msg.handle = foundHandle;

          // Set up handleRelation for the ToOne relationship
          if (foundHandle != null && foundHandle.id != null) {
            msg.handleRelation.target = foundHandle;
          }
        }
      }

      // 6. Relate the attachments to the messages. Keep the per-message list
      // around so we can re-apply the @Backlink ToMany after putMany — see step 7b.
      final attachmentsPerMessage = <String, List<Attachment>>{};
      for (final msg in newMessages) {
        final relatedAttachments = messageAttachments[msg.guid]?.map((e) => attachmentMap[e]).nonNulls.toList() ?? [];
        if (relatedAttachments.isEmpty) continue;
        attachmentsPerMessage[msg.guid!] = relatedAttachments;
        msg.dbAttachments.addAll(relatedAttachments);
      }

      // 7. Save all messages (and handle/attachment relationships)
      messageBox.putMany(newMessages);

      // 7b. ObjectBox Dart does not reliably persist @Backlink ToMany changes
      // via putMany for newly-inserted entities — the link table on the inverse
      // ToOne side won't be written. Without this, dbAttachments lazy-loads as
      // empty on next read, so chats with attachment-only latest messages show
      // "Empty message" in the conversation list. Mirror the pattern used in
      // Message.save() and ChatActions.bulkSyncMessages.
      for (final msg in newMessages) {
        final atts = attachmentsPerMessage[msg.guid];
        if (atts == null || atts.isEmpty) continue;
        msg.dbAttachments
          ..clear()
          ..addAll(atts);
        msg.dbAttachments.applyToDb();
      }

      // 7c. Repair pass for existing messages whose dbAttachments backlink was
      // lost by the bug we just fixed in 7b. If the server reports attachments
      // for an existing message but the local DB has none, link them now so
      // resyncs heal historical "Empty message" chat-list entries instead of
      // requiring a wipe.
      for (final existing in existingMessages) {
        final raw = messageAttachmentsData[existing.guid];
        if (raw == null || raw.isEmpty) continue;
        if (existing.dbAttachments.isNotEmpty) continue;
        final linked = raw
            .map((m) => m['guid'] as String?)
            .whereType<String>()
            .map((g) => attachmentMap[g])
            .whereType<Attachment>()
            .toList();
        if (linked.isEmpty) continue;
        existing.dbAttachments
          ..clear()
          ..addAll(linked);
        existing.dbAttachments.applyToDb();
        if (existing.hasAttachments != true) {
          existing.hasAttachments = true;
          messageBox.put(existing);
        }
      }

      // 8. Get the inserted messages
      final messageQuery2 = messageBox.query(Message_.guid.oneOf(inputMessageGuids)).build();
      List<Message> messages = messageQuery2.find().toList();
      messageQuery2.close();

      // 9. Check inserted messages for associated message GUIDs & update hasReactions flag
      Map<String, Message> messagesToUpdate = {};
      for (final message in messages) {
        // Check if this message existed before - if so, preserve its handleRelation
        final existingMsg = existingMessageMap[message.guid];
        if (existingMsg != null && existingMsg.handleRelation.hasValue) {
          // Preserve the existing handleRelation
          message.handleRelation.target = existingMsg.handleRelation.target;
          message.handle = existingMsg.handleRelation.target;
        } else if (!message.handleRelation.hasValue && message.handleId != null && message.handleId! > 0) {
          // No existing relationship, set up from handleId
          final foundHandle = handles.firstWhereOrNull((element) => element.originalROWID == message.handleId);
          message.handle = foundHandle;

          // Set up handleRelation for the ToOne relationship
          if (foundHandle != null && foundHandle.id != null) {
            message.handleRelation.target = foundHandle;
          }
        } else if (message.handleRelation.hasValue) {
          // Use the relationship to populate handle field
          message.handle = message.handleRelation.target;
        }

        // Continue if there isn't an associated message GUID to process
        if ((message.associatedMessageGuid ?? '').isEmpty) continue;

        // Find the associated message in the DB and update the hasReactions flag
        final associatedQuery = messageBox.query(Message_.guid.equals(message.associatedMessageGuid!)).build();
        List<Message> associatedMessages = associatedQuery.find().toList();
        associatedQuery.close();

        if (associatedMessages.isNotEmpty) {
          // Toggle the hasReactions flag
          Message messageWithReaction = messagesToUpdate[associatedMessages[0].guid] ?? associatedMessages[0];
          messageWithReaction.hasReactions = true;

          // Make sure the current message has the associated message in it's list, and the hasReactions
          // flag is set as well
          Message reactionMessage = messagesToUpdate[message.guid!] ?? message;
          for (var e in messageWithReaction.associatedMessages) {
            if (e.guid == messageWithReaction.guid) {
              e.hasReactions = true;
              break;
            }
          }

          // Update the cached values
          messagesToUpdate[messageWithReaction.guid!] = messageWithReaction;
          messagesToUpdate[reactionMessage.guid!] = reactionMessage;
        }
      }

      // 10. Save the updated associated messages
      if (messagesToUpdate.isNotEmpty) {
        try {
          messageBox.putMany(messagesToUpdate.values.toList());
        } catch (ex) {
          Logger.warn('Failed to put associated messages into DB: ${ex.toString()}');
        }
      }

      // 11. Update the associated chat's last message
      messages.sort(Message.sort);
      bool isNewer = false;

      // If the message was saved correctly, update this chat's latestMessage info,
      // but only if the incoming message's date is newer
      if (messages.isNotEmpty) {
        final first = messages.first;
        if (first.id != null) {
          isNewer = first.dateCreated!.isAfter(inputChat.latestMessage.dateCreated!);
          if (isNewer) {
            inputChat.latestMessage = first;
            if (!first.isFromMe! && !ChatsSvc.isChatActive(inputChat.guid)) {
              inputChat.toggleHasUnreadAsync(true);
            }
          }
        }
      }

      return messages.map((e) => e.id!).toList();
    });
  }

  static Future<int> replaceMessage(dynamic data) async {
    final oldGuid = data['oldGuid'] as String?;
    final newMessageData = data['newMessageData'] as Map<String, dynamic>;

    return Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;
      final inputNewMessage = Message.fromMap(newMessageData);

      // Find existing message
      final query = messageBox.query(Message_.guid.equals(oldGuid ?? '')).build();
      query.limit = 1;
      final existing = query.findFirst();
      query.close();

      if (existing == null) {
        throw Exception("Cannot replace on a null existing message!!");
      }

      // We just need to update the timestamps & error
      if (existing.guid != inputNewMessage.guid) {
        existing.guid = inputNewMessage.guid;
      }
      if (inputNewMessage.text != null) {
        existing.text = inputNewMessage.text;
      }

      existing.dateDelivered = inputNewMessage.dateDelivered ?? existing.dateDelivered;
      existing.isDelivered = inputNewMessage.isDelivered;
      existing.dateRead = inputNewMessage.dateRead ?? existing.dateRead;
      existing.dateEdited = inputNewMessage.dateEdited ?? existing.dateEdited;
      existing.attributedBody =
          inputNewMessage.attributedBody.isNotEmpty ? inputNewMessage.attributedBody : existing.attributedBody;
      existing.messageSummaryInfo = inputNewMessage.messageSummaryInfo.isNotEmpty
          ? inputNewMessage.messageSummaryInfo
          : existing.messageSummaryInfo;
      existing.payloadData = inputNewMessage.payloadData ?? existing.payloadData;
      existing.wasDeliveredQuietly =
          inputNewMessage.wasDeliveredQuietly ? inputNewMessage.wasDeliveredQuietly : existing.wasDeliveredQuietly;
      existing.didNotifyRecipient =
          inputNewMessage.didNotifyRecipient ? inputNewMessage.didNotifyRecipient : existing.didNotifyRecipient;
      existing.error = inputNewMessage.error;
      existing.errorMessage = inputNewMessage.errorMessage;

      try {
        messageBox.put(existing, mode: PutMode.update);
      } catch (ex) {
        Logger.warn(
            'Failed to replace message! This is likely due to a unique constraint being violated: ${ex.toString()}');
      }

      // Return just the ID for efficient transfer across isolates
      return existing.id!;
    });
  }

  static Future<void> deleteMessage(dynamic data) async {
    final guid = data['guid'] as String;

    Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;

      final query = messageBox.query(Message_.guid.equals(guid)).build();
      final result = query.findFirst();
      query.close();
      if (result?.id != null) {
        messageBox.remove(result!.id!);
      }
    });
  }

  static Future<void> softDeleteMessage(dynamic data) async {
    final guid = data['guid'] as String;

    Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;

      final query = messageBox.query(Message_.guid.equals(guid)).build();
      query.limit = 1;
      final toDelete = query.findFirst();
      query.close();

      if (toDelete != null) {
        toDelete.dateDeleted = DateTime.now().toUtc();
        messageBox.put(toDelete);
      }
    });
  }

  static Future<Map<String, dynamic>> fetchAssociatedMessagesAsync(dynamic data) async {
    final messageGuid = data['messageGuid'] as String;
    final threadOriginatorGuid = data['threadOriginatorGuid'] as String?;

    return Database.runInTransaction(TxMode.read, () {
      final messageBox = Database.messages;

      // Fetch associated messages (reactions)
      final query = messageBox.query(Message_.associatedMessageGuid.equals(messageGuid)).build();
      List<Message> associatedMessages = query.find();
      query.close();

      associatedMessages = MessageHelper.normalizedAssociatedMessages(associatedMessages);

      // If there's a thread originator, fetch it
      if (threadOriginatorGuid != null) {
        final originatorQuery = messageBox.query(Message_.guid.equals(threadOriginatorGuid)).build();
        originatorQuery.limit = 1;
        final threadOriginator = originatorQuery.findFirst();
        originatorQuery.close();

        if (threadOriginator != null) {
          associatedMessages.add(threadOriginator);
        }
      }

      associatedMessages.sort((a, b) => a.originalROWID!.compareTo(b.originalROWID!));

      return {
        'associatedMessages': associatedMessages.map((e) => e.toMap()).toList(),
      };
    });
  }

  static Future<int> saveMessageAsync(dynamic data) async {
    final messageData = data['messageData'] as Map<String, dynamic>;
    final chatData = data['chatData'] as Map<String, dynamic>?;
    final updateIsBookmarked = data['updateIsBookmarked'] as bool;

    return Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;
      final handleBox = Database.handles;

      final inputMessage = Message.fromMap(messageData);
      final inputChat = chatData != null ? Chat.fromMap(chatData) : null;

      // Find existing message
      final existingQuery = messageBox.query(Message_.guid.equals(inputMessage.guid ?? '')).build();
      existingQuery.limit = 1;
      final existing = existingQuery.findFirst();
      existingQuery.close();

      if (existing != null) {
        inputMessage.id = existing.id;
        inputMessage.text ??= existing.text;

        // Preserve existing handleRelation if available
        if (existing.handleRelation.hasValue && !inputMessage.handleRelation.hasValue) {
          inputMessage.handleRelation.target = existing.handleRelation.target;
          inputMessage.handle = existing.handleRelation.target;
        }
      }

      // Save the participant & set the handle ID to the new participant
      // Only do handleId lookup if we don't already have a handleRelation
      if (inputMessage.handle == null && !inputMessage.handleRelation.hasValue && inputMessage.handleId != null) {
        final handleQuery = handleBox.query(Handle_.originalROWID.equals(inputMessage.handleId!)).build();
        handleQuery.limit = 1;
        final foundHandle = handleQuery.findFirst();
        handleQuery.close();
        inputMessage.handle = foundHandle;

        // Set up handleRelation for the ToOne relationship
        if (foundHandle != null && foundHandle.id != null) {
          inputMessage.handleRelation.target = foundHandle;
        }
      } else if (inputMessage.handleRelation.hasValue && inputMessage.handle == null) {
        // Use existing relationship to populate handle field
        inputMessage.handle = inputMessage.handleRelation.target;
      }

      // Save associated messages or the original message (depending on whether
      // this message is a reaction or regular message
      if (inputMessage.associatedMessageType != null && inputMessage.associatedMessageGuid != null) {
        final associatedQuery = messageBox.query(Message_.guid.equals(inputMessage.associatedMessageGuid!)).build();
        associatedQuery.limit = 1;
        final associatedMessage = associatedQuery.findFirst();
        associatedQuery.close();

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

      if (!updateIsBookmarked) {
        inputMessage.isBookmarked = existing?.isBookmarked ?? inputMessage.isBookmarked;
      }

      try {
        if (inputChat != null) inputMessage.chat.target = inputChat;
        inputMessage.id = messageBox.put(inputMessage);
      } on UniqueViolationException catch (_) {}

      // Return just the ID for efficient transfer across isolates
      return inputMessage.id!;
    });
  }

  static Future<int?> findOneAsync(dynamic data) async {
    final guid = data['guid'] as String?;
    final associatedMessageGuid = data['associatedMessageGuid'] as String?;

    return Database.runInTransaction(TxMode.read, () {
      final messageBox = Database.messages;

      Message? result;

      if (guid != null) {
        final query = messageBox.query(Message_.guid.equals(guid)).build();
        query.limit = 1;
        result = query.findFirst();
        query.close();
      } else if (associatedMessageGuid != null) {
        final query = messageBox.query(Message_.associatedMessageGuid.equals(associatedMessageGuid)).build();
        query.limit = 1;
        result = query.findFirst();
        query.close();
      }

      // Return just the ID for efficient transfer across isolates
      return result?.id;
    });
  }

  static Future<List<int>> findAsync(dynamic data) async {
    // For now, we'll support finding all messages
    // A more sophisticated implementation would deserialize the condition JSON
    return Database.runInTransaction(TxMode.read, () {
      final messageBox = Database.messages;

      final query = messageBox.query().build();
      final results = query.find();
      query.close();

      // Return just the IDs for efficient transfer across isolates
      return results.map((e) => e.id!).toList();
    });
  }

  /// Bulk add messages with progress reporting
  /// This is the heavy-lifting version that runs in the isolate
  static Future<List<int>> bulkAddMessages(dynamic data) async {
    final chatData = data['chatData'] as Map<String, dynamic>?;
    final messagesData = (data['messagesData'] as List).cast<Map<String, dynamic>>();
    final checkForLatestMessageText = data['checkForLatestMessageText'] as bool? ?? true;

    // Note: Progress reporting will be handled by the isolate wrapper if sendPort is provided
    final progressCallback = data['progressCallback'] as Function(int, int)?;
    return Database.runInTransaction(TxMode.write, () {
      final messageBox = Database.messages;
      final attachmentBox = Database.attachments;
      final handleBox = Database.handles;
      final chatBox = Database.chats;

      List<Message> savedMessages = [];
      Map<String, Chat> chatCache = {};

      // Handle the input chat if provided
      Chat? inputChat;
      if (chatData != null) {
        inputChat = Chat.fromMap(chatData);

        // Check if chat exists in DB, save if not
        if (inputChat.id == null) {
          final existingChatQuery = chatBox.query(Chat_.guid.equals(inputChat.guid)).build();
          existingChatQuery.limit = 1;
          final existingChat = existingChatQuery.findFirst();
          existingChatQuery.close();

          if (existingChat != null) {
            inputChat = existingChat;
          } else {
            inputChat.id = chatBox.put(inputChat);
          }
        }

        chatCache[inputChat.guid] = inputChat;
      }

      // Fetch all handles upfront for mapping
      final allHandles = handleBox.getAll();

      // Process messages in batches
      int index = 0;
      final totalMessages = messagesData.length;

      for (final msgData in messagesData) {
        try {
          // Report progress
          if (progressCallback != null && index % 10 == 0) {
            progressCallback(index, totalMessages);
          }

          // Parse message
          final message = Message.fromMap(msgData);

          // Handle chat association
          Chat? msgChat = inputChat;
          if (msgChat == null && msgData['chats'] != null) {
            final chatsFromMessage = (msgData['chats'] as List).cast<Map<String, dynamic>>();
            if (chatsFromMessage.isNotEmpty) {
              final chatFromMsg = Chat.fromMap(chatsFromMessage.first);

              // Check cache first
              if (chatCache.containsKey(chatFromMsg.guid)) {
                msgChat = chatCache[chatFromMsg.guid];
              } else {
                // Check DB
                final chatQuery = chatBox.query(Chat_.guid.equals(chatFromMsg.guid)).build();
                chatQuery.limit = 1;
                final existingChat = chatQuery.findFirst();
                chatQuery.close();

                if (existingChat != null) {
                  msgChat = existingChat;
                } else {
                  chatFromMsg.id = chatBox.put(chatFromMsg);
                  msgChat = chatFromMsg;
                }

                chatCache[msgChat.guid] = msgChat;
              }
            }
          }

          // Skip if no chat association
          if (msgChat == null) {
            index++;
            continue;
          }

          // Check for existing message
          final existingQuery = messageBox.query(Message_.guid.equals(message.guid!)).build();
          existingQuery.limit = 1;
          final existingMessage = existingQuery.findFirst();
          existingQuery.close();

          Message messageToSave = existingMessage ?? message;

          // Associate chat and handle
          messageToSave.chat.target = msgChat;

          // Preserve existing handleRelation from DB, otherwise do handleId lookup
          if (existingMessage != null && existingMessage.handleRelation.hasValue) {
            // Use existing relationship
            messageToSave.handleRelation.target = existingMessage.handleRelation.target;
            messageToSave.handle = existingMessage.handleRelation.target;
          } else if (!messageToSave.handleRelation.hasValue &&
              messageToSave.handleId != null &&
              messageToSave.handleId! > 0) {
            // No existing relationship, look up by handleId
            final foundHandle = allHandles.firstWhereOrNull((h) => h.originalROWID == messageToSave.handleId);
            messageToSave.handle = foundHandle;

            // Set up handleRelation for the ToOne relationship
            if (foundHandle != null && foundHandle.id != null) {
              messageToSave.handleRelation.target = foundHandle;
            }
          } else if (messageToSave.handleRelation.hasValue && messageToSave.handle == null) {
            // Use existing relationship to populate handle field
            messageToSave.handle = messageToSave.handleRelation.target;
          }

          // Save/update the message first (to ensure it has an ID)
          messageToSave.id = messageBox.put(messageToSave);

          // Handle attachments AFTER message is saved
          if (msgData['attachments'] != null) {
            final attachmentsData = (msgData['attachments'] as List).cast<Map<String, dynamic>>();
            List<Attachment> attachmentsToLink = [];

            for (final attachmentData in attachmentsData) {
              final attachment = Attachment.fromMap(attachmentData);

              // Check if attachment exists
              final attachmentQuery = attachmentBox.query(Attachment_.guid.equals(attachment.guid!)).build();
              attachmentQuery.limit = 1;
              final existingAttachment = attachmentQuery.findFirst();
              attachmentQuery.close();

              if (existingAttachment != null) {
                attachmentsToLink.add(existingAttachment);
              } else {
                attachment.id = attachmentBox.put(attachment);
                attachmentsToLink.add(attachment);
              }
            }

            // IMPORTANT: Set BOTH attachment fields:
            // 1. dbAttachments: ToMany relationship for DB persistence
            //    Must be done AFTER message has an ID from put()
            //    For existing messages, clear first to avoid duplicates
            // 2. No transient Message.attachments cache; dbAttachments is the
            //    only message-level attachment source of truth.
            messageToSave.dbAttachments.clear();
            messageToSave.dbAttachments.addAll(attachmentsToLink);

            // Apply the ToMany relationship changes to DB
            messageToSave.dbAttachments.applyToDb();
          }

          // Update chat's latest message if this is newer (only for new messages)
          if (existingMessage == null && checkForLatestMessageText) {
            final latestMessage = msgChat.latestMessage;
            if (messageToSave.dateCreated!.isAfter(latestMessage.dateCreated!)) {
              msgChat.latestMessage = messageToSave;
              chatBox.put(msgChat);
            }
          }

          savedMessages.add(messageToSave);

          index++;
        } catch (ex) {
          Logger.warn('Failed to process message at index $index: $ex', tag: 'BulkAddMessages');
          index++;
          continue;
        }
      }

      // Final progress report
      if (progressCallback != null) {
        progressCallback(totalMessages, totalMessages);
      }

      // Return just the IDs for efficient transfer across isolates
      return savedMessages.map((m) => m.id!).toList();
    });
  }
}
