import 'dart:async';

import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

class NewMessageManager {
  factory NewMessageManager() {
    return _manager;
  }

  static final NewMessageManager _manager = NewMessageManager._internal();

  NewMessageManager._internal();

  StreamController<Map<String, dynamic>> _stream =
      new StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _stream.stream;

  void updateSpecificMessage(Chat chat, String oldGuid, Message message) {
    _stream.sink.add({chat.guid: message, "oldGuid": oldGuid});
  }

  void updateWithMessage(Chat chat, Message message,
      {bool sentFromThisClient = false}) {
    if (chat == null) {
      _stream.sink.add({null: message});
    } else {
      _stream.sink
          .add({chat.guid: message, "sentFromThisClient": sentFromThisClient});
    }
  }
}
