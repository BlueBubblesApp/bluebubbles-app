import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
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
class CollectionAttachmentCard extends StatelessWidget {
  const CollectionAttachmentCard({
    super.key,
    required this.controller,
    required this.cvController,
    required this.collectionPart,
    required this.attachmentIndex,
    required this.collectionAttachments,
    this.isEditing = false,
    this.enableGestures = true,
  });

  final MessageState controller;
  final ConversationViewController cvController;
  final MessagePart collectionPart;
  final int attachmentIndex;
  final List<Attachment> collectionAttachments;
  final bool isEditing;
  final bool enableGestures;

  MessagePart get _scopedPart => MessagePart(
        part: collectionPart.partIndexForAttachment(attachmentIndex),
        attachments: [collectionAttachments[attachmentIndex]],
        shouldRedact: collectionPart.shouldRedact,
        text: null,
        subject: null,
        mentions: const [],
        edits: const [],
        isUnsent: false,
      );

  @override
  Widget build(BuildContext context) {
    final scopedPart = _scopedPart;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MessagePopupHolder(
          controller: controller,
          cvController: cvController,
          isEditing: isEditing,
          part: scopedPart,
          enableGestures: enableGestures,
          child: AttachmentHolder(
            message: scopedPart,
            transparentBackground: true,
            showCardShadow: true,
            galleryAttachments: collectionAttachments,
          ),
        ),
        CollectionAttachmentReactions(
          collectionPart: collectionPart,
          attachmentIndex: attachmentIndex,
        ),
      ],
    );
  }
}
