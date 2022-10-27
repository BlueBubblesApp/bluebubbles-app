import 'dart:async';

import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// TODO determine how and when to update message widgets
// 1) when threaded items are added, the thread count needs to update
// 2) delivered receipts
// 3) edited & unsent messages


MessagesService ms(String chatGuid) => Get.isRegistered<MessagesService>(tag: chatGuid)
    ? Get.find<MessagesService>(tag: chatGuid) : Get.put(MessagesService(chatGuid), tag: chatGuid);

class MessagesService extends GetxController {
  static final Map<String, Size> cachedBubbleSizes = {};
  late final Chat chat;
  late final StreamSubscription countSub;
  final ChatMessages struct = ChatMessages();

  final String tag;
  MessagesService(this.tag);

  int currentCount = 0;

  Message? get mostRecentSent => (struct.messages.where((e) => e.isFromMe!).toList()
      ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  Message? get mostRecent => (struct.messages.toList()
    ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  void init(Chat c, Function(Message) onNewMessage) {
    chat = c;
    // watch for new messages
    final countQuery = (messageBox.query(Message_.dateDeleted.isNull())
      ..link(Message_.chat, Chat_.id.equals(chat.id!))
      ..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
    countSub = countQuery.listen((event) {
      final newCount = event.count();
      if (newCount > currentCount) {
        final message = event.findFirst()!;
        message.handle = Handle.findOne(id: message.handleId);
        message.attachments = List<Attachment>.from(message.dbAttachments);
        // add this as a reaction if needed
        if (message.associatedMessageGuid != null) {
          struct.getMessage(message.associatedMessageGuid!)?.associatedMessages.add(message);
        }
        struct.addMessages([message]);
        onNewMessage.call(message);
      }
      currentCount = newCount;
    });
  }

  @override
  void onClose() {
    countSub.cancel();
    super.onClose();
  }

  void close() {
    Get.delete<MessagesService>(tag: tag);
  }

  void reload() {
    Get.reload<MessagesService>(tag: tag);
  }

  void updateMessage(Message updated) {
    final toUpdate = struct.getMessage(updated.guid!)!;
    struct.addMessages([updated.mergeWith(toUpdate)]);
  }

  Future<bool> loadChunk(int offset) async {
    List<Message> _messages = [];
    offset = offset + struct.reactions.length;
    try {
      _messages = await Chat.getMessagesAsync(chat, offset: offset);
      if (_messages.isEmpty) {
        // get from server and save
        final fromServer = await ChatManager().getMessages(chat.guid, offset: offset);
        await MessageHelper.bulkAddMessages(chat, fromServer,
            notifyMessageManager: false, notifyForNewMessage: false, checkForLatestMessageText: false);
        // re-fetch from the DB because it will find handles / associated messages for us
        _messages = await Chat.getMessagesAsync(chat, offset: offset);
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    struct.addMessages(_messages);
    // get thread originators
    for (Message m in _messages.where((e) => e.threadOriginatorGuid != null)) {
      // see if the originator is already loaded
      final guid = m.threadOriginatorGuid!;
      if (struct.getMessage(guid) != null) continue;
      // if not, fetch local and add to data
      final threadOriginator = Message.findOne(guid: guid);
      if (threadOriginator != null) struct.addThreadOriginator(threadOriginator);
    }
    return _messages.isNotEmpty;
  }

  Future<void> loadSearchChunk(Message around, SearchMethod method) async {
    List<Message> _messages = [];
    if (method == SearchMethod.local) {
      _messages = await Chat.getMessagesAsync(chat, searchAround: around.dateCreated!.millisecondsSinceEpoch);
      _messages.add(around);
      _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
      struct.addMessages(_messages);
    } else {
      final beforeResponse = await ChatManager().getMessages(
        chat.guid,
        limit: 25,
        before: around.dateCreated!.millisecondsSinceEpoch,
      );
      final afterResponse = await ChatManager().getMessages(
        chat.guid,
        limit: 25,
        sort: "ASC",
        after: around.dateCreated!.millisecondsSinceEpoch,
      );
      beforeResponse.addAll(afterResponse);
      _messages = beforeResponse.map((e) => Message.fromMap(e)).toList();
      _messages.sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
      struct.addMessages(_messages);
    }
  }
}