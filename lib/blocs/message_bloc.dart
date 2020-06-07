import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

import '../socket_manager.dart';

class MessageBloc {
  final _messageController = StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get stream => _messageController.stream;

  List<Message> _messageCache = <Message>[];
  List<Message> _allMessages = <Message>[];

  Map<String, List<Message>> _reactions = new Map();

  List<Message> get messages =>
      _allMessages.length > 0 ? _allMessages : _messageCache;

  Map<String, List<Message>> get reactions => _reactions;

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
    _allMessages = messages;
    _messageCache = [];
    for (int i = 0; i < (messages.length <= 25 ? messages.length : 25); i++) {
      _messageCache.add(messages[i]);
    }
    _messageController.sink.add(messages);
    await getReactions(0);
  }

  Future loadMessageChunk(int offset) async {
    debugPrint("loading older messages");
    Completer completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages =
          await Chat.getMessages(_currentChat, offset: offset);
      if (messages.length == 0) {
        debugPrint("messages length is 0, fetching from server");
        Map<String, dynamic> params = Map();
        params["identifier"] = _currentChat.guid;
        params["limit"] = 100;
        params["offset"] = offset;

        SocketManager()
            .socket
            .sendMessage("get-chat-messages", jsonEncode(params), (data) async {
          List messages = jsonDecode(data)["data"];
          if (messages.length == 0) {
            completer.complete();
            return;
          }
          debugPrint("got messages");
          List<Message> _messages =
              await MessageHelper.bulkAddMessages(_currentChat, messages);
          _allMessages.addAll(_messages);
          _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
          _messageController.sink.add(_allMessages);
          completer.complete();
          await getReactions(offset);
        });
      } else {
        // debugPrint("loading more messages from sql " +);
        _allMessages.addAll(messages);
        _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
        _messageController.sink.add(_allMessages);
        completer.complete();
        await getReactions(offset);
      }
    } else {
      completer.completeError("chat not found");
    }
    return completer.future;
  }

  Future<void> getReactions(int offset) async {
    List<Message> reactionsResult = await Chat.getMessages(_currentChat,
        reactionsOnly: true, offset: offset);
    _reactions = new Map();
    reactionsResult.forEach((element) {
      if (element.associatedMessageGuid != null) {
        // debugPrint(element.handle.toString());
        String guid = element.associatedMessageGuid
            .substring(element.associatedMessageGuid.indexOf("/") + 1);

        if (!_reactions.containsKey(guid)) _reactions[guid] = <Message>[];
        _reactions[guid].add(element);
      }
    });
    _messageController.sink.add(_allMessages);
  }

  void dispose() {
    _allMessages = <Message>[];
  }
}
