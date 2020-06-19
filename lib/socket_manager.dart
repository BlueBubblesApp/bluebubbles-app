import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/blocs/setup_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/managers/navigator_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/queue_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
      if (chatsWithNotifications[i] == chat.guid) {
        chatsWithNotifications.removeAt(i);
        break;
      }
    }
    // NewMessageManager().updateWithMessage(chat, null);
  }

  List<String> processedGUIDS = <String>[];

  SetupBloc setup = new SetupBloc();
  StreamController<bool> finishedSetup = StreamController<bool>();

  //Socket io
  // SocketIOManager manager;
  SocketIO socket;

  //setstate for these widgets
  Map<String, Function> subscribers = new Map();

  Map<String, AttachmentDownloader> attachmentDownloaders = Map();
  Map<String, List<AttachmentSender>> attachmentSenders = Map();

  Function connectCb;
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

  void socketStatusUpdate(data) {
    switch (data) {
      case "connect":
        debugPrint("CONNECTED");
        authFCM();
        // syncChats();
        // if (connectCB != null) {
        // }
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });

        SettingsManager().settings.connected = true;
        if (connectCb != null) connectCb();
        return;
      case "disconnect":
        _manager.disconnectSubscribers.values.forEach((f) {
          f();
        });
        debugPrint("disconnected");
        SettingsManager().settings.connected = false;
        return;
      case "reconnect":
        debugPrint("RECONNECTED");
        SettingsManager().settings.connected = true;
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

  startSocketIO({Function connectCB}) async {
    if (connectCB == null && SettingsManager().settings.finishedSetup == false)
      return;
    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket.destroy();
    }
    connectCb = connectCB;

    debugPrint(
        "Starting socket io with the server: ${SettingsManager().settings.serverAddress}");

    try {
      // Create a new socket connection
      _manager.socket = SocketIOManager().createSocketIO(
          SettingsManager().settings.serverAddress, "/",
          query: "guid=${SettingsManager().settings.guidAuthKey}",
          socketStatusCallback: (data) => socketStatusUpdate(data));
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
        }

        SocketManager().processedGUIDS.add(data["guid"]);
        QueueManager().addEvent("new-message", _data);
        return new Future.value("");
      });

      /**
       * Handle errors sent by the server
       */
      _manager.socket.subscribe("message-send-error", (_data) async {
        Map<String, dynamic> data = jsonDecode(_data);
        Message message = Message.fromMap(data);

        // If there are no chats, try to find it in the DB via the message
        Chat chat;
        if (data["chats"].length == 0) {
          chat = await Message.getChat(message);
        } else {
          chat = Chat.fromMap(data['chats'][0]);
        }

        // Save the chat in-case is doesn't exist
        if (chat != null) {
          await chat.save();
        }

        // Lastly, save the message
        await message.save();
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
        message.error = 1003;
        message.guid = message.guid.replaceAll("temp", "error-Message Timeout");
        await Message.replaceMessage(data["tempGuid"], message);
        return new Future.value("");
      });

      /**
       * When an updated message comes in, update it in the database.
       * This may be when a read/delivered date has been changed.
       */
      _manager.socket.subscribe("updated-message", (_data) async {
        QueueManager().addEvent("updated-message", _data);
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

  void finishSetup() {
    finishedSetup.sink.add(true);
    NewMessageManager().updateWithMessage(null, null);
    // notify();
  }
}
