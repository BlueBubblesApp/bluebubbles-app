import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/attachment_info_bloc.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

import '../repository/models/handle.dart';
import '../repository/models/chat.dart';

class ChatBloc {
  // Stream controller is the 'Admin' that manages
  // the state of our stream of data like adding
  // new data, change the state of the stream
  // and broadcast it to observers/subscribers
  final _chatController = StreamController<List<Chat>>.broadcast();
  final _tileValController =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();

  Stream<List<Chat>> get chatStream => _chatController.stream;
  Stream<Map<String, Map<String, dynamic>>> get tileStream =>
      _tileValController.stream;

  final _archivedChatController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get archivedChatStream => _archivedChatController.stream;

  static StreamSubscription<NewMessageEvent> _messageSubscription;

  List<Chat> _chats;
  List<Chat> get chats => _chats;
  List<Chat> _archivedChats;
  List<Chat> get archivedChats => _archivedChats;

  static final ChatBloc _chatBloc = ChatBloc._internal();
  ChatBloc._internal();

  factory ChatBloc() {
    return _chatBloc;
  }

  Future<Chat> getChat(String guid) async {
    if (guid == null) return null;
    if (_chats == null) {
      await this.refreshChats();
    }

    for (Chat chat in _chats) {
      if (chat.guid == guid) return chat;
    }

    return null;
  }

  Future<void> refreshChats() async {
    _chats = [];
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
    await this.addToSink(_chats);
  }

  /// Inserts a [chat] into the chat bloc based on the lastMessage data
  Future<void> updateChatPosition(Chat chat) async {
    if (chat == null) return;
    if (isNullOrEmpty(_chats)) {
      await this.refreshChats();
    }

    int currentIndex = -1;
    bool shouldUpdate = true;

    // Get the current index of the chat, (if there),
    // and figure out if we need to update the chat.
    for (int i = 0; i < _chats.length; i++) {
      // Skip over non-matching chats
      if (_chats[i].guid != chat.guid) continue;

      // Don't move/update the chat if the latest message for it is newer than the incoming one
      int latest = chat.latestMessageDate != null
          ? chat.latestMessageDate.millisecondsSinceEpoch
          : 0;
      if (_chats[i].latestMessageDate != null &&
              _chats[i].latestMessageDate.millisecondsSinceEpoch > latest ??
          0) {
        shouldUpdate = false;
      }

      // Save the current index and break out of the loop
      currentIndex = i;
      break;
    }

    // If we shouldn't update the bloc because the message is older, return here
    if (!shouldUpdate) return;

    if (isNullOrEmpty(chat.title)) {
      await chat.getTitle();
    }

    // If the current chat isn't found in the bloc, let's insert it at the correct position
    if (currentIndex == -1) {
      for (int i = 0; i < _chats.length; i++) {
        // If the chat is older, that's where we want to insert
        if (_chats[i].latestMessageDate == null ||
                chat.latestMessageDate == null ||
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
    await this.addToSink(_chats);

    await updateShareTargets();
  }

  Future<void> updateShareTargets() async {
    debugPrint("Pushing share targets");

    List<String> names = [];
    List<String> addresses = [];
    List<Uint8List> icons = [];

    List<Chat> chats =
        _chats.where((element) => element.participants.length == 1).toList();
    chats.sort((a, b) {
      if (!a.isPinned && b.isPinned) return 1;
      if (a.isPinned && !b.isPinned) return -1;
      if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
      if (a.latestMessageDate == null) return 1;
      if (b.latestMessageDate == null) return -1;
      return -a.latestMessageDate.compareTo(b.latestMessageDate);
    });

    for (int i = 0; i < 4; i++) {
      if (i >= chats.length) break;
      if (chats[i].participants.length > 1) continue;
      String handleAddress = chats[i].participants.first.address;
      String contactTitle =
          await ContactManager().getContactTitle(handleAddress);
      Contact contact = await ContactManager().getCachedContact(handleAddress);
      names.add(contactTitle);
      addresses.add(handleAddress);
      Uint8List contactIcon;
      try {
        // If there is a contact specified, we can use it's avatar
        if (contact != null && contact.avatar.isNotEmpty) {
          contactIcon = contact.avatar;
          // Otherwise if there isn't, we use the [defaultAvatar]
        } else {
          // If [defaultAvatar] is not loaded, load it from assets
          if (NotificationManager().defaultAvatar == null) {
            ByteData file = await loadAsset("assets/images/person.png");
            NotificationManager().defaultAvatar = file.buffer.asUint8List();
          }

          contactIcon = NotificationManager().defaultAvatar;
        }
      } catch (ex) {
        debugPrint("Failed to load contact avatar: ${ex.toString()}");
      }
      icons.add(contactIcon);
    }

    await MethodChannelInterface().invokeMethod("push-share-targets", {
      "names": names,
      "addresses": addresses,
      "icons": icons,
    });
  }

  Future<void> handleMessageAction(NewMessageEvent event) async {
    // Only handle the "add" action right now
    if (event.type == NewMessageType.ADD) {
      // Find the chat to update
      Chat updatedChat = event.event["chat"];

      // Update the tile values for the chat (basically just the title)
      await initTileValsForChat(updatedChat);

      // Insert/move the chat to the correct position
      await updateChatPosition(updatedChat);
    }
  }

  StreamSubscription<NewMessageEvent> setupMessageListener() {
    // Listen for new messages
    return NewMessageManager().stream.listen(handleMessageAction);
  }

  void recursiveGetChats() async {
    // Get more chats
    int len = _chats.length;
    List<Chat> newChats = await Chat.getChats(limit: 10, offset: _chats.length);

    // If there were indeed results, then continue
    if (newChats.length != 0) {
      // Check to see if the chat already exists in the list
      // If so, don't add it
      // Otherwise add it and initialize it's values
      for (Chat newChat in newChats) {
        bool existingChat = false;
        for (Chat chat in _chats) {
          if (chat.guid == newChat.guid) {
            existingChat = true;
            break;
          }
        }

        if (existingChat) continue;
        _chats.add(newChat);
        await initTileValsForChat(newChat);
      }

      // Only keep going if the last request added new chats
      if (_chats.length > len) {
        await this.addToSink(_chats);
        recursiveGetChats();
      } else {
        await updateShareTargets();
      }
    } else {
      await updateShareTargets();
    }
  }

  /// Used to initialize all the values of the set List of [chat]s
  /// @param chats list of chats to initialize values for
  /// @param addToSink optional param whether to update the stream after initalizing all the values of the chat, defaults to true
  Future<void> initTileVals(List<Chat> chats, [bool addToSink = true]) async {
    for (int i = 0; i < chats.length; i++) {
      await initTileValsForChat(chats[i]);
    }

    if (addToSink) {
      await this.addToSink(_chats);
    }
  }

  /// Get the values for the chat, specifically the title
  /// @param chat to initialize
  Future<void> initTileValsForChat(Chat chat) async {
    if (chat.title == null) {
      await chat.getTitle();
    }
    AttachmentInfoBloc().initChat(chat);
  }

  void archiveChat(Chat chat) async {
    _chats.removeWhere((element) => element.guid == chat.guid);
    _archivedChats.add(chat);
    chat.isArchived = true;
    await chat.save(updateLocalVals: true);
    initTileValsForChat(chat);
    await this.addToSink(_chats);
    _archivedChatController.sink.add(_archivedChats);
  }

  void unArchiveChat(Chat chat) async {
    _archivedChats.removeWhere((element) => element.guid == chat.guid);
    chat.isArchived = false;
    await chat.save(updateLocalVals: true);
    await initTileValsForChat(chat);
    _chats.add(chat);
    _archivedChatController.sink.add(_archivedChats);
    await this.addToSink(_chats);
  }

  void deleteChat(Chat chat) async {
    _archivedChats.removeWhere((element) => element.id == chat.id);
    _chats.removeWhere((element) => element.id == chat.id);
    _archivedChatController.sink.add(_archivedChats);
    await this.addToSink(_chats);
  }

  void updateTileVals(Chat chat, Map<String, dynamic> chatMap,
      Map<String, Map<String, dynamic>> map) {
    if (map.containsKey(chat.guid)) {
      map.remove(chat.guid);
    }
    map[chat.guid] = chatMap;
  }

  void updateChat(Chat chat) async {
    if (_chats == null) await refreshChats();

    for (int i = 0; i < _chats.length; i++) {
      Chat _chat = _chats[i];
      if (_chat.guid == chat.guid) {
        _chats[i] = chat;
        await initTileValsForChat(chats[i]);
      }
    }

    await this.addToSink(_chats);
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

  Future<void> addToSink(List<Chat> chats) async {
    for (int i = 0; i < chats.length; i++) {
      if (isNullOrEmpty(chats[i].participants)) {
        await chats[i].getParticipants();
      }
    }

    _chatController.sink.add(chats);
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
