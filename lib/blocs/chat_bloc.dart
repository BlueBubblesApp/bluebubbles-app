import 'dart:async';

import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

import '../repository/models/handle.dart';
import '../repository/models/chat.dart';

class ChatBloc {
  //Stream controller is the 'Admin' that manages
  //the state of our stream of data like adding
  //new data, change the state of the stream
  //and broadcast it to observers/subscribers
  final _chatController = StreamController<List<Chat>>.broadcast();
  final _tileValController =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();

  Stream<List<Chat>> get chatStream => _chatController.stream;
  Stream<Map<String, Map<String, dynamic>>> get tileStream =>
      _tileValController.stream;

  final _archivedChatController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get archivedChatStream => _archivedChatController.stream;

  static StreamSubscription<Map<String, dynamic>> _messageSubscription;

  List<Chat> _chats;
  List<Chat> get chats => _chats;
  List<Chat> _archivedChats;
  List<Chat> get archivedChats => _archivedChats;

  static final ChatBloc _chatBloc = ChatBloc._internal();
  ChatBloc._internal();

  factory ChatBloc() {
    return _chatBloc;
  }

  Chat getChat(String guid) {
    if (_chats == null) return null;
    for (Chat chat in _chats) {
      if (chat.guid == guid) return chat;
    }
    return null;
  }

  Future<void> refreshChats() async {
    debugPrint("[ChatBloc] -> Fetching chats...");

    // Get the contacts in case we haven't
    await ContactManager().getContacts();

    if (_messageSubscription == null) {
      _messageSubscription = setupMessageListener();
    }

    // Fetch the first 10 chats
    _chats = await Chat.getChats(archived: false, limit: 10);
    _archivedChats = await Chat.getChats(archived: true);

    // Invoke and wait for the tile's values to be generated
    await initTileVals(_chats);

    // We don't care much about the result of these, so call them async
    recursiveGetChats();
    initTileVals(_archivedChats);

    // Update the sink so all listeners get the new chat list
    _chatController.sink.add(_chats);
  }

  /// Inserts a [chat] into the chat bloc based on the lastMessage data
  Future<void> updateChatPosition(Chat chat) async {
    int currentIndex = -1;
    bool shouldUpdate = true;

    // Get the current index of the chat, (if there),
    // and figure out if we need to update the chat.
    for (int i = 0; i < _chats.length; i++) {
      // Skip over non-matching chats
      if (_chats[i].guid != chat.guid) continue;

      // Don't move/update the chat if the latest message for it is newer than the incoming one
      int latest = chat.latestMessageDate != null ? chat.latestMessageDate.millisecondsSinceEpoch : 0;
      if (_chats[i].latestMessageDate != null &&
              _chats[i].latestMessageDate.millisecondsSinceEpoch >
                  latest ?? 0) {
        shouldUpdate = false;
      }

      // Save the current index and break out of the loop
      currentIndex = i;
      break;
    }

    // If we shouldn't update the bloc because the message is older, return here
    if (!shouldUpdate) return;

    if (chat.title == null || chat.title == "") {
      await chat.getTitle();
    }

    // If the current chat isn't found in the bloc, let's insert it at the correct position
    if (currentIndex == -1) {
      for (int i = 0; i < _chats.length; i++) {
        // If the chat is older, that's where we want to insert
        if (_chats[i].latestMessageDate == null ||
                _chats[i].latestMessageDate.millisecondsSinceEpoch <
                    chat.latestMessageDate.millisecondsSinceEpoch ??
            0) {
          _chats.insert(i, chat);
          break;
        }
      }
      // If we have the index, let's replace it in the chatbloc
    } else {
      _chats[currentIndex] = chat;
    }

    // Update the sink so all listeners get the new chat list
    _chatController.sink.add(_chats);
  }

  Future<void> handleMessageAction(
      String chatGuid, String actionType, Map<String, dynamic> action) async {
    // Only handle the "add" action right now
    if (actionType == NewMessageAction.ADD) {
      // Find the chat to update
      Chat updatedChat = action["chat"];
      Message newMessage = action["message"];

      // If the message is from "me", mark the chat as unread
      if (newMessage != null && newMessage.isFromMe) {
        await updatedChat.markReadUnread(false);
      }

      debugPrint("Updating CHAT");
      debugPrint(action["chat"].toString());

      // Update the tile values for the chat (basically just the title)
      await initTileValsForChat(updatedChat);

      // Insert/move the chat to the correct position
      await updateChatPosition(updatedChat);
    }
  }

  StreamSubscription<Map<String, dynamic>> setupMessageListener() {
    // Listen for new messages
    return NewMessageManager().stream.listen((msgEvent) {
      msgEvent.forEach((chatGuid, actionData) {
        actionData.forEach((actionType, actions) async {
          for (Map<String, dynamic> action in actions) {
            await handleMessageAction(chatGuid, actionType, action);
          }
        });
      });
    });
  }

  void recursiveGetChats() async {
    List<Chat> newChats = await Chat.getChats(limit: 10, offset: _chats.length);
    if (newChats.length != 0) {
      _chats.addAll(newChats);
      await initTileVals(newChats);
      recursiveGetChats();
    }
  }

  Future<void> initTileVals(List<Chat> chats, [bool addToSink = true]) async {
    for (int i = 0; i < chats.length; i++) {
      await initTileValsForChat(chats[i]);
    }

    if (addToSink) _chatController.sink.add(_chats);
  }

  Future<void> initTileValsForChat(Chat chat) async {
    if (chat.title == null) await chat.getTitle();
  }

  void archiveChat(Chat chat) async {
    _chats.removeWhere((element) => element.guid == chat.guid);
    _archivedChats.add(chat);
    chat.isArchived = true;
    await chat.save(updateLocalVals: true);
    initTileValsForChat(chat);
    _chatController.sink.add(_chats);
    _archivedChatController.sink.add(_archivedChats);
  }

  void unArchiveChat(Chat chat) async {
    _archivedChats.removeWhere((element) => element.guid == chat.guid);
    chat.isArchived = false;
    await chat.save(updateLocalVals: true);
    await initTileValsForChat(chat);
    _chats.add(chat);
    _archivedChatController.sink.add(_archivedChats);
    _chatController.sink.add(_chats);
  }

  void updateTileVals(Chat chat, Map<String, dynamic> chatMap,
      Map<String, Map<String, dynamic>> map) {
    if (map.containsKey(chat.guid)) {
      map.remove(chat.guid);
    }
    map[chat.guid] = chatMap;
  }

  void updateChat(Chat chat) {
    for (int i = 0; i < _chats.length; i++) {
      Chat _chat = _chats[i];
      if (_chat.guid == chat.guid) {
        _chats[i] = chat;
      }
    }
  }

  addChat(Chat chat) async {
    // Create the chat in the database
    await chat.save();
    refreshChats();
  }

  addParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.addParticipant(participant);
    refreshChats();
  }

  removeParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.removeParticipant(participant);
    chat.participants.remove(participant);
    refreshChats();
  }

  dispose() {
    _chatController.close();
    _tileValController.close();
    _archivedChatController.close();

    if (_messageSubscription != null) {
      _messageSubscription.cancel();
    }
  }
}
