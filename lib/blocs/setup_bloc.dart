import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';

class SetupBloc {
  final _stream = StreamController<double>.broadcast();

  bool _finishedSetup = false;
  double _progress = 0.0;
  int _currentIndex = 0;
  List chats = [];

  Stream<double> get stream => _stream.stream;
  double get progress => _progress;
  bool get finishedSetup => false;

  SetupBloc();

  void startSync(Settings settings) {
    debugPrint(settings.toJson().toString());
    SettingsManager().saveSettings(settings,
        connectToSocket: true, connectCb: () => onConnect());
  }

  void onConnect() {
    debugPrint("connected");
    SocketManager().socket.sendMessage("get-chats", '{}', (data) {
      receivedChats(data);
    });
  }

  void receivedChats(data) async {
    debugPrint("got chats");
    chats = jsonDecode(data)["data"];
    getChatMessagesRecursive(chats, 0);
    _stream.sink.add(_progress);
  }

  void getChatMessagesRecursive(List chats, int index) async {
    Chat chat = Chat.fromMap(chats[index]);
    await chat.save();

    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = 50;
    params["withBlurhash"] = true;
    SocketManager().socket.sendMessage("get-chat-messages", jsonEncode(params),
        (data) {
      receivedMessagesForChat(chat, data);
      if (index + 1 < chats.length) {
        _currentIndex = index + 1;
        getChatMessagesRecursive(chats, index + 1);
      } else {
        finishSetup();
      }
    });
    // if (i == chats.length - 1) {
    //   Settings _settings = _singleton.settings;
    //   _settings.finishedSetup = true;
    //   _singleton.saveSettings(_singleton.settings);
    //   List<Chat> _chats = await Chat.find();
    //   _singleton.chats = _chats;
    //   notify();
    // }
  }

  void receivedMessagesForChat(Chat chat, data) async {
    debugPrint("got messages");
    List messages = jsonDecode(data)["data"];
    MessageHelper.bulkAddMessages(chat, messages);

    _progress = (_currentIndex + 1) / chats.length;
    _stream.sink.add(_progress);
  }

  void finishSetup() {
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup = true;
    _finishedSetup = true;
    SettingsManager().saveSettings(_settingsCopy, connectToSocket: false);
    SocketManager().finishSetup();
  }

  void dispose() {
    _stream.close();
  }
}
