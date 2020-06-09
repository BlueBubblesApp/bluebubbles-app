import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/blocs/setup_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bluebubble_messages/helpers/message_helper.dart';

import 'helpers/attachment_sender.dart';
import 'managers/method_channel_interface.dart';
import 'repository/models/attachment.dart';
import 'repository/models/message.dart';
import 'settings.dart';
import './blocs/chat_bloc.dart';
import './repository/models/chat.dart';
import './repository/models/handle.dart';

class SocketManager {
  factory SocketManager() {
    return _manager;
  }

  static final SocketManager _manager = SocketManager._internal();

  SocketManager._internal();

  List<String> chatsWithNotifications = <String>[];

  void removeChatNotification(Chat chat) {
    for (int i = 0; i < chatsWithNotifications.length; i++) {
      debugPrint(i.toString());
      if (chatsWithNotifications[i] == chat.guid) {
        chatsWithNotifications.removeAt(i);
        break;
      }
    }
    NewMessageManager().updateWithMessage(chat, null);
    // notify();
  }

  List<String> processedGUIDS = [];

  SetupBloc setup = new SetupBloc();
  StreamController<bool> finishedSetup = StreamController<bool>();

  //Socket io
  // SocketIOManager manager;
  SocketIO socket;

  //setstate for these widgets
  Map<String, Function> subscribers = new Map();

  Map<String, AttachmentDownloader> attachmentDownloaders = Map();
  Map<String, List<AttachmentSender>> attachmentSenders = Map();
  void addAttachmentDownloader(String guid, AttachmentDownloader downloader) {
    attachmentDownloaders[guid] = downloader;
  }

  void addAttachmentSender(String guid, AttachmentSender sender) {
    if (!attachmentSenders.containsKey(guid))
      attachmentSenders[guid] = <AttachmentSender>[];
    attachmentSenders[guid].add(sender);
  }

  void finishDownloader(String guid) {
    attachmentDownloaders.remove(guid);
  }

  void finishSender(String chatGuid, String messageGuid) {
    for (int i = attachmentSenders[chatGuid].length - 1; i >= 0; i--) {
      if (attachmentSenders[chatGuid][i].guid == messageGuid) {
        attachmentSenders[chatGuid].removeAt(i);
      }
    }
  }

  Map<String, Function> disconnectSubscribers = new Map();

  String token;

  void disconnectCallback(Function cb, String guid) {
    _manager.disconnectSubscribers[guid] = cb;
  }

  void unSubscribeDisconnectCallback(String guid) {
    _manager.disconnectSubscribers.remove(guid);
  }

  void socketStatusUpdate(data, [Function connectCB]) {
    switch (data) {
      case "connect":
        debugPrint("CONNECTED");
        authFCM();
        // syncChats();
        if (connectCB != null) {
          connectCB();
        }
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });
        return;
      case "disconnect":
        _manager.disconnectSubscribers.values.forEach((f) {
          f();
        });
        debugPrint("disconnected");
        return;
      case "reconnect":
        debugPrint("RECONNECTED");
        return;
      default:
        return;
    }
  }

  Future<void> deleteDB() async {
    Database db = await DBProvider.db.database;

    // Remove base tables
    await Handle.flush();
    await Chat.flush();
    await Attachment.flush();
    await Message.flush();

    // Remove join tables
    await db.execute("DELETE FROM chat_handle_join");
    await db.execute("DELETE FROM chat_message_join");
    await db.execute("DELETE FROM attachment_message_join");

    // Recreate tables
    DBProvider.db.buildDatabase(db);
  }

  startSocketIO([Function connectCb]) async {
    if (connectCb == null && SettingsManager().settings.finishedSetup == false)
      return;
    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket.destroy();
    }

    debugPrint(
        "Starting socket io with the server: ${SettingsManager().settings.serverAddress}");

    try {
      // Create a new socket connection
      _manager.socket = SocketIOManager().createSocketIO(
          SettingsManager().settings.serverAddress, "/",
          query: "guid=${SettingsManager().settings.guidAuthKey}",
          socketStatusCallback: (data) => socketStatusUpdate(data, connectCb));
      _manager.socket.init();
      _manager.socket.connect();
      _manager.socket.unSubscribesAll();

      /**
       * Callback event for when the server successfully added a new FCM device
       */
      _manager.socket.subscribe("fcm-device-id-added", (data) {
        // TODO: Possibly turn this into a notification for the user?
        // This could act as a "pseudo" security measure so they're alerted
        // when a new device is registered
        debugPrint("fcm device added: " + data.toString());
      });

      /**
       * If the server sends us an error it ran into, handle it
       */
      _manager.socket.subscribe("error", (data) {
        debugPrint("An error occurred: " + data.toString());
      });

      /**
       * Handle new messages detected by the server
       */
      _manager.socket.subscribe("new-message", (_data) async {
        debugPrint("Client received new message");
        Map<String, dynamic> data = jsonDecode(_data);
        if (SocketManager().processedGUIDS.contains(data["guid"])) {
          return new Future.value("");
        } else {
          SocketManager().processedGUIDS.add(data["guid"]);
        }

        // If there are no chats, there's nothing to associate the message to, so skip
        if (data["chats"].length == 0) return new Future.value("");

        for (int i = 0; i < data["chats"].length; i++) {
          Chat chat = Chat.fromMap(data["chats"][i]);
          await chat.save();
          SocketManager().handleNewMessage(data, chat);
        }

        return new Future.value("");
      });

      /**
       * When the server detects a message timeout (aka, no match found),
       * handle it by replacing the temp-guid with error-guid so we can do
       * something about it (or at least just track it)
       */
      _manager.socket.subscribe("message-timeout", (_data) async {
        debugPrint("Client received message timeout");
        Map<String, dynamic> data = jsonDecode(_data);

        Message message = await Message.findOne({"guid": data["tempGuid"]});
        message.guid = message.guid.replaceAll("temp", "error");
        await Message.replaceMessage(data["tempGuid"], message);
        return new Future.value("");
      });

      /**
       * When an updated message comes in, update it in the database.
       * This may be when a read/delivered date has been changed.
       */
      _manager.socket.subscribe("updated-message", (_data) async {
        debugPrint("updated-message");
        updateMessage(jsonDecode(_data));
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void closeSocket() {
    if (_manager.socket != null) _manager.socket.destroy();
    _manager.socket = null;
  }

  Future<void> authFCM() async {
    if (SettingsManager().settings.fcmAuthData == null) {
      debugPrint("No FCM Auth data found. Skipping FCM authentication");
      return;
    } else if (token != null) {
      debugPrint("already authorized fcm " + token);
      if (_manager.socket != null) {
        _manager.socket.sendMessage(
            "add-fcm-device",
            jsonEncode({"deviceId": token, "deviceName": "android-client"}),
            () {});
      }
      return;
    }

    try {
      final String result = await MethodChannelInterface()
          .invokeMethod('auth', SettingsManager().settings.fcmAuthData);
      token = result;
      if (_manager.socket != null) {
        _manager.socket.sendMessage(
            "add-fcm-device",
            jsonEncode({"deviceId": token, "deviceName": "android-client"}),
            () {});
        debugPrint(token);
      }
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }

  void updateMessage(Map<String, dynamic> data) async {
    Message updatedMessage = new Message.fromMap(data);
    updatedMessage =
        await Message.replaceMessage(updatedMessage.guid, updatedMessage);
    updatedMessage.save();
    NewMessageManager().updateWithMessage(null, null);
    debugPrint("updated message with ROWID " + updatedMessage.id.toString());
  }

  void handleNewMessage(Map<String, dynamic> data, Chat chat) async {
    Message message = new Message.fromMap(data);

    // Handle message differently depending on if there is a temp GUID match
    if (data.containsKey("tempGuid")) {
      debugPrint("Client received message match for ${data["guid"]}");
      await Message.replaceMessage(data["tempGuid"], message);
      List<dynamic> attachments =
          data.containsKey("attachments") ? data['attachments'] : [];
      attachments.forEach((attachmentItem) async {
        Attachment file = Attachment.fromMap(attachmentItem);
        Attachment.replaceAttachment(data["tempGuid"], file);
      });
    } else {
      debugPrint("Client received new message " + chat.guid);
      message = new Message.fromMap(data);
      await chat.addMessage(message);
      // Add any related attachments
      List<dynamic> attachments =
          data.containsKey("attachments") ? data['attachments'] : [];
      attachments.forEach((attachmentItem) async {
        Attachment file = Attachment.fromMap(attachmentItem);
        await file.save(message);
        if (SettingsManager().settings.autoDownload)
          new AttachmentDownloader(file);
      });
    }

    if (!chatsWithNotifications.contains(chat.guid)) {
      chatsWithNotifications.add(chat.guid);
    }

    NewMessageManager().updateWithMessage(chat, message);
  }

  void finishSetup() {
    finishedSetup.sink.add(true);
    NewMessageManager().updateWithMessage(null, null);
    // notify();
  }

  void sendMessage(Chat chat, String text,
      {List<Attachment> attachments = const []}) async {
    debugPrint(chat.participants.toString());
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

    // Add attachments
    for (int i = 0; i < attachments.length; i++) {
      // TODO: Do something here
    }

    await sentMessage.save();
    await chat.save();
    await chat.addMessage(sentMessage);
    NewMessageManager().updateWithMessage(chat, sentMessage);

    _manager.socket.sendMessage("send-message", jsonEncode(params),
        (data) async {
      Map response = jsonDecode(data);
      debugPrint("message sent: " + response.toString());

      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        sentMessage.guid = sentMessage.guid.replaceAll("temp", "error");
        await Message.replaceMessage(tempGuid, sentMessage);

        // TODO: Display an error next to message that failed to send (in message list)
      }
    });
  }

  Future<void> resyncChat(Chat chat) async {
    // Flow:
    // 1 -> Delete all messages associated with a chat
    // 2 -> Delete all chat_message_join entries associated with a chat
    // 3 -> Run the resync

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
          where: "ROWID = ?", whereArgs: [items[0]["messageId"]]);
      // 2 -> Delete all chat_message_join entries associated with a chat
      batch.delete("chat_message_join",
          where: "ROWID = ?", whereArgs: [items[0]["ROWID"]]);
    }

    await batch.commit(noResult: true);

    // notify();
    NewMessageManager().updateWithMessage(chat, null);

    // 3 -> Run the resync
    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = 100;
    params["withBlurhash"] = true;
    SocketManager().socket.sendMessage("get-chat-messages", jsonEncode(params),
        (data) {
      List messages = jsonDecode(data)["data"];
      MessageHelper.bulkAddMessages(chat, messages);
    });

    // TODO: Notify when done?
  }
}
