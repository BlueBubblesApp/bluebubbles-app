import 'dart:async';

import 'package:bluebubbles/app/widgets/components/reaction.dart';

import 'models.dart';

enum QueueType {newMessage, updatedMessage, sendMessage, sendAttachment}

abstract class QueueItem {
  QueueType type;
  Completer<void>? completer;

  QueueItem({required this.type, this.completer});
}

class IncomingItem extends QueueItem {
  Message? message;

  IncomingItem._({
    required QueueType type,
    Completer<void>? completer,
    this.message,
  }) : super(type: type, completer: completer);

  factory IncomingItem.fromMap(QueueType t, Map<String, dynamic> m, [Completer<void>? c]) {
    return IncomingItem._(
      type: t,
      completer: c,
      message: Message.fromMap(m),
    );
  }
}

class OutgoingItem extends QueueItem {
  Chat chat;
  Message message;
  ReactionType? reaction;

  OutgoingItem({
    required QueueType type,
    Completer<void>? completer,
    required this.chat,
    required this.message,
    this.reaction,
  }) : super(type: type, completer: completer);
}