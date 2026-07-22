import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_stack.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Vertical overlapping collage for 2–3 media attachments (iOS skin).
///
/// Even indexes sit flush to the author side; odd indexes get a horizontal stagger.
/// Lower cards overlap the ones above them. Each card is an independent [AttachmentHolder]
/// wrapped in its own [MessagePopupHolder] so long-press targets that attachment.
class MessageImageCollage extends StatelessWidget {
  const MessageImageCollage({
    super.key,
    required this.messagePart,
    required this.cvController,
    required this.fanDirection,
    this.isEditing = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final GalleryFanDirection fanDirection;
  final bool isEditing;

  static const double _horizontalStagger = 20.0;
  static const double _verticalOverlap = 32.0;

  List<Attachment> get _attachments => messagePart.attachments;

  MessagePart _partForAttachment(int index) {
    return MessagePart(
      part: messagePart.partIndexForAttachment(index),
      attachments: [_attachments[index]],
      shouldRedact: messagePart.shouldRedact,
      text: null,
      subject: null,
      mentions: const [],
      edits: const [],
      isUnsent: false,
    );
  }

  double _estimateHeight(Attachment attachment, double cardWidth) {
    final w = attachment.width;
    final h = attachment.height;
    if (w != null && w > 0 && h != null && h > 0) {
      return (h / w) * cardWidth;
    }
    return cardWidth;
  }

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final cardWidth = min(NavigationSvc.width(context) * 0.5, 260.0);
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

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _attachments.length; i++)
            Positioned(
              top: tops[i],
              // Even indexes flush to author; odd indexes shift toward center.
              left: fromMe
                  ? (i.isOdd ? 0.0 : _horizontalStagger)
                  : (i.isOdd ? _horizontalStagger : 0.0),
              width: cardWidth,
              child: _buildCard(messageState, i),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(MessageState messageState, int index) {
    final part = _partForAttachment(index);
    return MessagePopupHolder(
      controller: messageState,
      cvController: cvController,
      isEditing: isEditing,
      part: part,
      child: AttachmentHolder(
        message: part,
        transparentBackground: true,
        showCardShadow: true,
        galleryAttachments: _attachments,
      ),
    );
  }
}
