import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

class ChatLifecycleManager {
  late Chat chat;
  late final StreamSubscription<Query<Chat>> sub;

  bool isActive = false;
  bool isAlive = false;
  ConversationViewController? controller;

  ChatLifecycleManager(this.chat) {
    if (!kIsWeb) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) async{
        final _chat = await runAsync(() {
          return chatBox.get(chat.id!);
        });
        if (_chat != null) {
          bool shouldSort = chat.latestMessage.dateCreated != _chat.latestMessage.dateCreated;
          chats.updateChat(_chat, shouldSort: shouldSort);
          chat = _chat.merge(chat);
        }
      });
    }
  }
}
