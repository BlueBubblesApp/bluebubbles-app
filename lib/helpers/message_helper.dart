import 'dart:math';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';

class MessageHelper {
  static Future<List<Message>> bulkAddMessages(
      Chat chat, List<dynamic> messages,
      {bool notifyForNewMessage = false}) async {
    // Create master list for all the messages and a chat cache
    List<Message> _messages = <Message>[];
    Map<String, Chat> chats = <String, Chat>{};

    // Add the chat in the cache and save it if it hasn't been saved yet
    if (chat != null) {
      chats[chat.guid] = chat;
      if (chat.id == null) {
        await chat.save();
      }
    }

    // Iterate over each message to parse it
    messages.forEach((item) async {
      // Pull the chats out of the message, if there isnt a default
      Chat msgChat = chat;
      if (msgChat == null) {
        List<Chat> msgChats = parseChats(item);
        msgChat = msgChats.length > 0 ? msgChats[0] : null;

        // If there is a cached chat, get it. Otherwise, save the new one
        if (msgChat != null && chats.containsKey(msgChat.guid)) {
          msgChat = chats[msgChat.guid];
        } else if (msgChat != null) {
          await msgChat.save();
          chats[msgChat.guid] = msgChat;
        }
      }

      // If we can't get a chat from the data, skip the message
      if (msgChat == null) return;

      Message message = Message.fromMap(item);
      if (notifyForNewMessage) {
        Message existingMessage = await Message.findOne({"guid": message.guid});
        if (existingMessage == null) {
          String title = await getFullChatTitle(msgChat);

          if (!message.isFromMe &&
              message.handle != null &&
              (NotificationManager().chatGuid != msgChat.guid ||
                  !LifeCycleManager().isAlive) &&
              !msgChat.isMuted &&
              !NotificationManager()
                  .processedNotifications
                  .contains(message.guid)) {
            NotificationManager().createNewNotification(
                title,
                MessageHelper.getNotificationText(message),
                msgChat.guid,
                Random().nextInt(9998) + 1,
                msgChat.id,
                message.dateCreated.millisecondsSinceEpoch,
                getContactTitle(message.handle.id, message.handle.address),
                msgChat.participants.length > 1,
                handle: message.handle,
                contact: getContact(message.handle.address));
            NotificationManager().processedNotifications.add(message.guid);
            await msgChat.markReadUnread(true);
            NewMessageManager().addMessage(msgChat, message);
          }
        }
      }

      // Save the message
      message.save().then((_) {
        _messages.add(message);
        msgChat.addMessage(message).then((value) {
          // Create the attachments
          List<dynamic> attachments = item['attachments'];

          attachments.forEach((attachmentItem) async {
            Attachment file = Attachment.fromMap(attachmentItem);
            await file.save(message);
          });
        });
      });
    });

    // Return all the synced messages
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

  static String getNotificationText(Message message) {
    // If the item type is not 0, it's a group event
    if (message.itemType != 0) {
      return getGroupEventText(message);
    }

    // Parse/search for links
    List<RegExpMatch> matches = parseLinks(message.text);

    // If there are attachments, return the number of attachments
    int aCount = (message.attachments ?? []).length;
    if (message.hasAttachments && matches.length == 0) {
      // Build the attachment output by counting the attachments
      String output = "Attachment${aCount > 1 ? "s" : ""}";
      Map<String, int> counts = {};
      for (Attachment attachment in message.attachments ?? []) {
        String mime = attachment.mimeType;
        String key;
        if (mime == null) {
          key = "link";
        } else if (mime.contains("location")) {
          key = "location";
        } else if (mime.contains("contact")) {
          key = "contact";
        } else {
          key = mime.split("/").first;
        }

        if (key != null) {
          int current = counts.containsKey(key) ? counts[key] : 0;
          counts[key] = current + 1;
        }
      }

      List<String> attachmentStr = [];
      counts.forEach((key, value) {
        attachmentStr.add("$value $key${value > 1 ? "s" : ""}");
      });

      return "$output: ${attachmentStr.join(attachmentStr.length == 2 ? " & " : ", ")}";
    } else {
      return message.text;
    }
  }
}
