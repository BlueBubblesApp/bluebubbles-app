import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_collage.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_grid.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_group_stack.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_layout_metrics.dart';
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
    this.isEditing = false,
    this.galleryCurrentIndexNotifier,
    this.canSwipeToReply = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;
  final ValueNotifier<int>? galleryCurrentIndexNotifier;
  final bool canSwipeToReply;

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.messageOf(context);
    // Interactive messages (URL previews, GamePigeon, etc.)
    if (message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive) {
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
      if (messagePart.isMediaGallery) {
        final layout = resolveMediaCollectionLayout(messagePart.attachments.length);
        final isFromMe = message.isFromMe == true;
        final fanDirection = isFromMe ? GalleryFanDirection.right : GalleryFanDirection.left;
        final Widget gallery;
        switch (layout) {
          case MediaCollectionLayout.collage:
            gallery = CollectionGroupCollage(
              messagePart: messagePart,
              cvController: cvController,
              isEditing: isEditing,
              fanDirection: fanDirection,
              canSwipeToReply: canSwipeToReply,
            );
          case MediaCollectionLayout.stack:
            gallery = CollectionGroupStack(
              messagePart: messagePart,
              cvController: cvController,
              isInReply: false,
              fanDirection: fanDirection,
              isEditing: isEditing,
              currentIndexNotifier: galleryCurrentIndexNotifier,
            );
          case MediaCollectionLayout.grid:
          case MediaCollectionLayout.skinDefault:
            gallery = CollectionGroupGrid(
              messagePart: messagePart,
              cvController: cvController,
              isEditing: isEditing,
            );
        }
        // Galleries skip TailClipper; restore the author-edge inset bubbles get from it.
        return Padding(
          padding: collectionAuthorEdgeInsets(isFromMe: isFromMe),
          child: gallery,
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
