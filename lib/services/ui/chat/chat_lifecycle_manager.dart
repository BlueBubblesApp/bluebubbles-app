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
      // listen for contacts update (this listens for all chats)
      eventDispatcher.stream.listen((event) {
        if (event.item1 != 'update-contacts') return;
        if (event.item2.isNotEmpty) {
          for (Handle h in chat.participants) {
            if (event.item2.first.contains(h.contactRelation.targetId)) {
              final contact = contactBox.get(h.contactRelation.targetId);
              h.contactRelation.target = contact;
            }
            if (event.item2.last.contains(h.id)) {
              h = handleBox.get(h.id!)!;
            }
          }
          chats.updateChat(chat, override: true);
        }
      });
    }
  }
}
