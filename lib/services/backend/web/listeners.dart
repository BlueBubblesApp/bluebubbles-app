import 'dart:async';

import 'package:bluebubbles/models/models.dart';
import 'package:tuple/tuple.dart';

/// Class to replace objectbox DB listener functionality with an old-fashioned
/// stream based listener
class WebListeners {
  static final Set<String> _messageGuids = {};
  static final Set<String> _chatGuids = {};

  static final StreamController<Tuple3<Message, String?, Chat?>> _messageUpdate = StreamController.broadcast();
  static final StreamController<Tuple2<Message, Chat?>> _newMessage = StreamController.broadcast();

  static final StreamController<Chat> _chatUpdate = StreamController.broadcast();
  static final StreamController<Chat> _newChat = StreamController.broadcast();

  static Stream<Tuple3<Message, String?, Chat?>> get messageUpdate => _messageUpdate.stream;
  static Stream<Tuple2<Message, Chat?>> get newMessage => _newMessage.stream;

  static Stream<Chat> get chatUpdate => _chatUpdate.stream;
  static Stream<Chat> get newChat => _newChat.stream;

  static void notifyMessage(Message m, {Chat? chat, String? tempGuid}) {
    if (tempGuid != null) {
      if (_messageGuids.contains(tempGuid)) {
        _messageGuids.add(m.guid!);
        _messageUpdate.add(Tuple3(m, tempGuid, chat));
      } else {
        _messageGuids.add(tempGuid);
        _newMessage.add(Tuple2(m, chat));
      }
    } else {
      if (_messageGuids.contains(m.guid)) {
        _messageUpdate.add(Tuple3(m, null, chat));
      } else {
        _messageGuids.add(m.guid!);
        _newMessage.add(Tuple2(m, chat));
      }
    }
  }

  static void notifyChat(Chat c) {
    if (_chatGuids.contains(c.guid)) {
      _chatUpdate.add(c);
    } else {
      _chatGuids.add(c.guid);
      _newChat.add(c);
    }
  }
}