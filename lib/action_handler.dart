import 'dart:convert';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

/// This helper class allows us to section off all socket "actions"
/// These actions allow us to interact with the server, whether it
/// be telling the server to do something, or asking the server for
/// information
class ActionHandler {
  /// Tells the server to create a [text] in the [chat], along with
  /// any [attachments] that go with the message
  ///
  /// ```dart
  /// sendMessage(chatObject, 'Hello world!')
  /// ```
  static Future<void> sendMessage(Chat chat, String text,
      {List<Attachment> attachments = const []}) async {
    if (text == null || text.trim().length == 0) return;

    Map<String, dynamic> params = new Map();
    params["guid"] = chat.guid;
    params["message"] = text;
    String tempGuid = "temp-${randomString(8)}";
    params["tempGuid"] = tempGuid;

    // Create the message
    Message sentMessage = Message(
      guid: tempGuid,
      text: text,
      dateCreated: DateTime.now(),
      hasAttachments: attachments.length > 0 ? true : false,
    );
    NewMessageManager()
        .updateWithMessage(chat, sentMessage, sentFromThisClient: true);

    // If we aren't conneted to the socket, set the message error code
    if (SettingsManager().settings.connected == false)
      sentMessage.error = MessageError.NO_CONNECTION.code;

    await sentMessage.save();
    await chat.save();
    await chat.addMessage(sentMessage);

    // If we aren't connected to the socket, return
    if (SettingsManager().settings.connected == false) return;

    if (SocketManager().socket == null) {
      SocketManager().startSocketIO(connectCB: () {
        ActionHandler.sendMessage(chat, text, attachments: attachments);
        SocketManager().closeSocket();
      });
    } else {
      SocketManager().socket.sendMessage("send-message", jsonEncode(params),
          (data) async {
        Map response = jsonDecode(data);
        debugPrint("message sent: " + response.toString());

        // If there is an error, replace the temp value with an error
        if (response['status'] != 200) {
          sentMessage.guid = sentMessage.guid
              .replaceAll("temp", "error-${response['error']['message']}");
          sentMessage.error = response['status'] == 400
              ? MessageError.BAD_REQUEST.code
              : MessageError.SERVER_ERROR.code;

          await Message.replaceMessage(tempGuid, sentMessage);
          NewMessageManager().updateWithMessage(chat, sentMessage);
        }
      });
    }
  }

  /// Try to resents a [message] that has errored during the
  /// previous attempts to send the message
  ///
  /// ```dart
  /// retryMessage(messageObject)
  /// ```
  static Future<void> retryMessage(Message message) async {
    // Don't allow us to retry an un-errored message
    if (message.error == 0) return;

    // Get message's chat
    Chat chat = await Message.getChat(message);
    if (chat == null) throw ("Could not find chat!");

    // Build request parameters
    Map<String, dynamic> params = new Map();
    params["guid"] = chat.guid;
    params["message"] = message.text.trim();
    String tempGuid = "temp-${randomString(8)}";
    String oldGuid = message.guid;
    params["tempGuid"] = tempGuid;

    // Reset error, guid, and send date
    message.error = 0;
    message.guid = tempGuid;
    message.dateCreated = DateTime.now();

    // Add attachments
    // TODO: Get Attachments from DB

    // If we aren't conneted to the socket, set the message error code
    if (SettingsManager().settings.connected == false) message.error = 1000;

    await Message.replaceMessage(oldGuid, message);
    NewMessageManager().updateWithMessage(chat, message);

    // If we aren't connected to the socket, return
    if (SettingsManager().settings.connected == false) return;

    SocketManager().socket.sendMessage("send-message", jsonEncode(params),
        (data) async {
      Map response = jsonDecode(data);
      debugPrint("message sent: " + response.toString());

      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        message.guid = message.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        message.error = response['status'] == 400 ? 1001 : 1002;
        await Message.replaceMessage(tempGuid, message);
        NewMessageManager().updateWithMessage(chat, message);
      }
    });
  }

  /// Resyncs a [chat] by removing all currently saved messages
  /// for the given [chat], then redownloads its' messages from the server
  ///
  /// ```dart
  /// resyncChat(chatObj)
  /// ```
  static Future<void> resyncChat(Chat chat) async {
    final Database db = await DBProvider.db.database;

    // Fetch messages associated with the chat
    var items = await db.rawQuery(
        "SELECT"
        " chatId,"
        " messageId"
        " FROM chat_message_join"
        " WHERE chatId = ?",
        [chat.id]);

    // If there are no messages, return
    if (items.length == 0) return;

    Batch batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      // 1 -> Delete all messages associated with a chat
      batch.delete("message",
          where: "ROWID = ?", whereArgs: [items[i]["messageId"]]);
      // 2 -> Delete all chat_message_join entries associated with a chat
      batch.delete("chat_message_join",
          where: "ROWID = ?", whereArgs: [items[i]["ROWID"]]);
    }

    // Commit the deletes, then refresh the chats
    await batch.commit(noResult: true);
    NewMessageManager().updateWithMessage(chat, null);
  }

  /// Handles the ingestion of a 'updated-message' event. It takes the
  /// input [data] and uses that data to update an already existing
  /// message within the database
  ///
  /// ```dart
  /// handleUpdatedMessage(JsonMap)
  /// ```
  static Future<void> handleUpdatedMessage(Map<String, dynamic> data) async {
    Message updatedMessage = new Message.fromMap(data);
    updatedMessage =
        await Message.replaceMessage(updatedMessage.guid, updatedMessage);

    Chat chat;
    debugPrint("handle updated message ");
    if (data["chats"] == null &&
        updatedMessage != null &&
        updatedMessage.id != null) {
      chat = await Message.getChat(updatedMessage);
    } else if (data["chats"] != null) {
      chat = Chat.fromMap(data["chats"][0]);
    }
    if (updatedMessage != null)
      NewMessageManager()
          .updateSpecificMessage(chat, updatedMessage.guid, updatedMessage);
  }

  /// Handles the ingestion of an incoming chat. Chats come in
  /// associated with a message. These chats can either be passed
  /// as a [chat] object or JSON [chatData]. Lastly, the user can
  /// tell the function if they want it to check for the existance
  /// of the chat using the [checkifExists] parameter.
  ///
  /// ```dart
  /// handleChat(chat: chatObject, checkIfExists: true)
  /// ```
  static Future<void> handleChat(
      {Map<String, dynamic> chatData,
      Chat chat,
      bool checkIfExists = false}) async {
    Chat currentChat;
    Chat newChat = chat;
    if (chatData != null && newChat == null) {
      newChat = Chat.fromMap(chatData);
    }

    // If we are told to check if the chat exists, do it
    if (checkIfExists) {
      currentChat = await Chat.findOne({"guid": newChat.guid});
    }

    // Save the new chat only if current chat isn't found
    if (currentChat == null) await newChat.save();

    // If we already have a chat, don't fetch the participants
    if (currentChat != null) return;

    Map<String, dynamic> params = Map();
    params["chatGuid"] = newChat.guid;
    params["withParticipants"] = true;
    SocketManager().socket.sendMessage("get-chat", jsonEncode(params),
        (data) async {
      Map<String, dynamic> chatData = jsonDecode(data)["data"];
      if (chatData != null) {
        newChat = Chat.fromMap(chatData);

        // Resave the chat after we've got the participants
        await newChat.save();

        // Update the main view
        // await ChatBloc().getChats();
        await ChatBloc().moveChatToTop(newChat);
        // NewMessageManager().updateWithMessage(null, null);
      }
    });
  }

  /// Handles the ingestion of a 'new-message' event from the server.
  /// The server will send new-message events when it detects either
  /// a new message or a "matched" message. This function will handle
  /// the ingestion of said message JSON [data], according to what is
  /// passed to it.
  ///
  /// ```dart
  /// handleMessage(JsonMap)
  /// ```
  static Future<void> handleMessage(Map<String, dynamic> data) async {
    Message message = Message.fromMap(data);
    List<Chat> chats = MessageHelper.parseChats(data);

    // Handle message differently depending on if there is a temp GUID match
    if (data.containsKey("tempGuid")) {
      debugPrint("Client received message match for ${data["guid"]}");

      // Check if the GUID exists
      Message existing = await Message.findOne({'guid': data['guid']});

      // If the GUID exists already, delete the temporary entry
      // Otherwise, replace the temp message
      if (existing != null) {
        debugPrint(
            "Message already exists for match. Removing temporary entry.");
        await Message.delete({'guid': data['tempGuid']});
      } else {
        await Message.replaceMessage(data["tempGuid"], message);
        List<dynamic> attachments =
            data.containsKey("attachments") ? data['attachments'] : [];
        attachments.forEach((attachmentItem) async {
          Attachment file = Attachment.fromMap(attachmentItem);
          Attachment.replaceAttachment(data["tempGuid"], file);
        });
      }
      NewMessageManager()
          .updateSpecificMessage(chats.first, data['tempGuid'], message);
    } else {
      // Add the message to the chats
      for (int i = 0; i < chats.length; i++) {
        debugPrint("Client received new message " + chats[i].guid);
        await ActionHandler.handleChat(chat: chats[i], checkIfExists: true);
        await message.save();
        await chats[i].addMessage(message);

        // Add notification metadata
        if (!SocketManager().chatsWithNotifications.contains(chats[i].guid) &&
            NotificationManager().chat != chats[i].guid) {
          SocketManager().chatsWithNotifications.add(chats[i].guid);
        }

        // Update chats
        NewMessageManager().updateWithMessage(chats[i], message);
      }

      // Add any related attachments
      List<dynamic> attachments =
          data.containsKey("attachments") ? data['attachments'] : [];
      attachments.forEach((attachmentItem) async {
        Attachment file = Attachment.fromMap(attachmentItem);
        await file.save(message);

        if (SettingsManager().settings.autoDownload && file.mimeType != null) {
          new AttachmentDownloader(file);
        }
      });
    }
  }

  static void createNotification(Map<String, dynamic> notification) {
    if (!NotificationManager()
        .processedNotifications
        .contains(notification["guid"])) {
      NotificationManager().createNewNotification(
          notification["contentTitle"],
          notification["contentText"],
          notification["group"],
          notification["id"],
          notification["summaryId"]);
      NotificationManager().processedNotifications.add(notification["guid"]);
    }
  }
}
