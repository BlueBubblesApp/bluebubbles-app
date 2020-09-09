import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/outgoing_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
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

    List<Message> messages = <Message>[];

    // Check for URLs
    RegExpMatch linkMatch;
    String linkMsg;
    List<RegExpMatch> matches = parseLinks(text);

    // Get the first match (if it exists)
    if (matches.length > 0) {
      linkMatch = matches.first;
      linkMsg = text.substring(linkMatch.start, linkMatch.end);
    }

    bool shouldSplit = linkMatch != null && text.endsWith(linkMsg);

    // Create the main message
    Message mainMsg = Message(
      guid: "temp-${randomString(8)}",
      text: (!shouldSplit) ? text : text.substring(0, linkMatch.start),
      dateCreated: DateTime.now(),
      hasAttachments: attachments.length > 0 ? true : false,
    );

    if (mainMsg.text.trim().length > 0) messages.add(mainMsg);

    // If there is a link, build the link message
    if (shouldSplit) {
      messages.add(Message(
        guid: "temp-${randomString(8)}",
        text: text.substring(linkMatch.start, linkMatch.end),
        dateCreated: DateTime.now(),
        hasAttachments: false,
      ));
    }

    // Make sure to save the chat
    await chat.save();

    // Send all the messages
    for (Message message in messages) {
      // Add the message to the UI and DB
      NewMessageManager()
          .addMessage(chat, message, outgoing: true);
      await chat.addMessage(message);

      // Create params for the queue item
      Map<String, dynamic> params = {"chat": chat, "message": message};

      // Add the message send to the queue
      await OutgoingQueue()
          .add(new QueueItem(event: "send-message", item: params));
    }
  }

  static Future<void> sendMessageHelper(Chat chat, Message message) async {
    Completer<void> completer = new Completer<void>();
    Map<String, dynamic> params = new Map();
    params["guid"] = chat.guid;
    params["message"] = message.text;
    params["tempGuid"] = message.guid;

    // // If we aren't connected to the socket, return
    // if (SettingsManager().settings.connected == false) return;
    SocketManager().sendMessage("send-message", params, (response) async {
      String tempGuid = message.guid;

      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        message.guid = message.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        message.error = response['status'] == 400
            ? MessageError.BAD_REQUEST.code
            : MessageError.SERVER_ERROR.code;

        await Message.replaceMessage(tempGuid, message);
        NewMessageManager().updateMessage(chat, tempGuid, message);
      }

      completer.complete();
    });

    return completer.future;
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

    await Message.getAttachments(message);
    for (int i = 0; i < message.attachments.length; i++) {
      String appDocPath = SettingsManager().appDocDir.path;
      String pathName =
          "$appDocPath/attachments/${message.attachments[i].guid}/${message.attachments[i].transferName}";
      File file = File(pathName);

      OutgoingQueue().add(new QueueItem(
          event: "send-attachment",
          item: new AttachmentSender(
            file,
            chat,
            i == message.attachments.length - 1 ? message.text : "",
          )));
    }

    // If we sent attachments, return because we finished sending
    if (message.attachments.length > 0) return;

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
    NewMessageManager().removeMessage(chat, oldGuid);

    // Add the new message
    await chat.addMessage(message);
    NewMessageManager().addMessage(chat, message);

    SocketManager().sendMessage("send-message", params, (response) async {
      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        message.guid = message.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        message.error = response['status'] == 400 ? 1001 : 1002;
        await Message.replaceMessage(tempGuid, message);
        NewMessageManager().addMessage(chat, message);
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
        " ROWID,"
        " chatId,"
        " messageId"
        " FROM chat_message_join"
        " WHERE chatId = ?",
        [chat.id]);

    // If there are no messages, return
    debugPrint("Deleting ${items.length} messages");
    if (items.length == 0) return;

    Batch batch = db.batch();
    for (Map<String, dynamic> message in items) {
      // Find all attachments associated with a message
      var attachments = await db.rawQuery(
          "SELECT"
          " ROWID,"
          " attachmentId,"
          " messageId"
          " FROM attachment_message_join"
          " WHERE messageId = ?",
          [message["messageId"]]);

      // 1 -> Delete all attachments associated with a message
      for (Map<String, dynamic> attachment in attachments) {
        batch.delete("attachment",
            where: "ROWID = ?", whereArgs: [attachment["attachmentId"]]);

        batch.delete("attachment_message_join",
            where: "ROWID = ?", whereArgs: [attachment["ROWID"]]);
      }

      // 2 -> Delete all messages associated with a chat
      batch.delete("message",
          where: "ROWID = ?", whereArgs: [message["messageId"]]);
      // 3 -> Delete all chat_message_join entries associated with a chat
      batch.delete("chat_message_join",
          where: "ROWID = ?", whereArgs: [message["ROWID"]]);
    }

    // Commit the deletes
    await batch.commit(noResult: true, continueOnError: true);

    // Now, let's re-fetch the messages for the chat
    await messageBloc.loadMessageChunk(0, includeReactions: false);
    ChatBloc().refreshChats();
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
          .updateMessage(chat, updatedMessage.guid, updatedMessage);
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
        await ChatBloc().updateChatPosition(newChat);
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
            .removeMessage(chats.first, data['tempGuid']);
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
              .updateMessage(chats.first, data['tempGuid'], message);
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
        Chat chat = ChatBloc().getChat(chats[i].guid);
        if (chat == null) {
          await ActionHandler.handleChat(
              chat: chats[i], checkIfExists: true, isHeadless: isHeadless);
          chat = chats[i];
        }
        Message existing = await Message.findOne({"guid": message.guid});
        await chats[i].save();
        if (!message.isFromMe &&
            message.handle != null &&
            (NotificationManager().chatGuid != chat.guid ||
                !LifeCycleManager().isAlive) &&
            !chat.isMuted &&
            !processedNotificationsCopy.contains(message.guid) &&
            existing == null) {
          String title = await getFullChatTitle(chats[i]);
          NotificationManager().createNewNotification(
              title,
              MessageHelper.getNotificationText(message),
              chats[i].guid,
              Random().nextInt(9998) + 1,
              chat.id,
              message.dateCreated.millisecondsSinceEpoch,
              getContactTitle(message.handle.id, message.handle.address),
              chat.participants.length > 1,
              handle: message.handle,
              contact: getContact(message.handle.address));
        }

        debugPrint(
            "(handle message) handle message ${message.text}, ${message.guid} " +
                data["dateCreated"].toString());
        debugPrint(
            "(handle message) after saving ${message.text}, ${message.guid} " +
                message.dateCreated.millisecondsSinceEpoch.toString());
        await chat.addMessage(message);

        if (message.itemType == ItemTypes.nameChanged.index) {
          chat = await chat.changeName(message.groupTitle);
          ChatBloc().updateChat(chat);
        }

        // Replace the chat with the updated chat
        chats[i] = chat;
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
        if (!isHeadless)
          NewMessageManager().addMessage(element, message);
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
