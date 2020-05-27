import 'dart:async';

import 'package:bluebubble_messages/repository/blocs/message_bloc.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../singleton.dart';
import '../models/handle.dart';
import '../models/chat.dart';
import '../../helpers/utils.dart';

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
  Map<String, Map<String, dynamic>> _tileVals = new Map();

  ChatBloc() {
    getChats();
  }

  void getChats() async {
    //sink is a way of adding data reactively to the stream
    //by registering a new event
    _chats = await Chat.find();
    initTileVals(_chats).then((value) {
      _chatController.sink.add(_chats);
    });
  }

  Future<void> initTileVals(List<Chat> chats) async {
    for (int i = 0; i < chats.length; i++) {
      Chat chat = chats[i];
      String title = await chatTitle(chat);
      if (title.substring(title.length - 2) == ", ")
        title = title.substring(0, title.length - 2);
      MessageBloc messageBloc;

      if (!_tileVals.containsKey(chat.guid)) {
        messageBloc = new MessageBloc(chat);
        messageBloc.stream.listen((List<Message> messages) async {
          if (messages.length > 0) {
            String subtitle = "";
            String date = "";

            Message firstMessage = messages.first;
            String text = firstMessage.text;
            if (firstMessage.hasAttachments) {
              List<Attachment> attachments = await Message.getAttachments(firstMessage);
              
              if (text.length == 0 && attachments.length > 0) {
                text = "${attachments.length} attachments";
              }
            }
            
            subtitle = text;

            Message lastMessage = messages.first;
            if (lastMessage.dateCreated.isToday()) {
              date = new DateFormat.jm().format(lastMessage.dateCreated);
            } else if (lastMessage.dateCreated.isYesterday()) {
              date = "Yesterday";
            } else {
              date =
                  "${lastMessage.dateCreated.month.toString()}/${lastMessage.dateCreated.day.toString()}/${lastMessage.dateCreated.year.toString()}";
            }
            Map<String, dynamic> chatMap = _tileVals[chat.guid];
            chatMap["subtitle"] = subtitle;
            chatMap["date"] = date;
            chatMap["actualDate"] =
                lastMessage.dateCreated.millisecondsSinceEpoch;
            bool hasNotification = false;

            for (int i = 0;
                i < Singleton().chatsWithNotifications.length;
                i++) {
              if (Singleton().chatsWithNotifications[i].guid == chat.guid) {
                hasNotification = true;
              }
            }
            chatMap["hasNotification"] = hasNotification;
            updateTileVals(chat, chatMap);
            _tileValController.add(_tileVals);
          }
        });
      } else {
        messageBloc = _tileVals[chat.guid]["bloc"];
      }

      bool hasNotification = false;

      for (int i = 0; i < Singleton().chatsWithNotifications.length; i++) {
        if (Singleton().chatsWithNotifications[i].guid == chat.guid) {
          hasNotification = true;
          break;
        }
      }

      Map<String, dynamic> chatMap = {
        "title": title,
        "subtitle": "",
        "date": "",
        "bloc": messageBloc,
        "actualDate": 0,
        "hasNotification": hasNotification,
      };
      updateTileVals(chat, chatMap);
    }
    _tileValController.sink.add(_tileVals);
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
