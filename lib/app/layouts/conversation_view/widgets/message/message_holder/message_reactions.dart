import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

import 'message_holder_reactions.dart';

/// Consolidated widget for displaying reactions on a message part
/// Handles both isFromMe and !isFromMe cases
class MessageReactions extends StatelessWidget {
  const MessageReactions({
    super.key,
    required this.messageParts,
    required this.part,
    required this.chatGuid,
    required this.reactionsForPart,
  });

  final List<MessagePart> messageParts;
  final MessagePart part;
  final String chatGuid;
  final Iterable<Message> Function(MessagePart, List<Message>) reactionsForPart;

  @override
  Widget build(BuildContext context) {
    return ReactionObserver(
      messageParts: messageParts,
      part: part,
      chatGuid: chatGuid,
      reactionsForPart: reactionsForPart,
    );
  }
}
