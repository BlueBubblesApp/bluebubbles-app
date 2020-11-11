import 'dart:async';
import 'dart:async';

import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';

class AttachmentInfoBloc {
  factory AttachmentInfoBloc() {
    return _manager;
  }

  static final AttachmentInfoBloc _manager = AttachmentInfoBloc._internal();

  AttachmentInfoBloc._internal();

  Map<String, CurrentChat> _chatData = {};

  CurrentChat getCurrentChat(String chatGuid) {
    if (!_chatData.containsKey(chatGuid)) {
      return null;
    }
    return _chatData[chatGuid];
  }

  Future<void> init(List<Chat> chats) async {
    for (Chat chat in chats) {
      if (!_chatData.containsKey(chat.guid)) {
        _chatData[chat.guid] = await _initChat(chat);
      }
    }
  }

  void addCurrentChat(CurrentChat currentChat) {
    _chatData[currentChat.chat.guid] = currentChat;
  }

  Future<CurrentChat> initChat(Chat chat) async {
    if (!_chatData.containsKey(chat.guid)) {
      _chatData[chat.guid] = await _initChat(chat);
    } else {
      await _chatData[chat.guid].preloadMessageAttachments();
    }

    return _chatData[chat.guid];
  }

  Future<CurrentChat> _initChat(Chat chat) async {
    CurrentChat currentChat = new CurrentChat(chat);
    await currentChat.preloadMessageAttachments();
    return currentChat;
  }
}
