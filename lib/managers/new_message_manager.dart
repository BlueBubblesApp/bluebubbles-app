import 'dart:async';

import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

class NewMessageType {
  // ignore: non_constant_identifier_names
  static String ADD = "NEW";
  // ignore: non_constant_identifier_names
  static String REMOVE = "REMOVE";
  // ignore: non_constant_identifier_names
  static String UPDATE = "UPDATE";
}

class NewMessageManager {
  factory NewMessageManager() {
    return _manager;
  }

  static final NewMessageManager _manager = NewMessageManager._internal();
  NewMessageManager._internal();

  // Structure of the stream data:
  // {
  //   "<chat GUID>": {
  //     "<action>": [
  //       ...Some items to take action on
  //     ]
  //   }
  // }

  StreamController<Map<String, Map<String, List<Map<String, dynamic>>>>>
      _stream = new StreamController<
          Map<String, Map<String, List<Map<String, dynamic>>>>>.broadcast();

  Stream<Map<String, Map<String, List<Map<String, dynamic>>>>> get stream =>
      _stream.stream;

  void removeMessage(Chat chat, String guid) {
    _stream.sink.add({
      chat.guid: {
        NewMessageType.REMOVE: [
          {"guid": guid}
        ]
      }
    });
  }

  void updateMessage(Chat chat, String oldGuid, Message message) {
    // If the message is not from yourself, we don't need an update
    // Theoretically, addMessage will be called for all incoming messages
    if (!message.isFromMe) return;

    _stream.sink.add({
      chat.guid: {
        NewMessageType.UPDATE: [
          {"oldGuid": oldGuid, "message": message}
        ]
      }
    });
  }

  void addMessage(Chat chat, Message message, {bool outgoing = false}) {
    if (chat == null) {
      debugPrint("No chat provided to NewMessageManager!");
      return;
    }

    _stream.sink.add({
      chat.guid: {
        NewMessageType.ADD: [
          {"message": message, "outgoing": outgoing, "chat": chat}
        ]
      }
    });
  }

  dispose() {
    _stream.close();
  }
}
