import 'dart:async';

import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';

class NewMessageManager {
  factory NewMessageManager() {
    return _manager;
  }

  static final NewMessageManager _manager = NewMessageManager._internal();

  NewMessageManager._internal();

  StreamController<Map<String, Message>> _stream =
      new StreamController<Map<String, Message>>.broadcast();

  Stream<Map<String, Message>> get stream => _stream.stream;

  void updateWithMessage(Chat chat, Message message) {
    _stream.sink.add({chat.guid: message});
  }
}
