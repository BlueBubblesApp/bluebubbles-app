import 'dart:async';
import 'dart:collection';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:get/get.dart';

import '../socket_manager.dart';

abstract class MessageBlocEventType {
  static String insert = "INSERT";
  static String update = "UPDATE";
  static String remove = "REMOVE";
  static String messageUpdate = "MESSAGEUPDATE";
}

class MessageBlocEvent {
  List<Message> messages = [];
  Message? message;
  String? remove;
  String? oldGuid;
  bool outGoing = false;
  int? index;
  String? type;
  Map<String, dynamic> data = {};
}

class MessageBloc {
  final Rxn<MessageBlocEvent> event = Rxn<MessageBlocEvent>();
  Map<String, Message> _allMessages = {};
  final Map<String, Message> _reactionMessages = {};
  final RxMap<String, String> threadOriginators = <String, String>{}.obs;
  int _reactions = 0;
  bool showDeleted = false;
  bool _canLoadMore = true;
  bool _isGettingMore = false;

  Map<String, Message> get messages {
    if (!showDeleted) {
      _allMessages.removeWhere((key, value) => value.dateDeleted != null);
    }

    return _allMessages;
  }

  Map<String, Message> get reactionMessages {
    if (!showDeleted) {
      _reactionMessages.removeWhere((key, value) => value.dateDeleted != null);
    }

    return _reactionMessages;
  }

  Chat? _currentChat;

  Chat? get currentChat => _currentChat;

  String? get firstSentMessage {
    for (Message message in _allMessages.values) {
      if (message.isFromMe!) {
        return message.guid;
      }
    }
    return "no sent message found";
  }

  MessageBloc(Chat? chat, {bool canLoadMore = true}) {
    _canLoadMore = canLoadMore;
    _currentChat = chat;

    NewMessageManager().stream.listen((msgEvent) {
      // Ignore any events that don't have to do with the current chat
      if (msgEvent.chatGuid != currentChat?.guid) return;

      // Iterate over each action that needs to take place on the chat
      bool addToRx = true;
      MessageBlocEvent baseEvent = MessageBlocEvent();

      // If we want to remove something, set the event data correctly
      if (msgEvent.type == NewMessageType.REMOVE && _allMessages.containsKey(msgEvent.event["guid"])) {
        _allMessages.remove(msgEvent.event["guid"]);
        baseEvent.remove = msgEvent.event["guid"];
        baseEvent.type = MessageBlocEventType.remove;
      } else if (msgEvent.type == NewMessageType.UPDATE && _allMessages.containsKey(msgEvent.event["oldGuid"])) {
        // If we want to updating an existing message, remove the old one, and add the new one
        _allMessages.remove(msgEvent.event["oldGuid"]);
        insert(msgEvent.event["message"], msgEvent.event, addToRx: false);
        baseEvent.message = msgEvent.event["message"];
        baseEvent.oldGuid = msgEvent.event["oldGuid"];
        baseEvent.type = MessageBlocEventType.update;
      } else if (msgEvent.type == NewMessageType.ADD) {
        // If we want to add a message, just add it through `insert`
        addToRx = false;
        insert(msgEvent.event["message"], msgEvent.event, sentFromThisClient: msgEvent.event["outgoing"]);
        baseEvent.message = msgEvent.event["message"];
        baseEvent.type = MessageBlocEventType.insert;
      }

      // As long as the controller isn't closed and it's not an `add`, update the listeners
      if (addToRx) {
        baseEvent.messages = _allMessages.values.toList();
        baseEvent.data = msgEvent.event;
        event.value = baseEvent;
      }
    });
  }

  void insert(Message message, Map<String, dynamic> data, {bool sentFromThisClient = false, bool addToRx = true}) {
    if (message.associatedMessageGuid != null) {
      if (_allMessages.containsKey(message.associatedMessageGuid)) {
        Message messageWithReaction = _allMessages[message.associatedMessageGuid]!;
        messageWithReaction.hasReactions = true;
        _allMessages.update(message.associatedMessageGuid!, (value) => messageWithReaction);
        if (addToRx) {
          MessageBlocEvent mbEvent = MessageBlocEvent();
          mbEvent.messages = _allMessages.values.toList();
          mbEvent.oldGuid = message.associatedMessageGuid;
          mbEvent.message = _allMessages[message.associatedMessageGuid];
          mbEvent.type = MessageBlocEventType.update;
          mbEvent.data = data;
          event.value = mbEvent;
        }
      }
      return;
    }

    int index = 0;
    if (_allMessages.isEmpty && message.guid != null) {
      _allMessages.addAll({message.guid!: message});
      if (addToRx) {
        MessageBlocEvent mbEvent = MessageBlocEvent();
        mbEvent.messages = _allMessages.values.toList();
        mbEvent.message = message;
        mbEvent.outGoing = sentFromThisClient;
        mbEvent.type = MessageBlocEventType.insert;
        mbEvent.index = index;
        mbEvent.data = data;
        event.value = mbEvent;
      }

      return;
    }

    if (sentFromThisClient && message.guid != null) {
      _allMessages = linkedHashMapInsert<String, Message>(_allMessages, 0, message.guid!, message);
    } else {
      List<Message?> messages = _allMessages.values.toList();
      for (int i = 0; i < messages.length; i++) {
        //if _allMessages[i] dateCreated is earlier than the new message, insert at that index
        if (message.guid != null &&
                (messages[i]!.originalROWID != null &&
                    message.originalROWID != null &&
                    message.originalROWID! > messages[i]!.originalROWID!) ||
            ((messages[i]!.originalROWID == null || message.originalROWID == null) &&
                messages[i]!.dateCreated!.compareTo(message.dateCreated!) < 0)) {
          _allMessages = linkedHashMapInsert<String, Message>(_allMessages, i, message.guid!, message);
          index = i;

          break;
        }
      }
    }

    if (addToRx) {
      MessageBlocEvent mbEvent = MessageBlocEvent();
      mbEvent.messages = _allMessages.values.toList();
      mbEvent.message = message;
      mbEvent.outGoing = sentFromThisClient;
      mbEvent.type = MessageBlocEventType.insert;
      mbEvent.index = index;
      mbEvent.data = data;
      event.value = mbEvent;
    }
  }

  void addMessage(Message m) {
    _allMessages[m.guid!] = m;
  }

  LinkedHashMap<M, N> linkedHashMapInsert<M, N>(map, int index, M key, N value) {
    List<M> keys = map.keys.toList();
    List<N> values = map.values.toList();
    keys.insert(index, key);
    values.insert(index, value);

    return LinkedHashMap<M, N>.from(LinkedHashMap.fromIterables(keys, values));
  }

  void emitLoaded() {
    MessageBlocEvent mbEvent = MessageBlocEvent();
    mbEvent.messages = _allMessages.values.toList();
    event.value = mbEvent;
  }

  Future<Map<String, Message>> getMessages() async {
    // If we are already fetching, return empty
    if (_isGettingMore || !_canLoadMore) return {};
    _isGettingMore = true;

    // Fetch messages
    List<Message> messages = await Chat.getMessagesAsync(_currentChat!);

    if (isNullOrEmpty(messages)!) {
      _allMessages = {};
    } else {
      for (var element in messages) {
        if (element.associatedMessageGuid == null && element.guid != null) {
          _allMessages.addAll({element.guid!: element});
        } else {
          _reactionMessages.addAll({element.guid!: element});
          _reactions++;
        }
      }
    }

    emitLoaded();

    _isGettingMore = false;
    return _allMessages;
  }

  Future<void> loadSearchChunk(Message message) async {
    // List<int> rowIDs = [message.originalROWID + 1];
    // if (message.originalROWID - 1 > 0) {
    //   rowIDs.add(message.originalROWID - 1);
    // }

    // List<Map<String, dynamic>> params = [
    //   {"statement": "message.ROWID IN (${rowIDs.join(", ")})", 'args': null},
    //   {"statement": "message.associated_message_guid IS NULL", 'args': null}
    // ];

    // List<dynamic> res =
    //     await SocketManager().fetchMessages(null, limit: 3, where: params);
    _allMessages = {};
    if (message.guid != null) {
      _allMessages.addAll({message.guid!: message});
    }

    // Logger.instance.log("ITEMS OG");
    // for (var i in _allMessages.values.toList()) {
    //   Logger.instance.log(i.guid);
    // }

    // for (var i in res ?? []) {
    //   Message tmp = Message.fromMap(i);
    //   Logger.instance.log("ADDING: ${tmp.guid}");
    //   if (!_allMessages.containsKey(tmp.guid)) {
    //     _allMessages.addAll({tmp.guid: message});
    //   }
    // }

    // Logger.instance.log("ITEMS AFTER");
    // for (var i in _allMessages.values.toList()) {
    //   Logger.instance.log("TEXT: ${i.text}");
    // }

    // Logger.instance.log(_allMessages.length);

    emitLoaded();
  }

  Future<LoadMessageResult> loadMessageChunk(int offset,
      {bool includeReactions = true, bool checkLocal = true, ChatController? currentChat}) async {
    int reactionCnt = includeReactions ? _reactions : 0;
    Completer<LoadMessageResult> completer = Completer();
    if (!_canLoadMore) {
      completer.complete(LoadMessageResult.RETREIVED_LAST_PAGE);
      return completer.future;
    }

    Chat? currChat = currentChat?.chat ?? _currentChat;

    if (currChat != null) {
      List<Message> messages = [];
      int count = 0;

      // Should we check locally first?
      if (checkLocal) messages = await Chat.getMessagesAsync(currChat, offset: offset + reactionCnt);

      // Fetch messages from the socket
      count = messages.length;
      if (isNullOrEmpty(messages)!) {
        try {
          // Fetch messages from the server
          List<dynamic> _messages = await SocketManager().loadMessageChunk(currChat, offset + reactionCnt);
          count = _messages.length;

          // Handle the messages
          if (isNullOrEmpty(_messages)!) {
            Logger.info("No message chunks left from server", tag: "MessageBloc");
            completer.complete(LoadMessageResult.RETREIVED_NO_MESSAGES);
          } else {
            Logger.info("Received ${_messages.length} messages from socket", tag: "MessageBloc");

            messages = await MessageHelper.bulkAddMessages(_currentChat, _messages,
                notifyMessageManager: false, notifyForNewMessage: false, checkForLatestMessageText: false);

            // If the handle is empty, load it
            for (Message msg in messages) {
              if (msg.isFromMe! || msg.handle != null) continue;
              msg.handle = msg.getHandle();
            }
          }
        } catch (ex) {
          Logger.error("Failed to load message chunk!", tag: "MessageBloc");
          Logger.error(ex.toString());
          completer.complete(LoadMessageResult.FAILED_TO_RETREIVE);
        }
      }

      // Save the messages to the bloc
      Logger.info("Emitting ${messages.length} messages to listeners", tag: "MessageBloc");
      for (Message element in messages) {
        if (element.associatedMessageGuid == null && element.guid != null) {
          _allMessages.addAll({element.guid!: element});
        } else {
          _reactionMessages.addAll({element.guid!: element});
          _reactions++;
        }
      }

      if (currentChat != null) {
        List<Message> messagesWithAttachment = messages.where((element) => element.hasAttachments).toList();
        await currentChat.preloadMessageAttachmentsAsync(specificMessages: messagesWithAttachment);
      }

      emitLoaded();

      // Complete the execution
      if (count < 25 && !completer.isCompleted) {
        completer.complete(LoadMessageResult.RETREIVED_LAST_PAGE);
      } else if (count >= 25 && !completer.isCompleted) {
        completer.complete(LoadMessageResult.RETREIVED_MESSAGES);
      }
    } else {
      Logger.error(" Failed to load message chunk! Unknown chat!", tag: "MessageBloc");
      completer.complete(LoadMessageResult.FAILED_TO_RETREIVE);
    }

    return completer.future;
  }

  Future<void> refresh() async {
    _allMessages = {};
    _reactionMessages.clear();
    _reactions = 0;

    await getMessages();
  }

  void dispose() {
    _allMessages = {};
  }
}

enum LoadMessageResult { RETREIVED_MESSAGES, RETREIVED_NO_MESSAGES, FAILED_TO_RETREIVE, RETREIVED_LAST_PAGE }
