import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_sender.dart';
import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
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
      {List<Attachment> attachments = const [],
      bool closeOnFinish = false}) async {
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

    if (!closeOnFinish) {
      NewMessageManager()
          .updateWithMessage(chat, sentMessage, sentFromThisClient: true);
      await sentMessage.save();
      await chat.save();
      await chat.addMessage(sentMessage);
    }

    // // If we aren't connected to the socket, return
    // if (SettingsManager().settings.connected == false) return;
    SocketManager().sendMessage("send-message", params, (response) async {
      // if (closeOnFinish &&
      //     SocketManager().attachmentDownloaders.length == 0 &&
      //     SocketManager().attachmentSenders.length == 0) {
      //   SocketManager().closeSocket();
      // }

      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        sentMessage.guid = sentMessage.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        sentMessage.error = response['status'] == 400
            ? MessageError.BAD_REQUEST.code
            : MessageError.SERVER_ERROR.code;

        await Message.replaceMessage(tempGuid, sentMessage);
        NewMessageManager().updateSpecificMessage(chat, tempGuid, sentMessage);
      }
    });
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

    if (message.hasAttachments) {
      List<Attachment> attachments = await Message.getAttachments(message);

      for (int i = 0; i < attachments.length; i++) {
        String appDocPath = SettingsManager().appDocDir.path;
        String pathName =
            "$appDocPath/attachments/${attachments[i].guid}/${attachments[i].transferName}";
        File file = File(pathName);
        new AttachmentSender(
          file,
          chat,
          i == attachments.length - 1 ? message.text : "",
        );
      }
      return;
    }

    // Build request parameters
    Map<String, dynamic> params = new Map();
    params["guid"] = chat.guid;
    params["message"] = message.text.trim();
    String tempGuid = "temp-${randomString(8)}";
    String oldGuid = message.guid;
    params["tempGuid"] = tempGuid;

    // Reset error, guid, and send date
    message.id = null;
    message.error = 0;
    message.guid = tempGuid;
    message.dateCreated = DateTime.now();

    // Delete the old message
    Map<String, dynamic> msgOpts = {'guid': oldGuid};
    await Message.delete(msgOpts);
    NewMessageManager().deleteSpecificMessage(chat, oldGuid);

    // Add the new message
    await chat.addMessage(message);
    NewMessageManager().updateWithMessage(chat, message);

    SocketManager().sendMessage("send-message", params, (response) async {
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
  static Future<void> resyncChat(Chat chat, MessageBloc messageBloc) async {
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
      //find all attachments associated with a message
      var attachments = await db.rawQuery(
          "SELECT"
          " attachmentId,"
          " messageId"
          " FROM attachment_message_join"
          " WHERE messageId = ?",
          [items[i]["messageId"]]);
      //1 -> delete all attachments associated with a message
      for (int j = 0; j < attachments.length; j++) {
        batch.delete("attachment",
            where: "ROWID = ?", whereArgs: [attachments[j]["attachmentId"]]);

        batch.delete("attachment_message_join",
            where: "ROWID = ?", whereArgs: [items[j]["ROWID"]]);
      }

      // 2 -> Delete all messages associated with a chat
      batch.delete("message",
          where: "ROWID = ?", whereArgs: [items[i]["messageId"]]);
      // 3 -> Delete all chat_message_join entries associated with a chat
      batch.delete("chat_message_join",
          where: "ROWID = ?", whereArgs: [items[i]["ROWID"]]);
    }

    // Commit the deletes, then refresh the chats
    await batch.commit(noResult: true);
    NewMessageManager().updateWithMessage(chat, null);

    // Now, let's re-fetch the messages for the chat
    await messageBloc.loadMessageChunk(0);
    ChatBloc().getChats();
  }

  /// Handles the ingestion of a 'updated-message' event. It takes the
  /// input [data] and uses that data to update an already existing
  /// message within the database
  ///
  /// ```dart
  /// handleUpdatedMessage(JsonMap)
  /// ```
  static Future<void> handleUpdatedMessage(Map<String, dynamic> data,
      {bool headless = false}) async {
    Message updatedMessage = new Message.fromMap(data);

    if (updatedMessage.isFromMe) {
      await Future.delayed(Duration(milliseconds: 1000));
    }
    updatedMessage =
        await Message.replaceMessage(updatedMessage.guid, updatedMessage);

    Chat chat;
    if (data["chats"] == null &&
        updatedMessage != null &&
        updatedMessage.id != null) {
      chat = await Message.getChat(updatedMessage);
    } else if (data["chats"] != null) {
      chat = Chat.fromMap(data["chats"][0]);
    }

    if (!headless && updatedMessage != null)
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
      bool checkIfExists = false,
      bool isHeadless = false}) async {
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
    if (currentChat == null) {
      debugPrint("current chat == null, saving");
      await newChat.save();
    }

    // If we already have a chat, don't fetch the participants
    if (currentChat != null) return;
    // if (isHeadless) return;

    Map<String, dynamic> params = Map();
    params["chatGuid"] = newChat.guid;
    params["withParticipants"] = true;
    SocketManager().sendMessage("get-chat", params, (data) async {
      // if (closeSocketOnFinish &&
      //     SocketManager().attachmentDownloaders.length == 0 &&
      //     SocketManager().attachmentSenders.length == 0) {
      //   SocketManager().closeSocket();
      // }
      if (data['status'] != 200) return;

      Map<String, dynamic> chatData = data["data"];
      if (chatData != null) {
        debugPrint("got chat data " + chatData.toString());
        newChat = Chat.fromMap(chatData);

        // Resave the chat after we've got the participants
        await newChat.save();
        debugPrint("saved chat " + newChat.toMap().toString());

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
  static Future<void> handleMessage(Map<String, dynamic> data,
      {bool createAttachmentNotification = false,
      bool isHeadless = false}) async {
    Message message = Message.fromMap(data);
    List<Chat> chats = MessageHelper.parseChats(data);
    // chats.forEach((element) {
    //   ChatBloc().moveChatToTop(element);
    // });

    // Handle message differently depending on if there is a temp GUID match
    if (data.containsKey("tempGuid")) {
      // Check if the GUID exists
      Message existing = await Message.findOne({'guid': data['guid']});

      // If the GUID exists already, delete the temporary entry
      // Otherwise, replace the temp message
      if (existing != null) {
        await Message.delete({'guid': data['tempGuid']});
        NewMessageManager()
            .deleteSpecificMessage(chats.first, data['tempGuid']);
      } else {
        await Message.replaceMessage(data["tempGuid"], message,
            chat: chats.first);
        List<dynamic> attachments =
            data.containsKey("attachments") ? data['attachments'] : [];
        for (dynamic attachmentItem in attachments) {
          Attachment file = Attachment.fromMap(attachmentItem);
          await Attachment.replaceAttachment(data["tempGuid"], file);
        }
        debugPrint("Client received message match for ${data["guid"]}");
        if (!isHeadless)
          NewMessageManager()
              .updateSpecificMessage(chats.first, data['tempGuid'], message);
      }
    } else {
      if (SocketManager().processedGUIDS.contains(data["guid"])) return;

      SocketManager().processedGUIDS.add(data["guid"]);
      // Add the message to the chats
      for (int i = 0; i < chats.length; i++) {
        debugPrint("Client received new message " + chats[i].guid);
        List<String> processedNotificationsCopy = [];
        processedNotificationsCopy
            .addAll(NotificationManager().processedNotifications);
        if (!NotificationManager()
            .processedNotifications
            .contains(message.guid)) {
          NotificationManager().processedNotifications.add(message.guid);
        }
        await ActionHandler.handleChat(
            chat: chats[i], checkIfExists: true, isHeadless: isHeadless);
        Message existing = await Message.findOne({"guid": message.guid});
        if (!message.isFromMe &&
            message.handle != null &&
            (NotificationManager().chatGuid != chats[i].guid ||
                !LifeCycleManager().isAlive) &&
            !chats[i].isMuted &&
            !processedNotificationsCopy.contains(message.guid) &&
            existing == null) {
          String text = message.text;
          if ((data['attachments'] as List<dynamic>).length > 0) {
            text = (data['attachments'] as List<dynamic>).length.toString() +
                " attachment" +
                ((data['attachments'] as List<dynamic>).length > 1 ? "s" : "");
          }
          await chats[i].save();
          String title = await getFullChatTitle(chats[i]);
          NotificationManager().createNewNotification(
              title,
              text,
              chats[i].guid,
              Random().nextInt(9998) + 1,
              chats[i].id,
              message.dateCreated.millisecondsSinceEpoch,
              getContactTitle(message.handle.id, message.handle.address),
              chats[i].participants.length > 1,
              handle: message.handle,
              contact: getContact(message.handle.address));
        }
        await message.save();
        debugPrint(
            "(handle message) handle message ${message.text}, ${message.guid} " +
                data["dateCreated"].toString());
        debugPrint(
            "(handle message) after saving ${message.text}, ${message.guid} " +
                message.dateCreated.millisecondsSinceEpoch.toString());
        await chats[i].addMessage(message);

        // Add notification metadata
        if (!isHeadless &&
            !SocketManager().chatsWithNotifications.contains(chats[i].guid) &&
            NotificationManager().chatGuid != chats[i].guid &&
            !message.isFromMe) {
          SocketManager().chatsWithNotifications.add(chats[i].guid);
        }

        if (message.itemType == ItemTypes.nameChanged.index) {
          chats[i] = await chats[i].changeName(message.groupTitle);
          ChatBloc().updateChat(chats[i]);
        }
      }

      // Add any related attachments
      List<dynamic> attachments =
          data.containsKey("attachments") ? data['attachments'] : [];
      for (var attachmentItem in attachments) {
        Attachment file = Attachment.fromMap(attachmentItem);
        await file.save(message);

        if (SettingsManager().settings.autoDownload &&
            file.mimeType != null &&
            !SocketManager().attachmentDownloaders.containsKey(file.guid)) {
          new AttachmentDownloader(file, message,
              createNotification:
                  createAttachmentNotification && file.mimeType != null);
        }
      }

      chats.forEach((element) {
        // Update chats
        if (!isHeadless)
          NewMessageManager().updateWithMessage(element, message);
      });
    }
  }

  // static void createNotification(Map<String, dynamic> notification) {
  //   if (!NotificationManager()
  //       .processedNotifications
  //       .contains(notification["guid"])) {
  //     NotificationManager().createNewNotification(
  //       notification["contentTitle"],
  //       notification["contentText"],
  //       notification["group"],
  //       notification["id"],
  //       notification["summaryId"],
  //       handle: notification["handle"],
  //     );
  //     NotificationManager().processedNotifications.add(notification["guid"]);
  //   }
  // }
}
