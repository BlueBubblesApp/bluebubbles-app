import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_style.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/media_collection.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Tapbacks for a single attachment inside a media collection: on collage / stack cards, in the grid's overlay,
/// and on cells of the collection gallery page.
class CollectionAttachmentReactions extends StatelessWidget {
  const CollectionAttachmentReactions({
    super.key,
    required this.collectionPart,
    required this.attachmentIndex,
    this.tailType = ReactionTailType.standard,
    this.alignTrailing = false,
    this.tightOverhang = false,
  });

  final MessagePart collectionPart;
  final int attachmentIndex;
  final ReactionTailType tailType;

  /// Pin to the top-trailing corner. Also implied for [ReactionTailType.inside].
  final bool alignTrailing;

  /// Smaller hang-off (grid) so badges stay nearer their cell on shared gaps.
  final bool tightOverhang;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      final isFromMe = state.isFromMe.value;
      final targetPart = collectionPart.partIdForAttachment(attachmentIndex);
      final reactions = state.tapbacksForPartId(targetPart);
      if (reactions.isEmpty) return const SizedBox.shrink();

      // Inside-tail (fan stack) stays on the trailing edge for both sides. Standard
      // (collage and similar) follows author side like a normal bubble.
      final forceTrailing = alignTrailing || tailType == ReactionTailType.inside;
      final alignRight = forceTrailing || !isFromMe;
      // Grid cells share 2px gaps, so the tight variant hangs off 4px / 6px less than a normal bubble.
      final edge = tightOverhang ? ReactionHolder.bubbleOverhangSide + 6 : ReactionHolder.bubbleOverhangSide;
      return Positioned(
        top: tightOverhang ? ReactionHolder.bubbleOverhangTop + 4 : ReactionHolder.bubbleOverhangTop,
        left: alignRight ? null : edge,
        right: alignRight ? edge : null,
        child: ReactionHolder(
          reactions: reactions,
          tailType: tailType,
          tailDirection: forceTrailing ? ReactionTailDirection.right : null,
        ),
      );
    });
  }
}

/// Shared card slot for media collection layouts (collage, stack, grid).
///
/// Parents own frame size and motion; this widget owns card shadow + rounded clip
/// around media, popup, and reactions (reactions sit outside the clip).
class CollectionAttachmentCard extends StatelessWidget {
  /// A free-standing card (collage, stack): skin radius, iOS shadow, and its own tapbacks.
  const CollectionAttachmentCard({
    super.key,
    required this.attachment,
    required this.attachmentIndex,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
    this.ignorePointer = false,
    this.enableGestures = false,
    this.reactionTailType = ReactionTailType.standard,
  })  : hideReactions = false,
        showCardShadow = true,
        mediaClipBorderRadius = null;

  /// A grid cell: square edges, no shadow and no in-card tapbacks. The grid's outer clip owns the silhouette
  /// and shadow, and it paints every cell's tapbacks in one overlay above all cells so they aren't clipped.
  const CollectionAttachmentCard.gridCell({
    super.key,
    required this.attachment,
    required this.attachmentIndex,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
    this.enableGestures = false,
  })  : ignorePointer = false,
        reactionTailType = ReactionTailType.standard,
        hideReactions = true,
        showCardShadow = false,
        mediaClipBorderRadius = BorderRadius.zero;

  final Attachment attachment;
  final int attachmentIndex;
  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  /// When true, pointer events pass through to overlapping / background card.
  final bool ignorePointer;

  /// When true, long-press / double-tap open the per-card popup menu.
  final bool enableGestures;

  /// Fan stack uses [ReactionTailType.inside]; collage and grid keep the default standard bubble.
  final ReactionTailType reactionTailType;

  /// Omit in-card tapbacks ([CollectionAttachmentCard.gridCell]).
  final bool hideReactions;

  /// Soft card shadow (iOS only); off for [CollectionAttachmentCard.gridCell].
  final bool showCardShadow;

  /// Media clip radius; null uses [CollectionStyle.cardBorderRadius]. Tapbacks are never clipped.
  final BorderRadius? mediaClipBorderRadius;

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

  /// [MessagePopupHolder] re-renders its child inside the popup route, outside the layout's
  /// [MediaCollectionScope]. Re-provide it (as the holder does for ChatStateScope) so fullscreen opened
  /// from the popup preview still pages through the collection.
  Widget _reprovideCollection(BuildContext context, Widget child) {
    final collection = MediaCollectionScope.maybeOf(context);
    if (collection == null) return child;
    return MediaCollectionScope(collection: collection, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final scopedPart = _scopedPart();
    // Card owns shadow + clip so AttachmentHolder can stay fill-only.
    // Reactions stay outside the clip so tapbacks can overflow.
    final clipRadius = mediaClipBorderRadius ?? CollectionStyle.cardBorderRadius;
    final media = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: clipRadius,
        boxShadow: showCardShadow ? CollectionStyle.cardShadow(context) : null,
      ),
      child: ClipRRect(
        borderRadius: clipRadius,
        child: MessagePopupHolder(
          controller: MessageStateScope.of(context),
          cvController: cvController,
          part: scopedPart,
          isEditing: isEditing,
          enableGestures: enableGestures,
          child: _reprovideCollection(
            context,
            IgnorePointer(
              ignoring: ignorePointer,
              child: AttachmentHolder(
                message: scopedPart,
                fill: true,
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        media,
        if (!hideReactions)
          CollectionAttachmentReactions(
            collectionPart: messagePart,
            attachmentIndex: attachmentIndex,
            tailType: reactionTailType,
          ),
      ],
    );
  }
}
