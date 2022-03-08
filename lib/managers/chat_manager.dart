import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';

import '../socket_manager.dart';

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
    if (SettingsManager().settings.enablePrivateAPI.value) {
      if (SettingsManager().settings.privateMarkChatAsRead.value && chat.autoSendReadReceipts!) {
        SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat.guid}, (data) {});
      }

      if (!MethodChannelInterface().headless && SettingsManager().settings.privateSendTypingIndicators.value && chat.autoSendTypingIndicators!) {
        SocketManager().sendMessage("update-typing-status", {"chatGuid": chat.guid}, (data) {});
      }
    }

    // We want to clear the notifications for the chat so long as it is not a bubble-chat
    // This is because we do not want to kill the bubble-process (crashing it)
    if (!LifeCycleManager().isBubble) {
      await MethodChannelInterface().invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});
    }
  }
}
