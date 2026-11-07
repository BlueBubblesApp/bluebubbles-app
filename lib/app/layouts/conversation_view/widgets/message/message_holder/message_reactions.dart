import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

import 'message_holder_reactions.dart';

/// Consolidated widget for displaying reactions on a message part
/// Handles both isFromMe and !isFromMe cases
class MessageReactions extends StatelessWidget {
  const MessageReactions({
    super.key,
    required this.part,
    required this.chatGuid,
  });

  final MessagePart part;
  final String chatGuid;

  @override
  Widget build(BuildContext context) {
    return ReactionObserver(
      part: part,
      chatGuid: chatGuid,
    );
  }
}
