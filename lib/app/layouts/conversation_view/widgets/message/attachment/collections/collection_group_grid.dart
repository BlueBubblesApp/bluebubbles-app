import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_grid_layout.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/media_collection.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_style.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_title.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

/// Google Messages–style grid for multi-attachment media collections.
///
/// Tile packing lives in [CollectionGridLayout]; this widget renders it. Collections over
/// [CollectionGridLayout.maxCollapsedTiles] show a `+N` tile — tap opens the collection gallery,
/// long-press expands the remaining items in place.
class CollectionGroupGrid extends StatefulWidget {
  const CollectionGroupGrid({
    super.key,
    required this.messagePart,
    required this.cvController,
    this.isEditing = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  @override
  State<CollectionGroupGrid> createState() => _CollectionGroupGridState();
}

class _CollectionGroupGridState extends State<CollectionGroupGrid> with ThemeHelpers {
  static const Duration _expandAnimDuration = Duration(milliseconds: 320);

  bool _expanded = false;

  MessagePart get messagePart => widget.messagePart;
  ConversationViewController get cvController => widget.cvController;
  bool get isEditing => widget.isEditing;
  List<Attachment> get _attachments => messagePart.attachments;

  bool _hasBodyBelow(MessageState messageState) {
    if (!isNullOrEmpty(messagePart.text)) return true;
    return messageState.parts.any(
      (p) => !messagePart.coversPartId(p.part) && p.part > messagePart.part && !isNullOrEmpty(p.text),
    );
  }

  /// Tighten only the author-edge corner against subject (top) / body (bottom).
  /// iOS always keeps a full-radius card (same policy as text bubbles skipping TailClipper connect).
  BorderRadius _silhouetteBorderRadius({
    required double cardRadius,
    required double connectedRadius,
    required bool isFromMe,
    required bool tightenTop,
    required bool tightenBottom,
  }) {
    final outer = Radius.circular(cardRadius);
    final connected = Radius.circular(connectedRadius);
    return BorderRadius.only(
      topLeft: (tightenTop && !isFromMe) ? connected : outer,
      topRight: (tightenTop && isFromMe) ? connected : outer,
      bottomLeft: (tightenBottom && !isFromMe) ? connected : outer,
      bottomRight: (tightenBottom && isFromMe) ? connected : outer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final collection = MediaCollection.forPart(context, collectionPart: messagePart, cvController: cvController);
    // Obx: the layout reads isFromMe, subject and parts (author-edge corners, title alignment).
    return MediaCollectionScope(collection: collection, child: Obx(() => _buildGrid(context, collection)));
  }

  Widget _buildGrid(BuildContext context, MediaCollection collection) {
    final messageState = collection.messageState;
    final isFromMe = messageState.isFromMe.value;
    // Connected author-edge corners match text-bubble TailClipper: Material/Samsung only.
    final connectCorners = !iOS;
    final count = _attachments.length;
    final silhouette = _silhouetteBorderRadius(
      cardRadius: CollectionStyle.cardRadius,
      connectedRadius: CollectionStyle.connectedCornerRadius,
      isFromMe: isFromMe,
      tightenTop: connectCorners && messageState.hasSubjectAbove(messagePart),
      tightenBottom: connectCorners && _hasBodyBelow(messageState),
    );
    final gridWidth = min(NavigationSvc.width(context) * CollectionStyle.gridWidthFactor, CollectionStyle.maxGridWidth);
    final layout = CollectionGridLayout.compute(count: count, width: gridWidth, expanded: _expanded);
    final gridHeight = layout.height;

    // Media is clipped to the silhouette; tapbacks sit in a second, unclipped layer above it so they can
    // overhang the cell edges. Both layers are positioned from the same layout.
    final imageLayer = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      borderRadius: silhouette,
      child: _positionCells(layout, (cell) => _buildMediaCell(context, collection, cell)),
    );
    final reactionLayer = _positionCells(layout, _buildReactionCell);

    final gridBody = AnimatedSize(
      duration: _expandAnimDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _expandAnimDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // Size to incoming child so AnimatedSize can grow; outgoing floats above.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          children: [
            for (final child in previousChildren)
              Positioned(top: 0, left: 0, right: 0, child: IgnorePointer(child: child)),
            if (currentChild != null) currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(_expanded),
          child: CollectionDownloadButton.wrap(
            isFromMe: isFromMe,
            contentWidth: gridWidth,
            contentHeight: gridHeight,
            attachments: _attachments,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                imageLayer,
                Positioned.fill(child: reactionLayer),
              ],
            ),
          ),
        ),
      ),
    );

    // iOS chrome: title above the card. Material/Samsung stay grid-only.
    return CollectionTitledLayout(collection: collection, isFromMe: isFromMe, child: gridBody);
  }

  /// Places one widget per tile of [layout]. Each tile is a non-clipping [Stack] so [Positioned] children
  /// (tapbacks, overlays) work inside it.
  Widget _positionCells(CollectionGridLayout layout, List<Widget> Function(CollectionGridCell cell) buildCell) {
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final cell in layout.cells)
            Positioned.fromRect(
              rect: cell.rect,
              child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: buildCell(cell)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMediaCell(BuildContext context, MediaCollection collection, CollectionGridCell cell) {
    final moreCount = cell.moreCount;
    return [
      CollectionAttachmentCard.gridCell(
        attachmentIndex: cell.index,
        messagePart: messagePart,
        cvController: cvController,
        isEditing: isEditing,
        enableGestures: true,
      ),
      if (moreCount != null && moreCount > 0)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => collection.openGallery(context),
            onLongPress: () {
              HapticFeedback.lightImpact();
              setState(() => _expanded = true);
            },
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: material ? FontWeight.w500 : FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// Tapbacks for one tile; none on the `+N` tile, which stands in for several attachments.
  List<Widget> _buildReactionCell(CollectionGridCell cell) {
    final moreCount = cell.moreCount;
    if (moreCount != null && moreCount > 0) return const [];
    return [
      CollectionAttachmentReactions(
        collectionPart: messagePart,
        attachmentIndex: cell.index,
        tightOverhang: true,
        tailType: iOS ? ReactionTailType.inside : ReactionTailType.standard,
      ),
    ];
  }

  Widget _wrapGridCard(
    BuildContext context, {
    required double width,
    required double height,
    required BorderRadius borderRadius,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
          boxShadow: CollectionStyle.cardShadow(context),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      ),
    );
  }
}
