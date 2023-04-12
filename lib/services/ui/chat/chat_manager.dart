import 'dart:async';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';

ChatManager cm = Get.isRegistered<ChatManager>() ? Get.find<ChatManager>() : Get.put(ChatManager());

class ChatManager extends GetxService {
  ChatLifecycleManager? activeChat;
  final Map<String, ChatLifecycleManager> _chatControllers = {};

  Future<void> setAllInactive() async {
    Logger.debug('Setting all chats to inactive');

    activeChat?.controller = null;
    activeChat = null;

    await ss.prefs.remove('lastOpenedChat');
    _chatControllers.forEach((key, value) {
      value.isActive = false;
      value.isAlive = false;
    });
  }

  Future<void> setActiveChat(Chat chat, {clearNotifications = true}) async {
    eventDispatcher.emit("update-highlight", chat.guid);
    Logger.debug('Setting active chat to ${chat.guid} (${chat.displayName})');

    await createChatController(chat, active: true);
    await ss.prefs.setString('lastOpenedChat', chat.guid);
    if (clearNotifications) {
      chat.toggleHasUnread(false, force: true);
    }
  }

  void setActiveToDead() {
    Logger.debug('Setting active chat to dead: ${activeChat?.chat.guid}');
    activeChat?.isAlive = false;
  }

  void setActiveToAlive() {
    Logger.info('Setting active chat to alive: ${activeChat?.chat.guid}');
    activeChat?.isAlive = true;
  }

  bool isChatActive(String guid) => (getChatController(guid)?.isActive ?? false) && (getChatController(guid)?.isAlive ?? false);

  Future<ChatLifecycleManager> createChatController(Chat chat, {active = false}) async {
    Logger.debug('Creating chat controller for ${chat.guid} (${chat.displayName})');
  
    // If a chat is passed, get the chat and set it be active and make sure it's stored
    ChatLifecycleManager controller = getChatController(chat.guid) ?? ChatLifecycleManager(chat);
    _chatControllers[chat.guid] = controller;

    // If we are setting a new active chat, we need to clear the active statuses on
    // all of the other chat controllers
    if (active) {
      await setAllInactive();
      activeChat = controller;
    }

    controller.isActive = active;
    controller.isAlive = active;

    return controller;
  }

  ChatLifecycleManager? getChatController(String guid) {
    if (!_chatControllers.containsKey(guid)) return null;
    return _chatControllers[guid];
  }

  /// Fetch chat information from the server
  Future<Chat?> fetchChat(String chatGuid, {withParticipants = true, withLastMessage = false}) async {
    Logger.info("Fetching full chat metadata from server.", tag: "Fetch-Chat");

    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await http.singleChat(chatGuid, withQuery: withQuery.join(",")).catchError((err) {
      if (err is! Response) {
        Logger.error("Failed to fetch chat metadata! ${err.toString()}", tag: "Fetch-Chat");
        return err;
      }
      return Response(requestOptions: RequestOptions(path: ''));
    });

    if (response.statusCode == 200 && response.data["data"] != null) {
      Map<String, dynamic> chatData = response.data["data"];

      Logger.info("Got updated chat metadata from server. Saving.", tag: "Fetch-Chat");
      Chat updatedChat = Chat.fromMap(chatData);
      Chat? chat = Chat.findOne(guid: chatGuid);
      if (chat == null) {
        updatedChat.save();
        chat = Chat.findOne(guid: chatGuid)!;
      } else if (chat.handles.length > updatedChat.participants.length) {
        final newAddresses = updatedChat.participants.map((e) => e.address);
        final handlesToUse = chat.participants.where((e) => newAddresses.contains(e.address));
        chat.handles.clear();
        chat.handles.addAll(handlesToUse);
        chat.handles.applyToDb();
      } else if (chat.handles.length < updatedChat.participants.length) {
        final existingAddresses = chat.participants.map((e) => e.address);
        final newHandle = updatedChat.participants.firstWhere((e) => !existingAddresses.contains(e.address));
        final handle = Handle.findOne(addressAndService: Tuple2(newHandle.address, chat.isIMessage ? "iMessage" : "SMS")) ?? newHandle.save();
        chat.handles.add(handle);
        chat.handles.applyToDb();
      }
      if (!chat.lockChatName) {
        chat.displayName = updatedChat.displayName;
      }
      chat = chat.save(updateDisplayName: !chat.lockChatName);
      return chat;
    }

    return null;
  }

  Future<List<Chat>> getChats({bool withParticipants = false, bool withLastMessage = false, int offset = 0, int limit = 100,}) async {
    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await http.chats(withQuery: withQuery, offset: offset, limit: limit).catchError((err) {
      if (err is! Response) {
        Logger.error("Failed to fetch chat metadata! ${err.toString()}", tag: "Fetch-Chat");
        return err;
      }
      return Response(requestOptions: RequestOptions(path: ''));
    });

    // parse chats from the response
    final chats = <Chat>[];
    for (var item in response.data["data"]) {
      try {
        var chat = Chat.fromMap(item);
        chats.add(chat);
      } catch (ex) {
        chats.add(Chat(guid: "ERROR", displayName: item.toString()));
      }
    }

    return chats;
  }

  Future<List<dynamic>> getMessages(String guid, {bool withAttachment = true, bool withHandle = true, int offset = 0, int limit = 25, String sort = "DESC", int? after, int? before}) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>["message.attributedBody", "message.messageSummaryInfo", "message.payloadData"];
    if (withAttachment) withQuery.add("attachment");
    if (withHandle) withQuery.add("handle");

    http.chatMessages(guid, withQuery: withQuery.join(","), offset: offset, limit: limit, sort: sort, after: after, before: before).then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err.toString();
      }
      if (!completer.isCompleted) completer.completeError(error);
    });

    return completer.future;
  }
}
