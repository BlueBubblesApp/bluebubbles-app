import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

ChatManager cm = Get.isRegistered<ChatManager>() ? Get.find<ChatManager>() : Get.put(ChatManager());

class ChatManager extends GetxService {
  ChatLifecycleManager? activeChat;
  final Map<String, ChatLifecycleManager> _chatControllers = {};

  void setAllInactive() {
    activeChat?.controller = null;
    activeChat = null;
    attachmentDownloader.cancelAllDownloads();
    _chatControllers.forEach((key, value) {
      value.isActive = false;
      value.isAlive = false;
    });
  }

  void setActiveChat(Chat chat, {clearNotifications = true}) {
    ss.prefs.setString('lastOpenedChat', chat.guid);
    createChatController(chat, active: true);
    if (clearNotifications) {
      clearChatNotifications(chat);
    }
  }

  void setActiveToDead() {
    activeChat?.isAlive = false;
  }

  void setActiveToAlive() {
    activeChat?.isAlive = true;
  }

  bool isChatActive(String guid) => getChatController(guid)?.isActive ?? false;

  void createChatControllers(List<Chat> chats) {
    for (Chat c in chats) {
      createChatController(c);
    }
  }

  ChatLifecycleManager createChatController(Chat chat, {active = false}) {
    // If a chat is passed, get the chat and set it be active and make sure it's stored
    ChatLifecycleManager controller = getChatController(chat.guid) ?? ChatLifecycleManager(chat);
    _chatControllers[chat.guid] = controller;

    // If we are setting a new active chat, we need to clear the active statuses on
    // all of the other chat controllers
    if (active) {
      setAllInactive();
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

  Future<void> clearChatNotifications(Chat chat) async {
    chat.toggleHasUnread(false);

    if (kIsDesktop) {
      await notif.clearDesktopNotificationsForChat(chat.guid);
    }

    // Handle Private API features
    if (ss.settings.enablePrivateAPI.value) {
      if (ss.settings.privateMarkChatAsRead.value && chat.autoSendReadReceipts!) {
        http.markChatRead(chat.guid);
      }
    }

    // We want to clear the notifications for the chat so long as it is not a bubble-chat
    // This is because we do not want to kill the bubble-process (crashing it)
    if (!ls.isBubble) {
      await mcs.invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});
    }
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
      }
    });

    if (response.statusCode == 200 && response.data["data"] != null) {
      Map<String, dynamic> chatData = response.data["data"];

      Logger.info("Got updated chat metadata from server. Saving.", tag: "Fetch-Chat");
      Chat newChat = Chat.fromMap(chatData);
      newChat.handles.clear();
      newChat.handles.addAll(newChat.participants);
      newChat.save();
      return newChat;
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
      }
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
