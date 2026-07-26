import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/swipe_to_reply_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
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

  /// Pin to the top-trailing corner (collection grid). Also implied for [ReactionTailType.inside].
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
          tailDirection: forceTrailing ? ReactionTailDirection.right : null,
        ),
      );
    });
  }
}

/// Per-card popup, tapbacks, and optional swipe-to-reply for media collections.
class CollectionAttachmentCard extends StatefulWidget {
  const CollectionAttachmentCard({
    super.key,
    required this.controller,
    required this.cvController,
    required this.collectionPart,
    required this.attachmentIndex,
    required this.collectionAttachments,
    required this.frameMode,
    this.collectionController,
    this.isEditing = false,
    this.enableGestures = true,
    this.canSwipeToReply = false,
    this.enableSwipeToReply = false,
    this.cardWidth,
    this.cardHeight,
    this.hideReactions = false,
    this.reactionTailType = ReactionTailType.standard,
  }) : assert(
          frameMode == AttachmentFrameMode.fixedCard || frameMode == AttachmentFrameMode.gridCell,
          'CollectionAttachmentCard only supports fixedCard or gridCell',
        );

  final MessageState controller;
  final ConversationViewController cvController;
  final MessagePart collectionPart;
  final int attachmentIndex;
  final List<Attachment> collectionAttachments;
  final CollectionMediaController? collectionController;

  /// [AttachmentFrameMode.fixedCard] (collage/stack) or [AttachmentFrameMode.gridCell].
  final AttachmentFrameMode frameMode;
  final bool isEditing;
  final bool enableGestures;
  final bool canSwipeToReply;
  final bool enableSwipeToReply;

  /// Explicit frame when [frameMode] is [AttachmentFrameMode.fixedCard]
  /// (lets swipe-to-reply sit beside the card).
  final double? cardWidth;
  final double? cardHeight;
  final bool hideReactions;
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
      widget.frameMode == AttachmentFrameMode.fixedCard &&
      widget.cardWidth != null &&
      widget.cardHeight != null;

  Widget _buildCardContent(MessagePart scopedPart) {
    Widget content = Stack(
      fit: StackFit.expand,
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
            frameMode: widget.frameMode,
            galleryAttachments: widget.collectionAttachments,
            collectionController: widget.collectionController,
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
          AnimatedPadding(
            duration: Duration(milliseconds: _replyOffset.value == 0 ? 150 : 0),
            padding: EdgeInsets.only(
              left: isFromMe && _replyOffset.value != 0 ? 10 : 0,
              right: !isFromMe && _replyOffset.value != 0 ? 10 : 0,
            ),
            child: SlideToReply(
              width: _replyOffset.value.abs(),
              isFromMe: isFromMe,
            ),
          ),
        ].conditionalReverse(isFromMe),
      );
    });
  }
}
