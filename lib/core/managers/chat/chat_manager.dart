import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';

class ChatManager {
  factory ChatManager() {
    return _manager;
  }

  static final ChatManager _manager = ChatManager._internal();

  ChatManager._internal();

  ChatController? activeChat;
  final Map<String, ChatController> _chatControllers = {};
  late Uint8List noVideoPreviewIcon;
  late Uint8List unplayableVideoIcon;

  bool get hasActiveChat {
    return activeChat != null;
  }

  Future<void> loadAssets() async {
    ByteData file = await loadAsset("assets/images/no-video-preview.png");
    noVideoPreviewIcon = file.buffer.asUint8List();
    file = await loadAsset("assets/images/unplayable-video.png");
    unplayableVideoIcon = file.buffer.asUint8List();
  }

  void setAllInactive() {
    activeChat = null;
    _chatControllers.forEach((key, value) {
      value.isActive = false;
      value.isAlive = false;
    });
  }

  void setActiveChat(Chat? chat, {clearNotifications = true, loadAttachments = true}) {
    // If no chat is passed, clear all active chats (should just be one)
    if (chat == null) {
      return setAllInactive();
    }

    createChatController(chat, active: true, loadAttachments: loadAttachments);
    if (clearNotifications) {
      clearChatNotifications(chat);
    }
  }

  bool isChatActive(Chat chat) {
    ChatController? controller = getChatController(chat);
    return controller?.isActive ?? false;
  }

  bool isChatActiveByGuid(String guid) {
    ChatController? controller = getChatControllerByGuid(guid);
    return controller?.isActive ?? false;
  }

  void createChatControllers(List<Chat> chats, {loadAttachments = true}) {
    for (Chat c in chats) {
      createChatController(c, loadAttachments: loadAttachments);
    }
  }

  void removeChatController(Chat chat, {dispose = true}) {
    _chatControllers.removeWhere((key, value) {
      if (key == chat.guid && dispose) {
        value.isActive = false;
        value.isAlive = false;
        value.dispose();
      }

      // If it's active, we should unset the active chat
      if (value.isActive) {
        activeChat = null;
      }

      return key == chat.guid;
    });
  }

  void disposeChatController(Chat chat) {
    ChatController? controller = getChatController(chat);
    controller?.dispose();
  }

  void disposeAllControllers() {
    _chatControllers.forEach((key, value) {
      value.isActive = false;
      value.isAlive = false;
      value.dispose();
    });

    activeChat = null;
  }

  ChatController createChatController(Chat chat, {active = false, loadAttachments = false}) {
    // If a chat is passed, get the chat and set it be active and make sure it's stored
    ChatController? controller = getChatController(chat);
    controller ??= ChatController(chat);
    _chatControllers[chat.guid] = controller;

    // If we are setting a new active chat, we need to clear the active statuses on
    // all of the other chat controllers
    if (active) {
      setAllInactive();
    }

    controller.isActive = active;
    controller.isAlive = active;
    if (active) {
      activeChat = controller;
    }

    // Preload the message attachments
    if (loadAttachments) {
      controller.preloadMessageAttachments();
    }

    return controller;
  }

  ChatController? getChatControllerByGuid(String guid) {
    if (!_chatControllers.containsKey(guid)) return null;
    return _chatControllers[guid];
  }

  ChatController? getActiveDeadController() {
    return activeChat != null && !activeChat!.isAlive ? activeChat : null;
  }

  void setActiveToDead() {
    activeChat?.isAlive = false;
  }

  void setActiveToAlive() {
    activeChat?.isAlive = true;
  }

  ChatController? getChatController(Chat chat) {
    if (!_chatControllers.containsKey(chat.guid)) return null;
    return _chatControllers[chat.guid];
  }

  Future<void> clearChatNotifications(Chat chat) async {
    chat.toggleHasUnread(false);

    // Handle Private API features
    if (ss.settings.enablePrivateAPI.value) {
      if (ss.settings.privateMarkChatAsRead.value && chat.autoSendReadReceipts!) {
        await http.markChatRead(chat.guid);
      }

      if (ss.settings.privateSendTypingIndicators.value && chat.autoSendTypingIndicators!) {
        socket.sendMessage("update-typing-status", {"chatGuid": chat.guid});
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
    final withQuery = <String>["message.attributedbody"];
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
