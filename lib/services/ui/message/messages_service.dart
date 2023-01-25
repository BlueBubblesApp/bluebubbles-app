import 'dart:async';

import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

MessagesService ms(String chatGuid) => Get.isRegistered<MessagesService>(tag: chatGuid)
    ? Get.find<MessagesService>(tag: chatGuid) : Get.put(MessagesService(chatGuid), tag: chatGuid);

String? lastReloadedChat() => Get.isRegistered<String>(tag: 'lastReloadedChat') ? Get.find<String>(tag: 'lastReloadedChat') : null;

class MessagesService extends GetxController {
  static final Map<String, Size> cachedBubbleSizes = {};
  late Chat chat;
  late StreamSubscription countSub;
  final ChatMessages struct = ChatMessages();
  late Function(Message) newFunc;
  late Function(Message, {String? oldGuid}) updateFunc;
  late Function(Message) removeFunc;

  final String tag;
  MessagesService(this.tag);

  int currentCount = 0;
  bool isFetching = false;
  bool _init = false;
  String? method;

  Message? get mostRecentSent => (struct.messages.where((e) => e.isFromMe!).toList()
      ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  Message? get mostRecent => (struct.messages.toList()
    ..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!))).firstOrNull;

  void init(Chat c, Function(Message) onNewMessage, Function(Message, {String? oldGuid}) onUpdatedMessage, Function(Message) onDeletedMessage) {
    chat = c;
    Get.put<String>(tag, tag: 'lastReloadedChat');

    updateFunc = onUpdatedMessage;
    removeFunc = onDeletedMessage;
    newFunc = onNewMessage;

    // watch for new messages
    if (chat.id != null) {
      _init = true;
      final countQuery = (messageBox.query(Message_.dateDeleted.isNull())
        ..link(Message_.chat, Chat_.id.equals(chat.id!))
        ..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
      countSub = countQuery.listen((event) {
        if (!ss.settings.finishedSetup.value) return;
        final newCount = event.count();
        if (!isFetching && newCount > currentCount && currentCount != 0) {
          event.limit = newCount - currentCount;
          final messages = event.find();
          event.limit = 0;
          for (Message message in messages) {
            message.handle = message.getHandle();
            message.attachments = List<Attachment>.from(message.dbAttachments);
            // add this as a reaction if needed, update thread originators and associated messages
            if (message.associatedMessageGuid != null) {
              struct.getMessage(message.associatedMessageGuid!)?.associatedMessages.add(message);
              getActiveMwc(message.associatedMessageGuid!)?.updateAssociatedMessage(message);
            }
            if (message.threadOriginatorGuid != null) {
              getActiveMwc(message.threadOriginatorGuid!)?.updateThreadOriginator(message);
            }
            struct.addMessages([message]);
            if (message.associatedMessageGuid == null) {
              newFunc.call(message);
            }
          }
        }
        currentCount = newCount;
      });
    }
  }

  @override
  void onClose() {
    if (_init) countSub.cancel();
    super.onClose();
  }

  void close() {
    String? lastChat = lastReloadedChat();
    if (lastChat != tag) {
      Get.delete<MessagesService>(tag: tag);
    }
  }

  void reload() {
    Get.put<String>(tag, tag: 'lastReloadedChat');
    Get.reload<MessagesService>(tag: tag);
  }

  void updateMessage(Message updated, {String? oldGuid}) {
    final toUpdate = struct.getMessage(oldGuid ?? updated.guid!);
    if (toUpdate == null) return;
    updated = updated.mergeWith(toUpdate);
    struct.removeMessage(oldGuid ?? updated.guid!);
    struct.removeAttachments(toUpdate.attachments.map((e) => e!.guid!));
    struct.addMessages([updated]);
    updateFunc.call(updated, oldGuid: oldGuid);
  }

  void removeMessage(Message toRemove) {
    struct.removeMessage(toRemove.guid!);
    struct.removeAttachments(toRemove.attachments.map((e) => e!.guid!));
    removeFunc.call(toRemove);
  }

  Future<bool> loadChunk(int offset, ConversationViewController controller) async {
    isFetching = true;
    List<Message> _messages = [];
    offset = offset + struct.reactions.length;
    try {
      _messages = await Chat.getMessagesAsync(chat, offset: offset);
      if (_messages.isEmpty) {
        // get from server and save
        final fromServer = await cm.getMessages(chat.guid, offset: offset);
        final temp = await MessageHelper.bulkAddMessages(chat, fromServer, checkForLatestMessageText: false);
        if (!kIsWeb) {
          // re-fetch from the DB because it will find handles / associated messages for us
          _messages = await Chat.getMessagesAsync(chat, offset: offset);
        } else {
          _messages = temp;
        }
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
      if (threadOriginator != null) {
        // create the controller so it can be rendered in a reply bubble
        final c = mwc(threadOriginator);
        c.cvController = controller;
        struct.addThreadOriginator(threadOriginator);
      }
    }
    isFetching = false;
    return _messages.isNotEmpty;
  }

  Future<void> loadSearchChunk(Message around, SearchMethod method) async {
    isFetching = true;
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
      for (Message message in _messages) {
        if (message.handle != null) {
          message.handle!.contactRelation.target = cs.matchHandleToContact(message.handle!);
        }
      }
      struct.addMessages(_messages);
    }
    isFetching = false;
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