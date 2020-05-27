import 'dart:async';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

import '../../singleton.dart';

class MessageBloc {
  final _messageController = StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get stream => _messageController.stream;

  Chat _currentChat;

  MessageBloc(Chat chat) {
    _currentChat = chat;
    getMessages(chat);
    Singleton().subscribe(_currentChat.guid, () {
      getMessages(_currentChat);
    });
  }

  void getMessages(Chat chat) async {
    List<Message> messages = await Chat.getMessages(chat);
    messages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
    _messageController.sink.add(messages);
  }

  void dispose() {
    // _messageController.close();
    // Singleton().unsubscribe(_currentChat.guid);
  }
}
