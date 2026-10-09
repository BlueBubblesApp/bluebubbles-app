import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
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
  const MessagePartContent({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

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
      final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
      if (iOS && messagePart.isMediaCollection) {
        // Same 10px author-side inset single attachments get from TailClipper.
        final isFromMe = message.isFromMe == true;
        return Padding(
          padding: EdgeInsets.only(
            left: isFromMe ? 0 : 10,
            right: isFromMe ? 10 : 0,
          ),
          child: CollectionGroupStack(
            messagePart: messagePart,
            cvController: cvController,
            isEditing: isEditing,
          ),
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
