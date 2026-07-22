import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/swipe_to_reply_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
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
  });

  final MessagePart collectionPart;
  final int attachmentIndex;

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

      return Positioned(
        top: -14,
        left: isFromMe ? -20 : null,
        right: isFromMe ? null : -20,
        child: ReactionHolder(
          reactions: reactions,
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

  Widget _buildCardContent(MessagePart scopedPart) {
    return Stack(
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
            showCardShadow: true,
            galleryAttachments: widget.collectionAttachments,
          ),
        ),
        CollectionAttachmentReactions(
          collectionPart: widget.collectionPart,
          attachmentIndex: widget.attachmentIndex,
        ),
      ],
    );
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
          SlideToReply(
            width: _replyOffset.value.abs(),
            isFromMe: isFromMe,
          ),
        ].conditionalReverse(isFromMe),
      );
    });
  }
}
