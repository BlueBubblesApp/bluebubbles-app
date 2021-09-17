import 'dart:async';

import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/chat.dart';

class AttachmentInfoBloc {
  factory AttachmentInfoBloc() {
    return _manager;
  }

  static final AttachmentInfoBloc _manager = AttachmentInfoBloc._internal();

  AttachmentInfoBloc._internal();

  Map<String, CurrentChat> chatData = {};

  CurrentChat? getCurrentChat(String chatGuid) {
    if (!chatData.containsKey(chatGuid)) {
      return null;
    }
    return chatData[chatGuid];
  }

  Future<void> init(List<Chat> chats) async {
    for (Chat chat in chats) {
      if (chat.guid != null && !chatData.containsKey(chat.guid)) {
        chatData[chat.guid!] = await _initChat(chat);
      }
    }
  }

  void addCurrentChat(CurrentChat currentChat) {
    if (currentChat.chat.guid == null) return;
    chatData[currentChat.chat.guid!] = currentChat;
  }

  CurrentChat? initChat(Chat chat) {
    if (chat.guid == null) return null;
    if (!chatData.containsKey(chat.guid)) {
      chatData[chat.guid!] = _initChat(chat);
    } else {
      chatData[chat.guid]!.preloadMessageAttachments();
    }

    return chatData[chat.guid];
  }

  CurrentChat _initChat(Chat chat) {
    CurrentChat currentChat = new CurrentChat(chat);
    currentChat.preloadMessageAttachments();
    return currentChat;
  }
}
