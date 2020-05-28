import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/settings.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/material.dart';

class SetupBloc {
  final _stream = StreamController<double>();

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
    Singleton().saveSettings(settings, true, () => onConnect());
  }

  void onConnect() {
    debugPrint("connected");
    Singleton().socket.sendMessage("get-chats", '{}', (data) {
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
    params["limit"] = 100;
    Singleton().socket.sendMessage("get-chat-messages", jsonEncode(params),
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

    messages.forEach((item) {
      Message message = Message.fromMap(item);
      chat.addMessage(message).then((value) {
        // Create the attachments
        List<dynamic> attachments = item['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
      });
    });
    _progress = (_currentIndex + 1) / chats.length;
    _stream.sink.add(_progress);
  }

  void finishSetup() {
    Settings _settingsCopy = Singleton().settings;
    _settingsCopy.finishedSetup = true;
    _finishedSetup = true;
    Singleton().finishSetup();
  }

  void dispose() {
    _stream.close();
  }
}
