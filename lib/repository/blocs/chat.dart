import 'dart:async';

import '../models/handle.dart';
import '../models/chat.dart';

class ChatBloc {
  //Stream controller is the 'Admin' that manages
  //the state of our stream of data like adding
  //new data, change the state of the stream
  //and broadcast it to observers/subscribers
  final _chatController = StreamController<List<Chat>>.broadcast();

  get todos => _chatController.stream;

  ChatBloc() {
    getChats();
  }

  getChats() async {
    //sink is a way of adding data reactively to the stream
    //by registering a new event
    _chatController.sink.add(await Chat.find());
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
      await participant.addToChat(chat);
      chat.participants.add(participant);
      getChats();
  }

  removeParticipant(Chat chat, Handle participant) async {
      // Add the participant to the chat
      await chat.removeParticipant(participant);
      chat.participants.remove(participant);
      getChats();
  }

  dispose() {
    _chatController.close();
  }
}
