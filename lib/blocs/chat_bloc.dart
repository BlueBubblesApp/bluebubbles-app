import 'dart:async';
import 'dart:io';

import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../socket_manager.dart';
import '../repository/models/handle.dart';
import '../repository/models/chat.dart';
import '../helpers/utils.dart';

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

  List<Chat> _chats;
  List<Chat> get chats => _chats;
  Map<String, Map<String, dynamic>> _tileVals = new Map();
  Map<String, Map<String, dynamic>> get tileVals => _tileVals;

  factory ChatBloc() {
    return _chatBloc;
  }

  static final ChatBloc _chatBloc = ChatBloc._internal();

  ChatBloc._internal();

  Future<List<Chat>> getChats() async {
    //sink is a way of adding data reactively to the stream
    //by registering a new event
    _chats = await Chat.find();
    await initTileVals(_chats);
    NewMessageManager().stream.listen((event) async {
      debugPrint("updating chat tiles " + event.toString());
      if (event.keys.first != null) {
        //if there even is a chat specified in the newmessagemanager update
        for (int i = 0; i < _chats.length; i++) {
          if (_chats[i].guid == event.keys.first) {
            await initTileValsForChat(_chats[i],
                latestMessage: event.values.first);
          }
        }
      } else {
        await initTileVals(_chats);
      }
      _chatController.sink.add(_chats);
    });
    _chatController.sink.add(_chats);
    return _chats;
  }

  Future<List<Chat>> moveChatToTop(Chat chat) async {
    for (int i = 0; i < _chats.length; i++)
      if (_chats[i].guid == chat.guid) {
        _chats.removeAt(i);
        break;
      }

    _chats.insert(0, chat);
    await initTileValsForChat(chat);
    _chatController.sink.add(_chats);
    return _chats;
  }

  Future<void> initTileVals(List<Chat> chats) async {
    for (int i = 0; i < chats.length; i++) {
      Chat chat = chats[i];
      await initTileValsForChat(chat);
    }

    _tileValController.sink.add(_tileVals);
  }

  Future<void> initTileValsForChat(Chat chat, {Message latestMessage}) async {
    String title = await getFullChatTitle(chat);

    // if (!_tileVals.containsKey(chat.guid)) {

    Message firstMessage = latestMessage;
    if (latestMessage == null) {
      List<Message> messages = await Chat.getMessages(chat, limit: 1);
      firstMessage = messages.length > 0 ? messages[0] : null;
    }
    dynamic subtitle = "";
    String date = "";

    if (firstMessage != null) {
      subtitle = firstMessage.text;
      if (firstMessage.hasAttachments) {
        List<Attachment> attachments =
            await Message.getAttachments(firstMessage);

        // When there is an attachment,the text length  1
        if (subtitle.length == 1 && attachments.length > 0) {
          String appDocPath = SettingsManager().appDocDir.path;
          String pathName =
              "$appDocPath/attachments/${attachments[0].guid}/${attachments[0].transferName}";

          if (FileSystemEntity.typeSync(pathName) !=
                  FileSystemEntityType.notFound &&
              attachments[0].mimeType.startsWith("image/")) {
            // We need a row here so the parent honors our clipping
            subtitle = Container(
                padding: EdgeInsets.only(top: 2),
                child: Row(children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(File(pathName),
                        alignment: Alignment.centerLeft, height: 38),
                  )
                ]));
          } else {
            subtitle = "${attachments.length} Attachment";
            if (attachments.length > 1) subtitle += "s";
          }
        }
      }

      if (firstMessage.dateCreated.isToday()) {
        date = new DateFormat.jm().format(firstMessage.dateCreated);
      } else if (firstMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${firstMessage.dateCreated.month.toString()}/${firstMessage.dateCreated.day.toString()}/${firstMessage.dateCreated.year.toString()}";
      }
    }

    Map<String, dynamic> chatMap = _tileVals[chat.guid] ?? {};
    chatMap["title"] = title;
    chatMap["subtitle"] = subtitle;
    chatMap["date"] = date;
    chatMap["actualDate"] = firstMessage != null
        ? firstMessage.dateCreated.millisecondsSinceEpoch
        : 0;
    bool hasNotification = false;

    for (int i = 0; i < SocketManager().chatsWithNotifications.length; i++) {
      if (SocketManager().chatsWithNotifications[i] == chat.guid) {
        hasNotification = true;
        break;
      }
    }

    chatMap["hasNotification"] = hasNotification;

    updateTileVals(chat, chatMap);
    _tileValController.sink.add(_tileVals);
    // }
  }

  void updateTileVals(Chat chat, Map<String, dynamic> chatMap) {
    if (_tileVals.containsKey(chat.guid)) {
      _tileVals.remove(chat.guid);
    }
    _tileVals[chat.guid] = chatMap;
  }

  addChat(Chat chat) async {
    // Create the chat in the database
    await chat.save();
    getChats();
  }

  udpateChat(Chat chat) async {
    // Create the chat in the database
    await chat.update();
    getChats();
  }

  addParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.addParticipant(participant);
    getChats();
  }

  removeParticipant(Chat chat, Handle participant) async {
    // Add the participant to the chat
    await chat.removeParticipant(participant);
    chat.participants.remove(participant);
    getChats();
  }

  dispose() {
    // _chatController.close();
  }
}
