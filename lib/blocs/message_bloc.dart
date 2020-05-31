import 'dart:async';

import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

import '../socket_manager.dart';

class MessageBloc {
  final _messageController = StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get stream => _messageController.stream;

  List<Message> _messageCache = <Message>[];

  List<Message> get messages => _messageCache;

  Chat _currentChat;

  MessageBloc(Chat chat) {
    _currentChat = chat;
    getMessages(chat);
    NewMessageManager().stream.listen((Map<String, Message> event) {
      if (event.containsKey(_currentChat.guid)) {
        if (event[_currentChat.guid] == null) {
          getMessages(chat);
        } else {
          _messageCache.add(event[_currentChat.guid]);
          _messageController.sink.add(_messageCache);
          getMessages(chat);
        }
      } else if (event.keys.first == null) {
        getMessages(_currentChat);
      }
    });
  }

  void getMessages(Chat chat) async {
    List<Message> messages = await Chat.getMessages(chat);
    messages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
    _messageCache = [];
    for (int i = 0; i < (messages.length <= 25 ? messages.length : 25); i++) {
      _messageCache.add(messages[i]);
    }
    _messageController.sink.add(messages);
  }

  void dispose() {
    // _messageController.close();
    // Singleton().unsubscribe(_currentChat.guid);
  }
}
