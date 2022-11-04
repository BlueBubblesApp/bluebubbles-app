import 'dart:async';

import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

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
  late final Function(Message) updateFunc;
  late final Function(Message) removeFunc;

  final String tag;
  MessagesService(this.tag);

  int currentCount = 0;

  Message? get mostRecentSent => (struct.messages.where((e) => e.isFromMe!).toList()
      ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  Message? get mostRecent => (struct.messages.toList()
    ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  void init(Chat c, Function(Message) onNewMessage, Function(Message) onUpdatedMessage, Function(Message) onDeletedMessage) {
    chat = c;
    updateFunc = onUpdatedMessage;
    removeFunc = onDeletedMessage;
    // watch for new messages
    final countQuery = (messageBox.query(Message_.dateDeleted.isNull())
      ..link(Message_.chat, Chat_.id.equals(chat.id!))
      ..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
    countSub = countQuery.listen((event) {
      if (!ss.settings.finishedSetup.value) return;
      final newCount = event.count();
      if (newCount > currentCount && currentCount != 0) {
        event.limit = newCount - currentCount;
        final messages = event.find();
        for (Message message in messages) {
          message.handle = Handle.findOne(id: message.handleId);
          message.attachments = List<Attachment>.from(message.dbAttachments);
          // add this as a reaction if needed
          // todo update relevant messages (associated message or thread originator)
          if (message.associatedMessageGuid != null) {
            struct.getMessage(message.associatedMessageGuid!)?.associatedMessages.add(message);
          }
          struct.addMessages([message]);
          onNewMessage.call(message);
        }
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
    updated = updated.mergeWith(toUpdate);
    struct.addMessages([updated]);
    updateFunc.call(updated);
  }

  void removeMessage(Message toRemove) {
    struct.removeMessage(toRemove.guid!);
    struct.removeAttachments(toRemove.attachments.map((e) => e!.guid!));
  }

  Future<bool> loadChunk(int offset) async {
    List<Message> _messages = [];
    offset = offset + struct.reactions.length;
    try {
      _messages = await Chat.getMessagesAsync(chat, offset: offset);
      if (_messages.isEmpty) {
        // get from server and save
        final fromServer = await cm.getMessages(chat.guid, offset: offset);
        await MessageHelper.bulkAddMessages(chat, fromServer, checkForLatestMessageText: false);
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
      final beforeResponse = await cm.getMessages(
        chat.guid,
        limit: 25,
        before: around.dateCreated!.millisecondsSinceEpoch,
      );
      final afterResponse = await cm.getMessages(
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

  static Future<List<dynamic>> getMessages({
    bool withChats = false,
    bool withAttachments = false,
    bool withHandles = false,
    bool withChatParticipants = false,
    List<dynamic> where = const [],
    String sort = "DESC",
    int? before, int? after,
    String? chatGuid,
    int offset = 0, int limit = 100
  }) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>["attributedBody", "messageSummaryInfo", "payloadData"];
    if (withChats) withQuery.add("chat");
    if (withAttachments) withQuery.add("attachment");
    if (withHandles) withQuery.add("handle");
    if (withChatParticipants) withQuery.add("chat.participants");
    withQuery.add("attachment.metadata");

    http.messages(withQuery: withQuery, where: where, sort: sort, before: before, after: after, chatGuid: chatGuid, offset: offset, limit: limit).then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err?.toString();
      }
      if (!completer.isCompleted) completer.completeError(error ?? "");
    });

    return completer.future;
  }
}