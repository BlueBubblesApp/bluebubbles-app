import 'dart:async';

import 'package:async_task/async_task.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/helpers/backend/sync/sync_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';

class BulkSyncChats extends AsyncTask<List<dynamic>, List<Chat>> {
  final List<dynamic> params;

  BulkSyncChats(this.params);

  @override
  AsyncTask<List<dynamic>, List<Chat>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return BulkSyncChats(parameters);
  }

  @override
  List<dynamic> parameters() {
    return params;
  }

  @override
  FutureOr<List<Chat>> run() {
    return store.runInTransaction(TxMode.write, () {
      // 0. Create map for the chats and handles to save
      // 1. Check for existing handles and save new ones
      // 2. Fetch all inserted/existing handles based on input
      // 3. Create map of inserted/existing handles
      // 4. Check for existing chats and save new ones
      // 5. Fetch all inserted/existing chats based on input
      // 6. Create map of inserted chats
      // 7. Loop over chat -> participants map and relate all the participants to the chats
      // 8. Save & return updated chats

      /// Takes the list of chats from [params] and saves it
      /// to the objectbox store.
      List<Chat> inputChats = params[0];
      List<String> inputChatGuids = inputChats.map((element) => element.guid).toList();

      // 0. Create map for the chats and handles to save
      Map<String, Handle> handlesToSave = {};
      Map<String, List<String>> chatHandles = {};
      Map<String, Chat> chatsToSave = {};
      for (final chat in inputChats) {
        chatsToSave[chat.guid] = chat;
        for (final p in chat.participants) {
          if (!handlesToSave.containsKey(p.uniqueAddressAndService)) {
            handlesToSave[p.uniqueAddressAndService] = p;
          }

          if (!chatHandles.containsKey(chat.guid)) {
            chatHandles[chat.guid] = [];
          }

          if (!chatHandles[chat.guid]!.contains(p.uniqueAddressAndService)) {
            chatHandles[chat.guid]?.add(p.uniqueAddressAndService);
          }
        }
      }

      // 1. Check for existing handles and save new ones
      List<Handle> inputHandles = handlesToSave.values.toList();
      List<String> inputHandleAddressesAndServices = inputHandles.map((element) => element.uniqueAddressAndService).toList();
      final handleQuery = handleBox.query(Handle_.uniqueAddressAndService.oneOf(inputHandleAddressesAndServices)).build();
      List<String> existingHandleAddressesAndServices = handleQuery.find().map((e) => e.uniqueAddressAndService).toList();
      inputHandles = inputHandles.where((element) => !existingHandleAddressesAndServices.contains(element.uniqueAddressAndService)).toList();
      handleBox.putMany(inputHandles);

      // 2. Fetch all inserted/existing handles based on input
      final handleQuery2 = handleBox.query(Handle_.uniqueAddressAndService.oneOf(inputHandleAddressesAndServices)).build();
      List<Handle> handles = handleQuery2.find().toList();

      // 3. Create map of inserted/existing handles
      Map<String, Handle> handleMap = {};
      for (final h in handles) {
        handleMap[h.uniqueAddressAndService] = h;
      }

      // 4. Check for existing chats and save new ones
      final chatQuery = chatBox.query(Chat_.guid.oneOf(inputChatGuids)).build();
      List<String> existingChatGuids = chatQuery.find().map((e) => e.guid).toList();
      inputChats = inputChats.where((element) => !existingChatGuids.contains(element.guid)).toList();
      chatBox.putMany(inputChats);

      // 5. Fetch all inserted/existing chats based on input
      final chatQuery2 = chatBox.query(Chat_.guid.oneOf(inputChatGuids)).build();
      List<Chat> chats = chatQuery2.find().toList();

      // 6. Create map of inserted/existing chats
      Map<String, Chat> chatMap = {};
      for (final c in chats) {
        chatMap[c.guid] = c;
      }

      // Loop over chat -> participants map and relate all the participants to the chats
      for (final item in chatHandles.entries) {
        final chat = chatMap[item.key];
        if (chat == null) continue;
        final participants = item.value.map((e) => handleMap[e]).whereNotNull().toList();
        if (participants.isNotEmpty) {
          chat.handles.clear();
          chat.handles.addAll(participants);
          chat.handles.applyToDb();
        }
      }

      // 8. Save & return updated chats
      chatBox.putMany(chats);
      return chats;
    });
  }
}

class BulkSyncMessages extends AsyncTask<List<dynamic>, List<Message>> {
  final List<dynamic> params;

  BulkSyncMessages(this.params);

  @override
  AsyncTask<List<dynamic>, List<Message>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return BulkSyncMessages(parameters);
  }

  @override
  List<dynamic> parameters() {
    return params;
  }

  @override
  FutureOr<List<Message>> run() {
    return store.runInTransaction(TxMode.write, () {
      // Assumptions:
      // - The provided chat exists, has an ID, and participants exist and have an ID
      //
      // 0. Gather handles from chat and cache them
      // 1. For each message, match the handles & replace the old reference
      // 2. Extract & cache the attachments
      // 3. Sync the attachments & insert IDs into cache
      // 4. Sync the messages & insert relationships
      // 5. Invoke a final put call to sync the relational data

      // Input variables
      Chat inputChat = params[0];
      List<Message> inputMessages = params[1];

      // Processing Code
      // 0: Gather handles from chat and cache them
      // They should already exist because this function makes that assumption. #logic
      Map<String, Handle> handlesCache = {};
      for (var participant in inputChat.handles) {
        String addr = participant.uniqueAddressAndService;
        if (handlesCache.containsKey(addr)) continue;
        handlesCache[addr] = participant;
      }

      // 1. For each message, match the handles & replace the old reference
      for (Message message in inputMessages) {
        message.handle ??= handlesCache.values.firstWhereOrNull((e) => e.originalROWID == message.handleId);
      }

      // 2. Extract & cache the attachments
      Map<String, Attachment> attachmentCache = {};
      for (var msg in inputMessages) {
        if (msg.attachments.isEmpty) continue;
        for (Attachment? attachment in msg.attachments) {
          if (attachment == null) continue;
          attachmentCache[attachment.guid!] = attachment;
        }
      }

      // 3. Sync the attachments & insert IDs into cache
      List<Attachment> syncedAttachments = syncAttachments(attachmentCache.values.toList());
      for (var attachment in syncedAttachments) {
        if (!attachmentCache.containsKey(attachment.guid)) continue;
        attachmentCache[attachment.guid!] = attachment;
      }

      // 4. Sync the messages & insert synced attachments
      List<Message> syncedMessages = syncMessages(inputChat, inputMessages);
      for (var message in syncedMessages) {
        // Update related attachments with synced versions
        for (var attachment in message.attachments) {
          if (attachment == null) continue;
          Attachment? cached = attachmentCache[attachment.guid];
          if (cached == null) continue;
          attachment = cached;
        }

        // Update the relational attachments
        message.dbAttachments.addAll(message.attachments.where((element) => element != null).map((e) => e!).toList());
      }

      // 5. Invoke a final put call to sync the relational data
      for (Message m in syncedMessages) {
        try {
          messageBox.put(m);
        } catch (e, stack) {
          Logger.error("Failed to put messages into database during bulk sync!", error: e, trace: stack);
        }
      }
      return syncedMessages;
    });
  }
}

class SyncLastMessages extends AsyncTask<List<dynamic>, List<Chat>> {
  final List<dynamic> params;

  SyncLastMessages(this.params);

  @override
  AsyncTask<List<dynamic>, List<Chat>> instantiate(List<dynamic> parameters, [Map<String, SharedData>? sharedData]) {
    return SyncLastMessages(parameters);
  }

  @override
  List<dynamic> parameters() {
    return params;
  }

  /// Tries to update the latest message for a [chat], based on
  /// the input [lastMessage] object.
  /// 
  /// Returns a boolean determining if we've updated the latest message
  bool tryUpdateLastMessage(Chat chat, Message? lastMessage, bool toggleUnread) {
    // If we don't even have a last message, return false
    if (lastMessage == null || lastMessage.dateCreated == null) return false;

    // If the chat has no last message, but we now have a last message
    bool didUpdate = false;
    bool checkMessageText = false;

    // If the dates are equal, check the text to see if we should update it.
    // AKA, check if the text matches
    int currentMs = chat.latestMessage.dateCreated!.millisecondsSinceEpoch;
    int lastMs = lastMessage.dateCreated!.millisecondsSinceEpoch;
    if (currentMs <= lastMs) {
      didUpdate = true;

      if (currentMs == lastMs) {
        checkMessageText = true;
      }
    }

    // If we plan to update the message, but the dates are the same,
    String? newMsgText;
    if (didUpdate && checkMessageText) {
      newMsgText = MessageHelper.getNotificationText(lastMessage);
      if (MessageHelper.getNotificationText(chat.latestMessage) == newMsgText) {
        didUpdate = false;
      }
    }

    // If we still want to update the info, do so
    if (didUpdate) {
      chat.latestMessage = lastMessage;
      
      // Mark the chat as unread if we updated the last message & it's not from us
      if (toggleUnread && !(lastMessage.isFromMe ?? false)) {
        chat.toggleHasUnread(true);
      }
    }

    return didUpdate;
  }

  @override
  FutureOr<List<Chat>> run() {
    return store.runInTransaction(TxMode.write, () {
      // Input variables
      List<Chat> inputChats = params[0];
      bool toggleUnread = params[1];
      List<String> inputGuids = inputChats.map((e) => e.guid).toList();

      // Get the latest versions of the chats
      final chatQuery = chatBox.query(Chat_.guid.oneOf(inputGuids)).build();
      List<Chat> existingChats = chatQuery.find();

      // Pull the latest message for all of the chats.
      List<int> chatIds = existingChats.map((e) => e.id!).toList();
      List<Chat> updatedChats = [];
      for (int i in chatIds) {
        // Fetch latest message for the chat
        final latestMsgQuery = (messageBox.query(Message_.chat.equals(i))..order(Message_.dateCreated, flags: Order.descending)).build();
        Message? latestMessage = latestMsgQuery.findFirst();
        if (latestMessage?.handle == null && latestMessage?.handleId != null && latestMessage?.handleId != 0) {
          latestMessage!.handle = latestMessage.getHandle();
        }
        Chat current = existingChats.firstWhere((element) => element.id == i);

        // Try and update the last message info
        bool didUpdate = tryUpdateLastMessage(current, latestMessage, toggleUnread);
        if (didUpdate) {
          // Add to a list to be updated in the DB
          updatedChats.add(current);
        }
      }

      // If we have updates to make, apply them
      if (updatedChats.isNotEmpty) {
        chatBox.putMany(updatedChats, mode: PutMode.update);
      }
      
      // This will contain the updated chat values
      return existingChats;
    });
  }
}
