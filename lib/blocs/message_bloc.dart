import 'dart:async';
import 'dart:collection';

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
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
    NewMessageManager().stream.listen((msgEvent) {
      if (_messageController.isClosed) return;

      // Ignore any events that don't have to do with the current chat
      if (!msgEvent.containsKey(_currentChat.guid)) return;

      // Iterate over each action that needs to take place on the chat
      msgEvent[_currentChat.guid].forEach((actionType, actions) {
        for (Map<String, dynamic> action in actions) {
          bool addToSink = true;
          Map<String, dynamic> baseEvent = {
            "messages": null,
            "update": null,
            "index": null,
            "remove": null
          };

          // If we want to remove something, set the event data correctly
          if (actionType == NewMessageAction.REMOVE &&
              _allMessages.containsKey(action["guid"])) {
            _allMessages.remove(action["guid"]);
            baseEvent["remove"] = action["guid"];
          } else if (actionType == NewMessageAction.UPDATE &&
              _allMessages.containsKey(action["oldGuid"])) {
            
            // If we want to updating an existing message, remove the old one, and add the new one
            _allMessages.remove(action["oldGuid"]);
            insert(action["message"], addToSink: false);
            baseEvent["update"] = action["message"];
            baseEvent["oldGuid"] = action["oldGuid"];
          } else if (actionType == NewMessageAction.ADD) {
            // If we want to add a message, just add it through `insert`
            addToSink = false;
            insert(action["message"], sentFromThisClient: action["outgoing"]);
          }

          // As long as the controller isn't closed and it's not an `add`, update the listeners
          if (addToSink && !_messageController.isClosed) {
            baseEvent["messages"] = _allMessages;
            _messageController.sink.add(baseEvent);
          }
        }
      });
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

    if (sentFromThisClient) {
      _allMessages =
          linkedHashMapInsert(_allMessages, 0, message.guid, message);
    } else {
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
    }

    if (!_messageController.isClosed && addToSink) {
      _messageController.sink.add({
        "messages": _allMessages,
        "insert": message,
        "index": index,
        "sentFromThisClient": sentFromThisClient
      });
    }
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

  Future loadMessageChunk(int offset, {includeReactions = true}) async {
    int reactionCnt = includeReactions ? _reactions : 0;
    Completer completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages =
          await Chat.getMessages(_currentChat, offset: offset + reactionCnt);

      if (messages.length == 0) {
        Map<String, dynamic> params = Map();
        params["identifier"] = _currentChat.guid;
        params["limit"] = 25;
        params["offset"] = offset + reactionCnt;
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
