import 'dart:async';

import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:dio/dio.dart';

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

class MessageManager {
  factory MessageManager() {
    return _manager;
  }

  static final MessageManager _manager = MessageManager._internal();
  MessageManager._internal();

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

  Future<List<dynamic>> getMessages({
    bool withChats = false,
    bool withAttachments = false,
    bool withHandles = false,
    bool withChatParticipants = false,
    List<dynamic> where = const [],
    String sort = "DESC",
    int? before, int? after,
    String? chatGuid,
    int offset = 0, int limit = 100
  }) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>[];
    if (withChats) withQuery.add("chat");
    if (withAttachments) withQuery.add("attachment");
    if (withHandles) withQuery.add("handle");
    if (withChatParticipants) withQuery.add("chat.participants");

    await api.messages(withQuery: withQuery, where: where, sort: sort, before: before, after: after, chatGuid: chatGuid, offset: offset, limit: limit).then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err.toString();
      }
      if (!completer.isCompleted) completer.completeError(error);
    });

    return completer.future;
  }

  dispose() {
    _stream.close();
  }
}
