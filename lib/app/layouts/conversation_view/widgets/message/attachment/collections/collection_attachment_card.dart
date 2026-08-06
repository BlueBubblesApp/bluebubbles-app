import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

/// Single card slot in an iOS media collection stack.
class CollectionAttachmentCard extends StatelessWidget {
  const CollectionAttachmentCard({
    super.key,
    required this.attachment,
    required this.attachmentIndex,
    required this.messagePart,
    required this.galleryAttachments,
    this.reactionsByAttachmentKey,
    required this.isFromMe,
    this.ignorePointer = false,
  });

  final Attachment attachment;
  final int attachmentIndex;
  final MessagePart messagePart;
  final List<Attachment> galleryAttachments;
  final Map<String, List<Message>>? reactionsByAttachmentKey;
  final bool isFromMe;

  /// When true, pointer events pass through to the stack (past / background cards).
  final bool ignorePointer;

  int _partIdForAttachment() => messagePart.attachmentPartIndices?[attachmentIndex] ?? messagePart.part;

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

  List<Message> _reactionsFor() {
    final key = attachment.guid ?? attachment.transferName;
    if (key == null) return const [];
    return reactionsByAttachmentKey?[key] ?? const [];
  }

  Widget _withReactionOverlay(Widget card) {
    final reactions = _reactionsFor();
    if (reactions.isEmpty) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -14,
          left: isFromMe ? -14 : null,
          right: isFromMe ? null : -14,
          child: ReactionHolder(reactions: reactions),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _withReactionOverlay(
      IgnorePointer(
        ignoring: ignorePointer,
        child: AttachmentHolder(
          message: _scopedPart(),
          transparentBackground: true,
          showCardShadow: true,
          fill: true,
          galleryAttachments: galleryAttachments,
        ),
      ),
    );
  }
}
