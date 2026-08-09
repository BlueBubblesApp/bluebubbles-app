import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
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
      final reactions = state.associatedMessages
          .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")))
          .where((e) => (e.associatedMessagePart ?? 0) == targetPart)
          .toList();
      if (reactions.isEmpty) return const SizedBox.shrink();

      // Inside-tail (fan stack) stays on the trailing edge for both sides. Standard
      // (collage and similar) follows author side like a normal bubble.
      final forceTrailing = alignTrailing || tailType == ReactionTailType.inside;
      final alignRight = forceTrailing || !isFromMe;
      final edge = tightOverhang ? -14.0 : -20.0;
      return Positioned(
        top: tightOverhang ? -10.0 : -14.0,
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
  const CollectionAttachmentCard({
    super.key,
    required this.attachment,
    required this.attachmentIndex,
    required this.messagePart,
    required this.cvController,
    required this.isEditing,
    required this.collectionController,
    this.ignorePointer = false,
    this.enableGestures = false,
    this.reactionTailType = ReactionTailType.standard,
    this.alignTrailing = false,
    this.hideReactions = false,
    this.showCardShadow = true,
    this.mediaClipBorderRadius,
  });

  final Attachment attachment;
  final int attachmentIndex;
  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  /// Scopes fullscreen paging via [CollectionMediaController.media] and shows the
  /// collection-grid button. Overview gallery items use MediaGalleryCard instead (no controller).
  final CollectionMediaController collectionController;

  /// When true, pointer events pass through to overlapping / background card.
  final bool ignorePointer;

  /// When true, long-press / double-tap open the per-card popup menu.
  final bool enableGestures;

  /// Fan stack uses [ReactionTailType.inside]; collage and grid keep the default standard bubble.
  final ReactionTailType reactionTailType;

  /// Pin tapbacks to the top-trailing corner (grid cells).
  final bool alignTrailing;

  /// When true, omit in-card tapbacks (e.g. grid paints them in an overlay above all cells).
  final bool hideReactions;

  /// Soft card shadow (iOS only). Grid always passes false - parent owns the shadow.
  final bool showCardShadow;

  /// When set, clips media to this radius without clipping overflow tapbacks.
  /// Grid passes [BorderRadius.zero]; collage/stack omit and use [mediaCardBorderRadius].
  final BorderRadius? mediaClipBorderRadius;

  static double get mediaCardRadius => switch (SettingsSvc.settings.skin.value) {
        Skins.Samsung => 25.0,
        Skins.iOS => 20.0,
        Skins.Material => M3EShapes.lg,
      };

  static BorderRadius get mediaCardBorderRadius => BorderRadius.all(Radius.circular(mediaCardRadius));

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
    // Card owns shadow + clip so AttachmentHolder can stay fill-only.
    // Reactions stay outside the clip so tapbacks can overflow.
    final clipRadius = mediaClipBorderRadius ?? mediaCardBorderRadius;
    final paintShadow = showCardShadow && SettingsSvc.settings.skin.value == Skins.iOS;
    final media = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: clipRadius,
        boxShadow: paintShadow
            ? [
                BoxShadow(
                  color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: clipRadius,
        child: MessagePopupHolder(
          controller: MessageStateScope.of(context),
          cvController: cvController,
          part: scopedPart,
          isEditing: isEditing,
          enableGestures: enableGestures,
          child: IgnorePointer(
            ignoring: ignorePointer,
            child: AttachmentHolder(
              message: scopedPart,
              fill: true,
              collectionController: collectionController,
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
            alignTrailing: alignTrailing,
          ),
      ],
    );
  }
}
