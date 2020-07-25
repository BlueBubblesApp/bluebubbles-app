import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';

class SetupBloc {
  final _stream = StreamController<double>.broadcast();

  bool _finishedSetup = false;
  double _progress = 0.0;
  int _currentIndex = 0;
  List chats = [];
  bool isSyncing = false;

  Stream<double> get stream => _stream.stream;
  double get progress => _progress;
  bool get finishedSetup => false;
  bool _isMiniResync = false;
  int processId;

  Function onConnectionError;

  SetupBloc();

  void startSync(Settings settings, Function _onConnectionError,
      {bool isMiniResync = false}) {
    if (isSyncing) return;
    processId =
        SocketManager().addSocketProcess(([bool finishWithError = false]) {});
    onConnectionError = _onConnectionError;
    debugPrint(settings.toJson().toString());
    _isMiniResync = isMiniResync;
    isSyncing = true;
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
    params["withBlurhash"] = false;
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];
    if (_isMiniResync) {
      List<Message> messages = await Chat.getMessages(chat);
      if (messages.length != 0) {
        params["after"] = messages.first.dateCreated.millisecondsSinceEpoch;
      } else {
        params["limit"] = 25;
      }
    }
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
    MessageHelper.bulkAddMessages(chat, messages,
        notifyForNewMessage: _isMiniResync);

    _progress = (_currentIndex + 1) / chats.length;
    _stream.sink.add(_progress);
  }

  void finishSetup() async {
    isSyncing = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);
    if (!_isMiniResync) {
      Settings _settingsCopy = SettingsManager().settings;
      _settingsCopy.finishedSetup = true;
      _finishedSetup = true;
      ContactManager().contacts = [];
      await ContactManager().getContacts();
      SettingsManager().saveSettings(_settingsCopy, connectToSocket: false);
      SocketManager().finishSetup();
    }
  }

  void dispose() {
    _stream.close();
  }
}
