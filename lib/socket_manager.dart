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
    NewMessageManager().updateWithMessage(chat, null);
    // notify();
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

  void socketStatusUpdate(data, [Function() connectCB]) {
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
        connectCB();
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

  startSocketIO({Function connectCb}) async {
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

  Future<void> handleUpdatedMessage(Map<String, dynamic> data) async {
    Message updatedMessage = new Message.fromMap(data);
    updatedMessage = await Message.replaceMessage(updatedMessage.guid, updatedMessage);

    Chat chat;
    if (data["chat"] == null && updatedMessage != null && updatedMessage.id != null) {
      chat = await Message.getChat(updatedMessage);
    } else if (data["chat"] != null) {
      chat = Chat.fromMap(data["chat"][0]);
    }

    NewMessageManager().updateWithMessage(chat, updatedMessage);
  }

  Future<void> handleNewChat({Map<String, dynamic> chatData, Chat chat, bool checkIfExists = false}) async {
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
    if (currentChat == null)
      await newChat.save();

    // If we already have a chat, don't fetch the participants
    if (currentChat != null) return;

    Map<String, dynamic> params = Map();
    params["chatGuid"] = newChat.guid;
    params["withParticipants"] = true;
    SocketManager().socket.sendMessage("get-chat", jsonEncode(params), (data) async {
      Map<String, dynamic> chatData = jsonDecode(data)["data"];
      if (chatData != null) {
        newChat = Chat.fromMap(chatData);

        // Resave the chat after we've got the participants
        await newChat.save();

        // Update the main view
        await ChatBloc().getChats();
        NewMessageManager().updateWithMessage(null, null);
      }
    });
  }

  Future<void> handleNewMessage(Map<String, dynamic> data) async {
    Message message = Message.fromMap(data);

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
      List<Chat> chats = MessageHelper.parseChats(data);

      // Add the message to the chats
      for (int i = 0; i < chats.length; i++) {
        debugPrint("Client received new message " + chats[i].guid);
        await SocketManager().handleNewChat(chat: chats[i], checkIfExists: true);
        await chats[i].addMessage(message);

        // Add notification metadata
        if (!chatsWithNotifications.contains(chats[i].guid) && NotificationManager().chat != chats[i].guid) {
          chatsWithNotifications.add(chats[i].guid);
        }

        // Update chats
        NewMessageManager().updateWithMessage(chats[i], message);
      }
      
      // Add any related attachments
      List<dynamic> attachments = data.containsKey("attachments") ? data['attachments'] : [];
      attachments.forEach((attachmentItem) async {
        Attachment file = Attachment.fromMap(attachmentItem);
        await file.save(message);

        if (SettingsManager().settings.autoDownload) {
          new AttachmentDownloader(file);
        }
      });
    }
  }

  void finishSetup() {
    finishedSetup.sink.add(true);
    NewMessageManager().updateWithMessage(null, null);
    // notify();
  }

  /// Message Error Codes
  ///
  /// - 0: No error
  /// - 4: Timeout
  /// - 1000 (app specific): No connection to server
  /// - 1001 (app specific): Bad request
  /// - 1002 (app specific): Server error

  void sendMessage(Chat chat, String text,
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

    // If we aren't conneted to the socket, set the message error code
    if (SettingsManager().settings.connected == false) sentMessage.error = 1000;

    await sentMessage.save();
    await chat.save();
    await chat.addMessage(sentMessage);
    NewMessageManager().updateWithMessage(chat, sentMessage);

    // If we aren't connected to the socket, return
    if (SettingsManager().settings.connected == false) return;

    if (_manager.socket == null) {
      _manager.startSocketIO(
          connectCb: () => _manager.socket.sendMessage(
                  "send-message", jsonEncode(params), (data) async {
                Map response = jsonDecode(data);
                debugPrint("message sent: " + response.toString());

                // If there is an error, replace the temp value with an error
                if (response['status'] != 200) {
                  sentMessage.guid = sentMessage.guid.replaceAll(
                      "temp", "error-${response['error']['message']}");
                  sentMessage.error = response['status'] == 400 ? 1001 : 1002;
                  await Message.replaceMessage(tempGuid, sentMessage);
                  NewMessageManager().updateWithMessage(chat, null);
                }
              }));
    } else {
      _manager.socket.sendMessage("send-message", jsonEncode(params),
          (data) async {
        Map response = jsonDecode(data);
        debugPrint("message sent: " + response.toString());

        // If there is an error, replace the temp value with an error
        if (response['status'] != 200) {
          sentMessage.guid = sentMessage.guid
              .replaceAll("temp", "error-${response['error']['message']}");
          sentMessage.error = response['status'] == 400 ? 1001 : 1002;
          await Message.replaceMessage(tempGuid, sentMessage);
          NewMessageManager().updateWithMessage(chat, null);
        }
      });
    }
  }

  void retryMessage(Message message) async {
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
    NewMessageManager().updateWithMessage(chat, null);

    // If we aren't connected to the socket, return
    if (SettingsManager().settings.connected == false) return;

    _manager.socket.sendMessage("send-message", jsonEncode(params),
        (data) async {
      Map response = jsonDecode(data);
      debugPrint("message sent: " + response.toString());

      // If there is an error, replace the temp value with an error
      if (response['status'] != 200) {
        message.guid = message.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        message.error = response['status'] == 400 ? 1001 : 1002;
        await Message.replaceMessage(tempGuid, message);
        NewMessageManager().updateWithMessage(chat, null);
      }
    });
  }

  Future<void> resyncChat(Chat chat) async {
    // Flow:
    // 1 -> Delete all messages associated with a chat
    // 2 -> Delete all chat_message_join entries associated with a chat
    // 3 -> Run the resync
    Completer completer = new Completer();

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

    NewMessageManager().updateWithMessage(chat, null);

    // 3 -> Run the resync
    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = 100;
    params["withBlurhash"] = false;
    SocketManager().socket.sendMessage("get-chat-messages", jsonEncode(params),
        (data) {
      List messages = jsonDecode(data)["data"];
      MessageHelper.bulkAddMessages(chat, messages);
      NewMessageManager().updateWithMessage(chat, null);
      completer.complete();
    });
    return completer.future;
  }
}
