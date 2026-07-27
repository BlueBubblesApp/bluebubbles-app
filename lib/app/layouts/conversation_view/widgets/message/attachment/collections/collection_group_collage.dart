import 'dart:math' as math;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_layout_metrics.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Vertical overlapping collage for multi-attachment media collections.
class CollectionGroupCollage extends StatelessWidget {
  const CollectionGroupCollage({
    super.key,
    required this.messagePart,
    required this.cvController,
    this.isEditing = false,
    this.canSwipeToReply = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;
  final bool canSwipeToReply;

  static const double _horizontalStagger = 28.0;
  static const double _verticalOverlap = 32.0;
  static const double _cardTiltRad = 0.75 * math.pi / 180;

  List<Attachment> get _attachments => messagePart.attachments;

  /// Landscape → 4:3; portrait / square / unknown → 3:4.
  double _estimateHeight(Attachment attachment, double cardWidth, MessageState messageState) {
    final guid = attachment.guid;
    final state = guid != null ? messageState.getAttachmentState(guid) : null;
    final w = state?.width.value ?? attachment.displayWidth;
    final h = state?.height.value ?? attachment.displayHeight;
    final isLandscape = w != null && h != null && w > 0 && h > 0 && w > h;
    return isLandscape ? cardWidth * 3 / 4 : cardWidth * 4 / 3;
  }

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final cardWidth = collectionCardWidth(context);
    final collectionController = CollectionMediaController(
      chat: cvController.chat,
      media: _attachments,
      messageState: messageState,
      collectionPart: messagePart,
    );

    return Obx(() {
      final isFromMe = messageState.isFromMe.value;
      final heights = [for (final a in _attachments) _estimateHeight(a, cardWidth, messageState)];
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
                left: isFromMe ? null : (i.isEven ? _horizontalStagger : 0.0),
                right: isFromMe ? (i.isEven ? _horizontalStagger : 0.0) : null,
                child: _buildCard(messageState, collectionController, i, cardWidth, heights[i], isFromMe),
              ),
          ],
        ),
      );

      return CollectionDownloadButton.wrap(
        isFromMe: isFromMe,
        contentWidth: totalWidth,
        contentHeight: totalHeight,
        attachments: _attachments,
        child: collage,
      );
    });
  }

  Widget _buildCard(
    MessageState messageState,
    CollectionMediaController collectionController,
    int index,
    double cardWidth,
    double cardHeight,
    bool isFromMe,
  ) {
    // Odd cards tilt toward the screen edge (left for fromOther, right for fromMe).
    return Transform.rotate(
      angle: (index.isOdd == isFromMe ? 1 : -1) * _cardTiltRad,
      child: CollectionAttachmentCard(
        controller: messageState,
        cvController: cvController,
        collectionPart: messagePart,
        attachmentIndex: index,
        collectionAttachments: _attachments,
        collectionController: collectionController,
        isEditing: isEditing,
        canSwipeToReply: canSwipeToReply,
        enableSwipeToReply: true,
        frameMode: AttachmentFrameMode.fixedCard,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
      ),
    );
  }
}
