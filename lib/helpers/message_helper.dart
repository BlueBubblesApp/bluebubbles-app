import 'dart:math';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:contacts_service/contacts_service.dart';
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
        await MessageHelper.handleNotification(message, msgChat);
      }

      // Tell all listeners that we have a new message, and save the message
      NewMessageManager().addMessage(msgChat, message);
      await msgChat.addMessage(message, changeUnreadStatus: notifyForNewMessage);

      // Create the attachments
      List<dynamic> attachments = item['attachments'];
      attachments.forEach((attachmentItem) async {
        Attachment file = Attachment.fromMap(attachmentItem);
        await file.save(message);
      });

      // Add message to the "master list"
      _messages.add(message);
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

  static Future<void> handleNotification(Message message, Chat chat) async {
    // See if there is an existing message for the given GUID
    Message existingMessage = await Message.findOne({"guid": message.guid});

    // If we've already processed the GUID, skip it
    if (NotificationManager().hasProcessed(message.guid)) return;

    // Add the message to the "processed" list
    NotificationManager().addProcessed(message.guid);

    // Handle all the cases that would mean we don't show the notification
    if (existingMessage != null || chat.isMuted) return;
    if (message.isFromMe || message.handle == null) return;
    if (LifeCycleManager().isAlive && NotificationManager().chatGuid == chat.guid) return;

    String handleAddress;
    if (message.handle != null) {
      handleAddress = message.handle.address;
    }

    // Create the notification
    String contactTitle = await ContactManager().getContactTitle(handleAddress);
    Contact contact = await ContactManager().getCachedContact(handleAddress);
    String title = await getFullChatTitle(chat);
    String notification = await MessageHelper.getNotificationText(message);
    NotificationManager().createNewNotification(
      title,
      notification,
      chat.guid,
      Random().nextInt(9998) + 1,
      chat.id,
      message.dateCreated.millisecondsSinceEpoch,
      contactTitle,
      chat.participants.length > 1,
      handle: message.handle,
      contact: contact
    );
  }

  static Future<String> getNotificationText(Message message) async {
    // If the item type is not 0, it's a group event
    if (message.itemType != 0) {
      return await getGroupEventText(message);
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
    } else if (![null, ""].contains(message.associatedMessageGuid)) {
      // It's a reaction message, get the "sender"
      String sender = (message.isFromMe) ? "You" : formatPhoneNumber(message.handle.address);
      if (!message.isFromMe && message.handle != null) {
        Contact contact = await ContactManager().getCachedContact(message.handle.address);
        if (contact != null) {
          sender = contact.givenName ?? contact.displayName;
        }
      }

      return "$sender ${message.text}";
    } else {
      // It's all other message types
      return message.text;
    }
  }
}
