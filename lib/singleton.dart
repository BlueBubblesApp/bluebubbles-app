import 'dart:async';
import 'dart:convert';

// import 'package:adhara_socket_io/manager.dart';
// import 'package:adhara_socket_io/options.dart';
// import 'package:adhara_socket_io/socket.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:bluebubble_messages/SQL/Models/Chats.dart';
import 'package:bluebubble_messages/SQL/Repositories/RepoService.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'SQL/Models/Messages.dart';
import 'settings.dart';

class Singleton {
  static final Singleton _singleton = Singleton._internal();
  factory Singleton() {
    return _singleton;
  }
  Singleton._internal();

  //Socket io
  // SocketIOManager manager;
  IO.Socket socket;

  //general data
  List<Chat> chats = [];
  List<Contact> contacts = <Contact>[];

  //interface with native code
  final platform = const MethodChannel('samples.flutter.dev/fcm');

  //settings
  Settings settings;
  SharedPreferences sharedPreferences;
  String token;

  //for setup, when the user has no saved db
  Completer setupProgress = new Completer();

  Future setup() {
    return setupProgress.future;
  }

  //setstate for these widgets
  List<Function> subscribers = <Function>[];

  void subscribe(Function cb) {
    _singleton.subscribers.add(cb);
  }

  void notify() {
    debugPrint(
        "notifying subscribers: " + _singleton.subscribers.length.toString());
    for (int i = 0; i < _singleton.subscribers.length; i++) {
      _singleton.subscribers[i]();
    }
  }

  void getSavedSettings() async {
    _singleton.sharedPreferences = await SharedPreferences.getInstance();
    var result = _singleton.sharedPreferences.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _singleton.settings = Settings.fromJson(resultMap);
    }
    _singleton.startSocketIO();
    _singleton.authFCM();
  }

  void saveSettings(Settings settings) async {
    if (_singleton.sharedPreferences == null) {
      _singleton.sharedPreferences = await SharedPreferences.getInstance();
    }
    _singleton.sharedPreferences.setString('Settings', jsonEncode(settings));
    _singleton.startSocketIO();
    _singleton.authFCM();
  }

  void startSocketIO() async {
    if (_singleton.chats.length == 0) {
      List<Chat> _chats = await RepositoryServiceChats.getAllChats();
      if (_chats.length != 0) {
        _singleton.chats = _chats;
        setupProgress.complete();
      }
    }
    if (_singleton.socket != null) {
      _singleton.socket.close();
    }
    debugPrint("Starting socket io with the server: " +
        _singleton.settings.serverAddress);
    try {
      _singleton.socket =
          IO.io(_singleton.settings.serverAddress, <String, dynamic>{
        'transports': ['websocket'],
      });

      debugPrint("connecting...");
      _singleton.socket.connect();
      _singleton.socket.on(
        'connect',
        (data) {
          debugPrint("connected");
          _singleton.socket.emit("add-fcm-device-id", [
            {"deviceId": token, "deviceName": "android-client"}
          ]);
          _syncChats();
        },
      );
      _singleton.socket.on("fcm-device-id-added", (data) {
        debugPrint("fcm device added: " + data.toString());
      });
      _singleton.socket.on("error", (data) {
        debugPrint("an error occurred: " + data.toString());
      });
      _singleton.socket.on('chats', (data) {
        debugPrint("got chats");
        List chats = data["data"];
        for (int i = 0; i < chats.length; i++) {
          Chat chat = new Chat(chats[i]);
          _singleton.chats.add(chat);
          Map<String, dynamic> params = Map();
          params["identifier"] = chat.guid;
          params["limit"] = 100;
          _singleton.socket.emitWithAck("get-chat-messages", params,
              ack: (data) {
            debugPrint("got messages: " + data.toString());
            List messagesData = data["data"];
            List<Message> messages = <Message>[];
            for (int i = 0; i < messagesData.length; i++) {
              Message message = Message(messagesData[i]);
              messages.add(message);
            }
            RepositoryServiceMessage.addMessagesToChat(messages);
          });
        }
        notify();
        setupProgress.complete();
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void _syncChats() async {
    if (chats.length == 0) {
      debugPrint("get-chats");
      _singleton.socket.emit("get-chats", null);
    }
  }

  void closeSocket() {
    _singleton.socket.close();
    _singleton.socket = null;
  }

  Future<void> authFCM() async {
    try {
      final String result =
          await platform.invokeMethod('auth', _singleton.settings.fcmAuthData);
      token = result;
      if (_singleton.socket != null)
        _singleton.socket.emit("set-FCM-token", [token]);
      debugPrint(token);
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }
}
