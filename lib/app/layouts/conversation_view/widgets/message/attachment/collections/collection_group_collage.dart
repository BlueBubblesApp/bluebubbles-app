import 'dart:math' as math;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/swipe_to_reply_wrapper.dart';
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
    required this.isEditing,
    this.canSwipeToReply = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;
  final bool canSwipeToReply;

  static const double _horizontalStagger = 32.0;
  static const double _verticalOverlap = 20.0;
  static const double _cardTiltRad = 0.75 * math.pi / 180;
  static const double _maxCollageSizeFactor = 0.42;
  static const double _maxCollageWidth = 220.0;

  List<Attachment> get _attachments => messagePart.attachments;

  /// Whether this index should sit inward (away from the author edge).
  /// ios parity: For 2 items with no subject bubble, the first card is author-flush; otherwise
  /// (3+, or 2 with a subject above) the first is staggered in.
  static bool _staggerInward(int index, bool alignFirstToAuthor) =>
      alignFirstToAuthor ? index.isOdd : index.isEven;

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
    final isIOS = SettingsSvc.settings.skin.value == Skins.iOS;
    // Calculated against screen width; maxCollageWidth caps size on larger screens.
    final cardWidth = math.min(
      NavigationSvc.width(context) * _maxCollageSizeFactor,
      _maxCollageWidth,
    );
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
      // Subject bubble (message-level, above leading attachment parts) already
      // provides author-side alignment - keep the first card staggered in then.
      final hasSubjectBubble = messageState.isLeadingMessagePart(messagePart) &&
          !isNullOrEmpty(messageState.subject.value);
      final alignFirstToAuthor = _attachments.length == 2 && !hasSubjectBubble;

      final collage = SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < _attachments.length; i++)
              Positioned(
                top: tops[i],
                left: isFromMe
                    ? null
                    : (_staggerInward(i, alignFirstToAuthor) ? _horizontalStagger : 0.0),
                right: isFromMe
                    ? (_staggerInward(i, alignFirstToAuthor) ? _horizontalStagger : 0.0)
                    : null,
                child: _buildCard(collectionController, i, cardWidth, heights[i], isFromMe, isIOS),
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
    CollectionMediaController collectionController,
    int index,
    double cardWidth,
    double cardHeight,
    bool isFromMe,
    bool isIOS,
  ) {
    final card = CollectionAttachmentCard(
      attachment: _attachments[index],
      attachmentIndex: index,
      messagePart: messagePart,
      collectionController: collectionController,
      cvController: cvController,
      isEditing: isEditing,
      enableGestures: true,
    );

    // Parent owns the 4:3 / 3:4 frame; card expands to fill (same as fan stack).
    final framed = SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: isIOS
          // Odd cards tilt toward the screen edge (left for fromOther, right for fromMe).
          ? Transform.rotate(
              angle: (index.isOdd == isFromMe ? 1 : -1) * _cardTiltRad,
              child: card,
            )
          : card,
    );

    final swipeEnabled = canSwipeToReply && !isEditing;
    if (!swipeEnabled) return framed;

    return _CollageSwipeCard(
      partIndex: messagePart.partIdForAttachment(index),
      attachmentGuid: _attachments[index].guid,
      cvController: cvController,
      isFromMe: isFromMe,
      child: framed,
    );
  }
}

/// Collage-local swipe-to-reply: chevron sits beside the fixed card frame.
class _CollageSwipeCard extends StatefulWidget {
  const _CollageSwipeCard({
    required this.partIndex,
    required this.attachmentGuid,
    required this.cvController,
    required this.isFromMe,
    required this.child,
  });

  final int partIndex;
  final String? attachmentGuid;
  final ConversationViewController cvController;
  final bool isFromMe;
  final Widget child;

  @override
  State<_CollageSwipeCard> createState() => _CollageSwipeCardState();
}

class _CollageSwipeCardState extends State<_CollageSwipeCard> {
  final RxDouble _replyOffset = 0.0.obs;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offset = _replyOffset.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwipeToReplyWrapper(
            enabled: true,
            partIndex: widget.partIndex,
            attachmentGuid: widget.attachmentGuid,
            replyOffset: _replyOffset,
            cvController: widget.cvController,
            child: widget.child,
          ),
          AnimatedPadding(
            duration: Duration(milliseconds: offset == 0 ? 150 : 0),
            padding: EdgeInsets.only(
              left: widget.isFromMe && offset != 0 ? 10 : 0,
              right: !widget.isFromMe && offset != 0 ? 10 : 0,
            ),
            child: SlideToReply(
              width: offset.abs(),
              isFromMe: widget.isFromMe,
            ),
          ),
        ].conditionalReverse(widget.isFromMe),
      );
    });
  }
}
