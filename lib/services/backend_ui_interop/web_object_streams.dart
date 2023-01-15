import 'dart:async';

import 'package:bluebubbles/models/html/chat.dart';
import 'package:bluebubbles/models/html/message.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

WebObjectStreams webStreams = Get.isRegistered<WebObjectStreams>() ? Get.find<WebObjectStreams>() : Get.put(WebObjectStreams());

class WebObjectStreams extends GetxService with WidgetsBindingObserver {
  final StreamController<List<Chat>> _chatStream = StreamController<List<Chat>>.broadcast();
  final StreamController<Tuple2<Message, Chat>> _newMessageStream = StreamController<Tuple2<Message, Chat>>.broadcast();
  final StreamController<Tuple3<Message, Chat, String>> _updatedMessageStream = StreamController<Tuple3<Message, Chat, String>>.broadcast();

  Stream<List<Chat>> get chat => _chatStream.stream;
  Stream<Tuple2<Message, Chat>> get newMessage => _newMessageStream.stream;
  Stream<Tuple3<Message, Chat, String>> get updatedMessage => _updatedMessageStream.stream;

  @override
  void onClose() {
    _newMessageStream.close();
    _chatStream.close();
    super.onClose();
  }

  void addChatUpdate(List<Chat> chats) {
    _chatStream.sink.add(chats);
  }

  void emitNewMessage(Message m, Chat c) {
    _newMessageStream.sink.add(Tuple2(m, c));
  }

  void emitUpdatedMessage(Message m, Chat c, String oldGuid) {
    _updatedMessageStream.sink.add(Tuple3(m, c, oldGuid));
  }
}
