import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
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

  Function onConnectionError;

  SetupBloc();

  void startSync(Settings settings, Function _onConnectionError) {
    onConnectionError = _onConnectionError;
    debugPrint(settings.toJson().toString());
    SocketManager().sendMessage("get-chats", {}, (data) {
      if (data['status'] == 200) {
        receivedChats(data);
      } else {
        onConnectionError();
      }
    });
  }

  void receivedChats(data) async {
    debugPrint("got chats");
    chats = data["data"];
    getChatMessagesRecursive(chats, 0);
    _stream.sink.add(_progress);
  }

  void getChatMessagesRecursive(List chats, int index) async {
    Chat chat = Chat.fromMap(chats[index]);
    await chat.save();

    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = 25;
    params["withBlurhash"] = true;
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];
    SocketManager().sendMessage("get-chat-messages", params, (data) {
      if (data['status'] != 200) {
        onConnectionError();
        return;
      }
      receivedMessagesForChat(chat, data);
      if (index + 1 < chats.length) {
        _currentIndex = index + 1;
        getChatMessagesRecursive(chats, index + 1);
      } else {
        finishSetup();
      }
    });
  }

  void receivedMessagesForChat(Chat chat, Map<String, dynamic> data) async {
    List messages = data["data"];
    MessageHelper.bulkAddMessages(chat, messages);

    _progress = (_currentIndex + 1) / chats.length;
    _stream.sink.add(_progress);
  }

  void finishSetup() async {
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup = true;
    _finishedSetup = true;
    ContactManager().contacts = [];
    await ContactManager().getContacts();
    SettingsManager().saveSettings(_settingsCopy, connectToSocket: false);
    SocketManager().finishSetup();
  }

  void dispose() {
    _stream.close();
  }
}
