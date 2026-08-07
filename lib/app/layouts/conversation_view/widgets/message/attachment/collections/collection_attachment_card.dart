import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Tapbacks for a single attachment inside a media collection stack.
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

  /// Pin to the top-trailing corner. Also implied for [ReactionTailType.inside].
  final bool alignTrailing;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      final isFromMe = state.isFromMe.value;
      final targetPart = collectionPart.partIdForAttachment(attachmentIndex);
      final reactions = state.associatedMessages
          .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")))
          .where((e) => (e.associatedMessagePart ?? 0) == targetPart)
          .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      // Stack fans always open right, so inside-tail reactions stay on the trailing
      // edge for both sides.
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

/// Single card slot in an iOS media collection stack.
class CollectionAttachmentCard extends StatelessWidget {
  const CollectionAttachmentCard({
    super.key,
    required this.attachment,
    required this.attachmentIndex,
    required this.messagePart,
    required this.galleryAttachments,
    required this.cvController,
    required this.isEditing,
    this.ignorePointer = false,
    this.enableGestures = false,
  });

  final Attachment attachment;
  final int attachmentIndex;
  final MessagePart messagePart;
  final List<Attachment> galleryAttachments;
  final ConversationViewController cvController;
  final bool isEditing;

  /// When true, pointer events pass through to the stack (past / background cards).
  final bool ignorePointer;

  /// When true, long-press / double-tap open the per-card popup menu.
  final bool enableGestures;

  int _partIdForAttachment() => messagePart.partIdForAttachment(attachmentIndex);

  MessagePart _scopedPart() {
    return MessagePart(
      part: _partIdForAttachment(),
      attachments: [attachment],
      shouldRedact: false,
      text: null,
      subject: null,
      mentions: const [],
      edits: const [],
      isUnsent: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopedPart = _scopedPart();
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        MessagePopupHolder(
          controller: MessageStateScope.of(context),
          cvController: cvController,
          part: scopedPart,
          isEditing: isEditing,
          enableGestures: enableGestures,
          child: IgnorePointer(
            ignoring: ignorePointer,
            child: AttachmentHolder(
              message: scopedPart,
              transparentBackground: true,
              showCardShadow: true,
              fill: true,
              galleryAttachments: galleryAttachments,
            ),
          ),
        ),
        CollectionAttachmentReactions(
          collectionPart: messagePart,
          attachmentIndex: attachmentIndex,
          tailType: ReactionTailType.inside,
        ),
      ],
    );
  }
}
