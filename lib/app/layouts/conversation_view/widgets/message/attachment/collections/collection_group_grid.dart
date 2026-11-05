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
/// long-press expands the remaining items in place (or opens the gallery past [maxInPlaceTiles]).
class CollectionGroupGrid extends StatefulWidget {
  /// Largest collection the `+N` long-press expands in place. Expanding mounts every attachment at once (no
  /// lazy building inside a message bubble), so bigger collections open the gallery page instead.
  static const int maxInPlaceTiles = 24;

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
  static const Curve _expandCurve = Curves.easeOutCubic;

  bool _expanded = false;

  /// True only while the expand animation runs. Layout changes otherwise (window resize, rotation) apply
  /// immediately instead of trailing behind the new width.
  bool _animatingExpand = false;

  Duration get _layoutAnimDuration => _animatingExpand ? _expandAnimDuration : Duration.zero;

  void _expand() {
    setState(() {
      _expanded = true;
      _animatingExpand = true;
    });
    Future.delayed(_expandAnimDuration, () {
      if (mounted) setState(() => _animatingExpand = false);
    });
  }

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

    // One tree for collapsed and expanded: cells are keyed by attachment index and animate to their new rect,
    // so expanding moves the visible media instead of rebuilding it, and only the newly shown cells mount.
    // Media is clipped to the silhouette; tapbacks sit in a second, unclipped layer above it so they can
    // overhang the cell edges. Both layers are positioned from the same layout.
    final grid = SizedBox(
      width: gridWidth,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _wrapGridCard(
            context,
            width: gridWidth,
            height: layout.height,
            borderRadius: silhouette,
            child: _positionCells(layout, (cell) => _buildMediaCell(context, collection, cell)),
          ),
          Positioned.fill(child: _positionCells(layout, _buildReactionCell)),
        ],
      ),
    );

    // AnimatedSize smooths the message list's growth when the grid expands.
    final gridBody = AnimatedSize(
      duration: _layoutAnimDuration,
      curve: _expandCurve,
      alignment: Alignment.topCenter,
      child: CollectionDownloadButton.wrap(
        isFromMe: isFromMe,
        contentWidth: gridWidth,
        contentHeight: layout.height,
        attachments: _attachments,
        child: grid,
      ),
    );

    // iOS chrome: title above the card. Material/Samsung stay grid-only.
    return CollectionTitledLayout(collection: collection, isFromMe: isFromMe, child: gridBody);
  }

  /// Places one widget per tile of [layout], keyed by attachment index so a tile keeps its element when the
  /// layout changes. Each tile is a non-clipping [Stack] so [Positioned] children (tapbacks, overlays) work
  /// inside it. Tiles past [CollectionGridLayout.maxCollapsedTiles] only exist once expanded, so they fade in.
  Widget _positionCells(CollectionGridLayout layout, List<Widget> Function(CollectionGridCell cell) buildCell) {
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final cell in layout.cells)
            AnimatedPositioned.fromRect(
              key: ValueKey(cell.index),
              duration: _layoutAnimDuration,
              curve: _expandCurve,
              rect: cell.rect,
              child: _fadeInIfRevealed(
                cell.index,
                Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: buildCell(cell)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fadeInIfRevealed(int index, Widget child) {
    if (index < CollectionGridLayout.maxCollapsedTiles) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _expandAnimDuration,
      curve: Curves.easeOut,
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: child,
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
              if (_attachments.length > CollectionGroupGrid.maxInPlaceTiles) {
                collection.openGallery(context);
              } else {
                _expand();
              }
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
    // Animated so the silhouette (and its clip) grows with the cells when the grid expands.
    return AnimatedContainer(
      duration: _layoutAnimDuration,
      curve: _expandCurve,
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        boxShadow: CollectionStyle.cardShadow(context),
      ),
      child: child,
    );
  }
}
