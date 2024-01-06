import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

class ChatLifecycleManager {
  late Chat chat;
  late final StreamSubscription sub;
  late final StreamSubscription sub2;

  bool isActive = false;
  bool isAlive = false;
  ConversationViewController? controller;

  ChatLifecycleManager(this.chat) {

    if (!kIsWeb && !ss.settings.turboMode.value) {
      final chatQuery = chatBox.query(Chat_.guid.equals(chat.guid)).watch();
      sub = chatQuery.listen((Query<Chat> query) async{
        if (ss.settings.turboMode.value) return;
        final _chat = await runAsync(() {
          return chatBox.get(chat.id!);
        });
        if (_chat != null) {
          bool shouldSort = false;
          if (_chat.dbOnlyLatestMessageDate != null && chat.dbOnlyLatestMessageDate != null) {
            shouldSort =
                chat.dbOnlyLatestMessageDate != _chat.dbOnlyLatestMessageDate;
          }
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
    } else {
      sub = WebListeners.chatUpdate.listen((_chat) {
        chats.updateChat(_chat, shouldSort: false);
        chat = _chat.merge(chat);
      });
      sub2 = WebListeners.newMessage.listen((tuple) {
        final message = tuple.item1;
        final _chat = tuple.item2;
        if (_chat?.guid == chat.guid &&
            (chat.latestMessage.dateCreated!.millisecondsSinceEpoch == 0 || message.dateCreated!.isAfter(chat.latestMessage.dateCreated!))) {
          chats.updateChat(_chat!, shouldSort: true);
          chat = _chat.merge(chat);
          chat.latestMessage = message;
        }
      });
    }
  }
}
