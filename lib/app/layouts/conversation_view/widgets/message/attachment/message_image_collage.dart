import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_gallery.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Vertical overlapping collage for 2–3 media attachments (iOS skin).
///
/// Even indexes sit flush to the author side; odd indexes get a horizontal stagger.
/// Lower cards overlap the ones above them. Each card is an independent [AttachmentHolder].
class MessageImageCollage extends StatelessWidget {
  const MessageImageCollage({
    super.key,
    required this.attachments,
    required this.partIndex,
    required this.fanDirection,
  });

  final List<Attachment> attachments;
  final int partIndex;
  final GalleryFanDirection fanDirection;

  static const double _horizontalStagger = 20.0;
  static const double _verticalOverlap = 32.0;

  MessagePart _partForAttachment(Attachment attachment) {
    return MessagePart(
      part: partIndex,
      attachments: [attachment],
      shouldRedact: false,
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
    final cardWidth = min(NavigationSvc.width(context) * 0.5, 260.0);
    final fromMe = fanDirection == GalleryFanDirection.left;

    final heights = [for (final a in attachments) _estimateHeight(a, cardWidth)];
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
          for (int i = 0; i < attachments.length; i++)
            Positioned(
              top: tops[i],
              // Even indexes flush to author; odd indexes shift toward center.
              left: fromMe
                  ? (i.isOdd ? 0.0 : _horizontalStagger)
                  : (i.isOdd ? _horizontalStagger : 0.0),
              width: cardWidth,
              child: AttachmentHolder(
                message: _partForAttachment(attachments[i]),
                transparentBackground: true,
                showCardShadow: true,
                galleryAttachments: attachments,
              ),
            ),
        ],
      ),
    );
  }
}
