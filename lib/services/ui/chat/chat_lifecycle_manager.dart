import 'dart:async';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

class ChatLifecycleManager {
  late Chat chat;
  late final StreamSubscription<Query<Chat>> sub;

  bool isActive = false;
  bool isAlive = false;

  ChatLifecycleManager(this.chat) {
    if (!kIsWeb) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) {
        final _chat = chatBox.get(chat.id!);
        if (_chat != null) {
          bool shouldSort = chat.latestMessageDate != _chat.latestMessageDate;
          chats.updateChat(_chat, shouldSort: shouldSort);
          chat = _chat.merge(chat);
        }
      });
    }
  }
}
