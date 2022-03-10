import 'dart:async';

import 'package:bluebubbles/repository/models/models.dart';

class NewMessageType {
  // ignore: non_constant_identifier_names
  static String ADD = "NEW";
  // ignore: non_constant_identifier_names
  static String REMOVE = "REMOVE";
  // ignore: non_constant_identifier_names
  static String UPDATE = "UPDATE";
}

class NewMessageEvent {
  String chatGuid;
  String type;
  Map<String, dynamic> event;

  NewMessageEvent({required this.chatGuid, required this.type, required this.event});
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

  final StreamController<NewMessageEvent> _stream = StreamController<NewMessageEvent>.broadcast();

  Stream<NewMessageEvent> get stream => _stream.stream;

  void removeMessage(Chat chat, String? guid) {
    _stream.sink.add(
      NewMessageEvent(
        chatGuid: chat.guid,
        type: NewMessageType.REMOVE,
        event: {"guid": guid},
      ),
    );
  }

  void updateMessage(Chat chat, String oldGuid, Message message) {
    // If the message is not from yourself, we don't need an update
    // Theoretically, addMessage will be called for all incoming messages
    if (!message.isFromMe!) return;

    _stream.sink.add(
      NewMessageEvent(
        chatGuid: chat.guid,
        type: NewMessageType.UPDATE,
        event: {"oldGuid": oldGuid, "message": message},
      ),
    );
  }

  void addMessage(Chat chat, Message message, {bool outgoing = false}) {
    _stream.sink.add(
      NewMessageEvent(
        chatGuid: chat.guid,
        type: NewMessageType.ADD,
        event: {"message": message, "outgoing": outgoing, "chat": chat},
      ),
    );
  }

  dispose() {
    _stream.close();
  }
}
