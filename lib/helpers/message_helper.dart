import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/material.dart';

class MessageHelper {
  static Future<List<Message>> bulkAddMessages(
      Chat chat, List<dynamic> messages) async {
    List<Message> _messages = <Message>[];
    messages.forEach((item) {
      Message message = Message.fromMap(item);
      message.save().then((_) {
        _messages.add(message);
        chat.addMessage(message).then((value) {
          // Create the attachments
          List<dynamic> attachments = item['attachments'];

          attachments.forEach((attachmentItem) async {
            Attachment file = Attachment.fromMap(attachmentItem);
            await file.save(message);
            debugPrint("attachment id " + file.id.toString());
            debugPrint("message id " + message.id.toString());
          });
        });
      });
    });
    return _messages;
  }

  static List<Chat> parseChats(Map<String, dynamic> data) {
    List<Chat> chats = [];

    if (data.containsKey("chats") && data["chats"] != null ||
        data["chats"].length > 0) {
      for (int i = 0; i < data["chats"].length; i++) {
        Chat chat = Chat.fromMap(data["chats"][i]);
        chats.add(chat);
      }
    }

    return chats;
  }
}
