import 'dart:math' as math;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_stack.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Vertical overlapping collage for multi-attachment media collections.
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

  static const double _horizontalStagger = 28.0;
  static const double _verticalOverlap = 32.0;
  static const double _cardTiltRad = 0.75 * math.pi / 180;

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
              // Pin to the author edge so swipe-to-reply can grow the chevron toward
              // center beside the card (Clip.none). 
              left: fromMe ? null : (i.isOdd ? _horizontalStagger : 0.0),
              right: fromMe ? (i.isOdd ? _horizontalStagger : 0.0) : null,
              child: _buildCard(messageState, i, cardWidth, heights[i]),
            ),
        ],
      ),
    );

    if (fromMe || !CollectionDownloadButton.isSupported) return collage;

    return SizedBox(
      width: totalWidth + CollectionDownloadButton.gap + CollectionDownloadButton.size,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: totalWidth + CollectionDownloadButton.gap,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.center,
              child: CollectionDownloadButton(attachments: _attachments),
            ),
          ),
          collage,
        ],
      ),
    );
  }

  Widget _buildCard(MessageState messageState, int index, double cardWidth, double cardHeight) {
    return Transform.rotate(
      angle: index.isOdd ? _cardTiltRad : -_cardTiltRad,
      child: CollectionAttachmentCard(
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
      ),
    );
  }
}
