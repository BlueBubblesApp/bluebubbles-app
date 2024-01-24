import 'dart:async';

import 'package:bluebubbles/models/models.dart';

enum QueueType {newMessage, updatedMessage, sendMessage, sendAttachment}

abstract class QueueItem {
  QueueType type;
  Completer<void>? completer;

  QueueItem({required this.type, this.completer});
}

class IncomingItem extends QueueItem {
  Chat chat;
  Message message;
  String? tempGuid;

  IncomingItem._({
    required super.type,
    super.completer,
    required this.chat,
    required this.message,
    this.tempGuid,
  });

  factory IncomingItem.fromMap(QueueType t, Map<String, dynamic> m, [Completer<void>? c]) {
    return IncomingItem._(
      type: t,
      completer: c,
      chat: Chat.fromMap(m['chats'].first.cast<String, Object>()),
      message: Message.fromMap(m),
      tempGuid: m['tempGuid'],
    );
  }
}

class OutgoingItem extends QueueItem {
  Chat chat;
  Message message;
  Message? selected;
  String? reaction;
  Map<String, dynamic>? customArgs;

  OutgoingItem({
    required super.type,
    super.completer,
    required this.chat,
    required this.message,
    this.selected,
    this.reaction,
    this.customArgs,
  });
}