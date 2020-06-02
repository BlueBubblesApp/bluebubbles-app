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
  void addAttachmentDownloader(String guid, AttachmentDownloader downloader) {
    attachmentDownloaders[guid] = downloader;
  }

  void finishDownloader(String guid) {
    attachmentDownloaders.remove(guid);
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

      // Let us know when our device was added
      _manager.socket.subscribe("fcm-device-id-added", (data) {
        debugPrint("fcm device added: " + data.toString());
      });

      // Let us know when there is an error
      _manager.socket.subscribe("error", (data) {
        debugPrint("An error occurred: " + data.toString());
      });
      _manager.socket.subscribe("new-message", (_data) async {
        // debugPrint(data.toString());
        debugPrint("new-message");
        Map<String, dynamic> data = jsonDecode(_data);
        if (SocketManager().processedGUIDS.contains(data["guid"])) {
          return new Future.value("");
        } else {
          SocketManager().processedGUIDS.add(data["guid"]);
        }
        if (data["chats"].length == 0) return new Future.value("");
        Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
        if (chat == null) {
          debugPrint("could not find chat, returning");
          return new Future.value("");
        }
        SocketManager().handleNewMessage(data, chat);
        if (data["isFromMe"]) {
          return new Future.value("");
        }

        // String message = data["text"].toString();

        // await _showNotificationWithDefaultSound(0, title, message);

        return new Future.value("");
      });

      _manager.socket.subscribe("updated-message", (_data) async {
        debugPrint("updated-message");
        updateMessage(_data);
        // Map<String, dynamic> data = jsonDecode(_data);
        // debugPrint("updated message: " + data.toString());
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void closeSocket() {
    _manager.socket.destroy();
    _manager.socket = null;
  }

  Future<void> authFCM() async {
    if (SettingsManager().settings.fcmAuthData == null) {
      debugPrint("No FCM Auth data found. Skipping FCM authentication");
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
    // Message updatedMessage = new Message.fromMap(data);
    // updatedMessage =
    //     await Message.replaceMessage(updatedMessage.guid, updatedMessage);
    // updatedMessage.save();
    // debugPrint("updated message with ROWID " + updatedMessage.id.toString());
  }

  void handleNewMessage(Map<String, dynamic> data, Chat chat) {
    Message message = new Message.fromMap(data);
    if (message.isFromMe) {
      Timer(Duration(seconds: 3), () {
        if (!processedGUIDS.contains(message.guid)) {
          chat.save().then((_chat) {
            _chat.addMessage(message).then((value) {
              // if (value == null) {
              //   return;
              // }

              debugPrint("new message " + message.text);
              // Create the attachments
              List<dynamic> attachments = data['attachments'];

              attachments.forEach((attachmentItem) {
                Attachment file = Attachment.fromMap(attachmentItem);
                file.save(message);
              });
              NewMessageManager().updateWithMessage(_chat, message);
            });
          });
        }
      });
    } else {
      chat.addMessage(message).then((value) {
        // if (value == null) return;
        // Create the attachments
        debugPrint("new message " + chat.guid);
        List<dynamic> attachments = data['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
        if (!chatsWithNotifications.contains(chat.guid)) {
          chatsWithNotifications.add(chat.guid);
        }
        NewMessageManager().updateWithMessage(chat, message);
      });
    }
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

      // Find the message and update the message with the new GUID
      if (response['status'] == 200) {
        processedGUIDS.add(response['data']['guid']);
        await Message.replaceMessage(
            tempGuid, Message.fromMap(response['data']));
      } else {
        // If there is an error, replace the temp value with an error
        sentMessage.guid = sentMessage.guid.replaceAll("temp", "error");
        await Message.replaceMessage(tempGuid, sentMessage);
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
    SocketManager().socket.sendMessage("get-chat-messages", jsonEncode(params),
        (data) {
      List messages = jsonDecode(data)["data"];
      MessageHelper.bulkAddMessages(chat, messages);
    });

    // TODO: Notify when done?
  }
}
