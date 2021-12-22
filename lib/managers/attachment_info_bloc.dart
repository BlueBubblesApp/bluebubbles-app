import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/models.dart';

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

  void init(List<Chat> chats) {
    for (Chat chat in chats) {
      if (chat.guid != null && !chatData.containsKey(chat.guid)) {
        chatData[chat.guid!] = _initChat(chat);
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
    CurrentChat currentChat = CurrentChat(chat);
    currentChat.preloadMessageAttachments();
    return currentChat;
  }
}
