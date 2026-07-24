import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/swipe_to_reply_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/ui/reaction_helpers.dart';
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Tapbacks for a single attachment inside a media collection (collage or stack).
class CollectionAttachmentReactions extends StatelessWidget {
  const CollectionAttachmentReactions({
    super.key,
    required this.collectionPart,
    required this.attachmentIndex,
    this.tailType = ReactionTailType.standard,
    this.alignTrailing = false,
  });

  final MessagePart collectionPart;
  final int attachmentIndex;
  final ReactionTailType tailType;

  /// When true, always pin to the top-trailing corner (and use a matching
  /// [ReactionTailDirection]). Used by the collection grid page.
  /// Also implied when [tailType] is [ReactionTailType.inside] (stack fan).
  final bool alignTrailing;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      final isFromMe = state.isFromMe.value;
      final targetPart = collectionPart.partIndexForAttachment(attachmentIndex);
      final reactions = state.associatedMessages
          .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")))
          .where((e) => (e.associatedMessagePart ?? 0) == targetPart)
          .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      // Stack fans always open right, so inside-tail reactions stay on the trailing
      // edge for both sides (matching from-others / collection grid).
      final forceTrailing = alignTrailing || tailType == ReactionTailType.inside;
      final alignRight = forceTrailing || !isFromMe;
      return Positioned(
        top: -14,
        left: alignRight ? null : -20,
        right: alignRight ? -20 : null,
        child: ReactionHolder(
          reactions: reactions,
          tailType: tailType,
          // From-me defaults to a left-pointing tail; switch to right when trailing.
          tailDirection: forceTrailing ? ReactionTailDirection.right : null,
        ),
      );
    });
  }
}

/// Per-card wrapper for media collection attachments: popup gestures + tapbacks.
class CollectionAttachmentCard extends StatefulWidget {
  const CollectionAttachmentCard({
    super.key,
    required this.controller,
    required this.cvController,
    required this.collectionPart,
    required this.attachmentIndex,
    required this.collectionAttachments,
    this.isEditing = false,
    this.enableGestures = true,
    this.canSwipeToReply = false,
    this.enableSwipeToReply = false,
    this.inGridCell = false,
    this.fillCard = false,
    this.cardWidth,
    this.cardHeight,
    this.hideReactions = false,
    this.reactionTailType = ReactionTailType.standard,
  });

  final MessageState controller;
  final ConversationViewController cvController;
  final MessagePart collectionPart;
  final int attachmentIndex;
  final List<Attachment> collectionAttachments;
  final bool isEditing;
  final bool enableGestures;
  final bool canSwipeToReply;
  final bool enableSwipeToReply;
  final bool inGridCell;
  /// Cover-fill a fixed collage/stack card frame (keeps [showCardShadow]).
  final bool fillCard;
  /// Explicit frame when [fillCard] is true. Required for collage swipe-to-reply
  /// so the reply chevron can sit beside the card instead of inside a tight Positioned.
  final double? cardWidth;
  final double? cardHeight;
  final bool hideReactions;
  /// Thought-bubble tail style for per-card tapbacks (stack uses [ReactionTailType.inside]).
  final ReactionTailType reactionTailType;

  @override
  State<CollectionAttachmentCard> createState() => _CollectionAttachmentCardState();
}

class _CollectionAttachmentCardState extends State<CollectionAttachmentCard> {
  final RxDouble _replyOffset = 0.0.obs;

  MessagePart get _scopedPart => MessagePart(
        part: widget.collectionPart.partIndexForAttachment(widget.attachmentIndex),
        attachments: [widget.collectionAttachments[widget.attachmentIndex]],
        shouldRedact: widget.collectionPart.shouldRedact,
        text: null,
        subject: null,
        mentions: const [],
        edits: const [],
        isUnsent: false,
      );

  bool get _swipeEnabled =>
      widget.enableSwipeToReply && widget.canSwipeToReply && !widget.isEditing;

  bool get _hasExplicitCardSize =>
      widget.fillCard && widget.cardWidth != null && widget.cardHeight != null;

  Widget _buildCardContent(MessagePart scopedPart) {
    // fillCard/inGridCell: expand so SizedBox.expand in AttachmentHolder gets tight bounds.
    final fill = widget.fillCard || widget.inGridCell;
    Widget content = Stack(
      fit: fill ? StackFit.expand : StackFit.loose,
      clipBehavior: Clip.none,
      children: [
        MessagePopupHolder(
          controller: widget.controller,
          cvController: widget.cvController,
          isEditing: widget.isEditing,
          part: scopedPart,
          enableGestures: widget.enableGestures,
          child: AttachmentHolder(
            message: scopedPart,
            transparentBackground: true,
            showCardShadow: !widget.inGridCell,
            inGridCell: widget.inGridCell,
            fillCard: widget.fillCard,
            galleryAttachments: widget.collectionAttachments,
          ),
        ),
        if (!widget.hideReactions)
          CollectionAttachmentReactions(
            collectionPart: widget.collectionPart,
            attachmentIndex: widget.attachmentIndex,
            tailType: widget.reactionTailType,
          ),
      ],
    );

    if (_hasExplicitCardSize) {
      content = SizedBox(
        width: widget.cardWidth,
        height: widget.cardHeight,
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final scopedPart = _scopedPart;
    final attachment = widget.collectionAttachments[widget.attachmentIndex];

    if (!_swipeEnabled) {
      return _buildCardContent(scopedPart);
    }

    return Obx(() {
      final isFromMe = widget.controller.isFromMe.value;
      // Keep the card on a fixed SizedBox and let SlideToReply sit beside it
      // (mainAxisSize.min). Putting Expanded inside a tight Positioned ate the
      // chevron space and broke collage swipe-to-reply.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwipeToReplyWrapper(
            enabled: true,
            partIndex: scopedPart.part,
            attachmentGuid: attachment.guid,
            replyOffset: _replyOffset,
            cvController: widget.cvController,
            child: _buildCardContent(scopedPart),
          ),
          SlideToReply(
            width: _replyOffset.value.abs(),
            isFromMe: isFromMe,
          ),
        ].conditionalReverse(isFromMe),
      );
    });
  }
}
