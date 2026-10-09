import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_collage.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_grid.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_stack.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Renders the appropriate content widget based on message type
/// Extracted from MessageHolder to reduce nesting and improve readability
class MessagePartContent extends StatelessWidget {
  /// Author-side inset matching single attachments / [TailClipper].
  static const double _collectionEdgeInset = 10.0;

  const MessagePartContent({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
    this.canSwipeToReply = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  /// Passed through to collage for per-card swipe-to-reply (stack has no swipe).
  final bool canSwipeToReply;

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.messageOf(context);
    // Interactive messages (URL previews, GamePigeon, etc.)
    if (message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive) {
      // These checks are message-level, not part-level, but Apple's attributedBody
      // can split a single interactive balloon (e.g. a Photos share with its
      // underlying attachment) across multiple MessageParts. InteractiveHolder
      // already renders everything from message-level payloadData, so only the
      // first part should render it - other parts would otherwise duplicate the
      // widget (or, for an attachment part, risk falling through to
      // AttachmentHolder and auto-downloading media the interactive widget
      // intentionally avoids downloading).
      final parts = MessageStateScope.of(context).parts;
      final firstPart = parts.isEmpty ? messagePart.part : parts.map((p) => p.part).reduce((a, b) => a < b ? a : b);
      if (messagePart.part != firstPart) {
        return const SizedBox.shrink();
      }
      return InteractiveHolder(
        message: messagePart,
      );
    }

    // Text-only messages
    if (messagePart.attachments.isEmpty && (messagePart.text != null || messagePart.subject != null)) {
      return TextBubble(
        message: messagePart,
      );
    }

    // Messages with attachments
    if (messagePart.attachments.isNotEmpty) {
      if (messagePart.isMediaCollection) {
        final layout = resolveMediaCollectionLayout(messagePart.attachments.length);
        final Widget collection = switch (layout) {
          MediaCollectionLayout.collage => CollectionGroupCollage(
              messagePart: messagePart,
              cvController: cvController,
              isEditing: isEditing,
              canSwipeToReply: canSwipeToReply,
            ),
          MediaCollectionLayout.stack => CollectionGroupStack(
              messagePart: messagePart,
              cvController: cvController,
              isEditing: isEditing,
            ),
          MediaCollectionLayout.grid || MediaCollectionLayout.skinDefault => CollectionGroupGrid(
              messagePart: messagePart,
              cvController: cvController,
              isEditing: isEditing,
            ),
        };
        final isFromMe = message.isFromMe == true;
        return Padding(
          padding: EdgeInsets.only(
            left: isFromMe ? 0 : _collectionEdgeInset,
            right: isFromMe ? _collectionEdgeInset : 0,
          ),
          child: collection,
        );
      }
      return AttachmentHolder(
        message: messagePart,
      );
    }

    // Empty/unsupported message
    return const SizedBox.shrink();
  }
}
