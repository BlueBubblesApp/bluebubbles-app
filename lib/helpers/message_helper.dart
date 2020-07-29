import 'dart:math';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';

class MessageHelper {
  static Future<List<Message>> bulkAddMessages(
      Chat chat, List<dynamic> messages,
      {bool notifyForNewMessage = false}) async {
    List<Message> _messages = <Message>[];
    messages.forEach((item) async {
      Message message = Message.fromMap(item);
      if (notifyForNewMessage) {
        Message existingMessage = await Message.findOne({"guid": message.guid});
        if (existingMessage == null) {
          // Get the chat title and message
          await chat.save();
          String title = await getFullChatTitle(chat);

          if (!message.isFromMe && message.handle != null &&
              (NotificationManager().chatGuid != chat.guid ||
                  !LifeCycleManager().isAlive) &&
              !chat.isMuted &&
              !NotificationManager()
                  .processedNotifications
                  .contains(message.guid)) {
            String text = message.text;
            if ((item['attachments'] as List<dynamic>).length > 0) {
              text = (item['attachments'] as List<dynamic>).length.toString() +
                  " attachment" +
                  ((item['attachments'] as List<dynamic>).length > 1
                      ? "s"
                      : "");
            }

            NotificationManager().createNewNotification(
              title,
              text,
              chat.guid,
              Random().nextInt(9998) + 1,
              chat.id,
              message.dateCreated.millisecondsSinceEpoch,
              getContactTitle(message.handle.id, message.handle.address),
              chat.participants.length > 1,
              handle: message.handle,
              contact: getContact(message.handle.address)
            );
            NotificationManager().processedNotifications.add(message.guid);
            if (!SocketManager().chatsWithNotifications.contains(chat.guid) &&
                NotificationManager().chatGuid != chat.guid) {
              SocketManager().chatsWithNotifications.add(chat.guid);
            }
          }
        }
      }
      message.save().then((_) {
        _messages.add(message);
        chat.addMessage(message).then((value) {
          // Create the attachments
          List<dynamic> attachments = item['attachments'];

          attachments.forEach((attachmentItem) async {
            Attachment file = Attachment.fromMap(attachmentItem);
            await file.save(message);
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
