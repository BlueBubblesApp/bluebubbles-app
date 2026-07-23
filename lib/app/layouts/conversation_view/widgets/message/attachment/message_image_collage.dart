import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_stack.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Vertical overlapping collage for 2–3 media attachments (iOS skin).
///
/// Even indexes sit flush to the author side; odd indexes get a horizontal stagger.
/// Lower cards overlap the ones above them. Each card is a [CollectionAttachmentCard]
/// with its own popup gestures, per-attachment tapbacks, and swipe-to-reply.
///
/// Card frames use each attachment's natural aspect ratio (mixed portrait/landscape
/// allowed). Media cover-fills the locked frame so load no longer resizes cards.
class MessageImageCollage extends StatelessWidget {
  const MessageImageCollage({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.fanDirection,
    this.isEditing = false,
    this.canSwipeToReply = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final GalleryFanDirection fanDirection;
  final bool isEditing;
  final bool canSwipeToReply;

  static const double _horizontalStagger = 20.0;
  static const double _verticalOverlap = 32.0;

  List<Attachment> get _attachments => messagePart.attachments;

  double _estimateHeight(Attachment attachment, double cardWidth) {
    final w = attachment.displayWidth;
    final h = attachment.displayHeight;
    if (w != null && w > 0 && h != null && h > 0) {
      return (h / w) * cardWidth;
    }
    return cardWidth;
  }

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final cardWidth = collectionCardWidth(context);
    // Matches MessagePartContent: from-me → right, received → left.
    final fromMe = fanDirection == GalleryFanDirection.right;

    final heights = [for (final a in _attachments) _estimateHeight(a, cardWidth)];
    final tops = <double>[];
    double y = 0;
    for (int i = 0; i < heights.length; i++) {
      tops.add(y);
      y += heights[i];
      if (i < heights.length - 1) y -= _verticalOverlap;
    }
    final totalHeight = tops.isEmpty ? 0.0 : tops.last + heights.last;
    final totalWidth = cardWidth + _horizontalStagger;

    final collage = SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _attachments.length; i++)
            Positioned(
              top: tops[i],
              // Even indexes flush to author; odd indexes shift toward center.
              // Only pin top/left so swipe-to-reply can grow the row beside the
              // fixed card SizedBox (Clip.none paints the chevron outside).
              left: fromMe
                  ? (i.isOdd ? 0.0 : _horizontalStagger)
                  : (i.isOdd ? _horizontalStagger : 0.0),
              child: _buildCard(messageState, i, cardWidth, heights[i]),
            ),
        ],
      ),
    );

    if (fromMe || !CollectionDownloadButton.isSupported) return collage;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        collage,
        const SizedBox(width: CollectionDownloadButton.gap),
        CollectionDownloadButton(attachments: _attachments),
      ],
    );
  }

  Widget _buildCard(MessageState messageState, int index, double cardWidth, double cardHeight) {
    return CollectionAttachmentCard(
      controller: messageState,
      cvController: cvController,
      collectionPart: messagePart,
      attachmentIndex: index,
      collectionAttachments: _attachments,
      isEditing: isEditing,
      canSwipeToReply: canSwipeToReply,
      enableSwipeToReply: true,
      fillCard: true,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
    );
  }
}
