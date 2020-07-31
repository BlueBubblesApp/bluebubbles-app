import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../socket_manager.dart';

class MessageBloc {
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _messageController.stream;

  LinkedHashMap<String, Message> _allMessages = new LinkedHashMap();

  int _reactions = 0;

  LinkedHashMap<String, Message> get messages => _allMessages;

  Chat _currentChat;

  Chat get currentChat => _currentChat;

  String get firstSentMessage {
    for (Message message in _allMessages.values) {
      if (message.isFromMe) {
        return message.guid;
      }
    }
    return "no sent message found";
  }

  MessageBloc(Chat chat) {
    _currentChat = chat;
    NewMessageManager().stream.listen((Map<String, dynamic> event) {
      if (_messageController.isClosed) return;
      if (event.containsKey(_currentChat.guid)) {
        //if there even is a chat specified in the newmessagemanager update
        if (event[_currentChat.guid] == null) {
          if (event.containsKey("remove") && event["remove"] != null) {
            if (_allMessages.containsKey(event["remove"])) {
              _allMessages.remove(event["remove"]);
              if (!_messageController.isClosed)
                _messageController.sink.add({
                  "messages": _allMessages,
                  "update": event[_currentChat.guid],
                  "index": null,
                  "remove": event["remove"]
                });
            } else {
              debugPrint("could not remove message that does not exist");
            }
          } else {
            //if no message is specified in the newmessagemanager update
            getMessages();
          }
        } else {
          if (event.containsKey("oldGuid")) {
            if (_allMessages.containsKey(event["oldGuid"])) {
              // List<Message> values = _allMessages.values.toList();
              // List<String> keys = _allMessages.keys.toList();
              // for (int i = 0; i < keys.length; i++) {
              //   if (keys[i] == event["oldGuid"]) {
              //     keys[i] = (event[_currentChat.guid] as Message).guid;
              //     values[i] = event[_currentChat.guid];
              //     break;
              //   }
              // }
              _allMessages.remove(event["oldGuid"]);
              insert(event[_currentChat.guid], addToSink: false);
              // _allMessages = LinkedHashMap<String, Message>.from(
              //     LinkedHashMap.fromIterables(keys, values));
              if (!_messageController.isClosed)
                _messageController.sink.add({
                  "messages": _allMessages,
                  "update": event[_currentChat.guid],
                  "index": null,
                  "oldGuid": event["oldGuid"]
                });
            } else {
              debugPrint("could not find existing message");
            }
          } else {
            //if there is a specific message to insert
            insert(event[_currentChat.guid],
                sentFromThisClient: event.containsKey("sentFromThisClient")
                    ? event["sentFromThisClient"]
                    : false);
          }
        }
      } else if (event.keys.first == null) {
        //if there is no chat specified in the newmessagemanager update
        getMessages();
      }
    });
  }

  void insert(Message message,
      {bool sentFromThisClient = false, bool addToSink = true}) {
    if (message.associatedMessageGuid != null) {
      if (_allMessages.containsKey(message.associatedMessageGuid)) {
        Message messageWithReaction =
            _allMessages[message.associatedMessageGuid];
        messageWithReaction.hasReactions = true;
        _allMessages.update(
            message.associatedMessageGuid, (value) => messageWithReaction);
        if (addToSink)
          _messageController.sink.add({
            "messages": _allMessages,
            "update": _allMessages[message.associatedMessageGuid],
          });
      }
      return;
    }

    int index = 0;
    if (_allMessages.length == 0) {
      _allMessages.addAll({message.guid: message});
      if (!_messageController.isClosed && addToSink)
        _messageController.sink.add({
          "messages": _allMessages,
          "insert": message,
          "index": index,
          "sentFromThisClient": sentFromThisClient
        });
      return;
    }
    List<Message> messages = _allMessages.values.toList();
    for (int i = 0; i < messages.length; i++) {
      //if _allMessages[i] dateCreated is earlier than the new message, insert at that index
      if ((messages[i].originalROWID != null &&
              message.originalROWID != null &&
              message.originalROWID > messages[i].originalROWID) ||
          ((messages[i].originalROWID == null ||
                  message.originalROWID == null) &&
              messages[i].dateCreated.compareTo(message.dateCreated) < 0)) {
        _allMessages =
            linkedHashMapInsert(_allMessages, i, message.guid, message);
        index = i;

        break;
      }
    }
    if (!_messageController.isClosed && addToSink)
      _messageController.sink.add({
        "messages": _allMessages,
        "insert": message,
        "index": index,
        "sentFromThisClient": sentFromThisClient
      });
  }

  LinkedHashMap linkedHashMapInsert(map, int index, key, value) {
    List keys = map.keys.toList();
    List values = map.values.toList();
    keys.insert(index, key);
    values.insert(index, value);

    return LinkedHashMap<String, Message>.from(
        LinkedHashMap.fromIterables(keys, values));
  }

  Future<LinkedHashMap<String, Message>> getMessages() async {
    List<Message> messages = await Chat.getMessages(_currentChat);

    if (messages.length == 0) {
      _allMessages = new LinkedHashMap();
    } else {
      messages.forEach((element) {
        if (element.associatedMessageGuid == null) {
          _allMessages.addAll({element.guid: element});
        } else {
          _reactions++;
        }
      });
    }
    if (!_messageController.isClosed)
      _messageController.sink.add({"messages": _allMessages, "insert": null});
    return _allMessages;
  }

  Future loadMessageChunk(int offset) async {
    Completer completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages =
          await Chat.getMessages(_currentChat, offset: offset + _reactions);
      if (messages.length == 0) {
        Map<String, dynamic> params = Map();
        params["identifier"] = _currentChat.guid;
        params["limit"] = 25;
        params["offset"] = offset + _reactions;
        params["withBlurhash"] = false;
        params["where"] = [
          {"statement": "message.service = 'iMessage'", "args": null}
        ];

        SocketManager().sendMessage("get-chat-messages", params, (data) async {
          if (data['status'] != 200) {
            completer.complete();
            return;
          }
          List messages = data["data"];
          if (messages.length == 0) {
            completer.complete();
            return;
          }

          List<Message> _messages =
              await MessageHelper.bulkAddMessages(_currentChat, messages);
          _messages.forEach((element) {
            if (element.associatedMessageGuid == null) {
              _allMessages.addAll({element.guid: element});
            } else {
              _reactions++;
            }
          });
          if (!_messageController.isClosed) {
            _messageController.sink
                .add({"messages": _allMessages, "insert": null});
            completer.complete();
          } else {
            debugPrint("message controller closed");
          }
        });
      } else {
        messages.forEach((element) {
          if (element.associatedMessageGuid == null) {
            _allMessages.addAll({element.guid: element});
          } else {
            _reactions++;
          }
        });
        if (!_messageController.isClosed) {
          _messageController.sink
              .add({"messages": _allMessages, "insert": null});
          completer.complete();
        }
      }
    } else {
      debugPrint("failed to load ");
      completer.completeError("chat not found");
    }
    return completer.future;
  }

  void dispose() {
    _allMessages = new LinkedHashMap();
    _messageController.close();
  }
}
