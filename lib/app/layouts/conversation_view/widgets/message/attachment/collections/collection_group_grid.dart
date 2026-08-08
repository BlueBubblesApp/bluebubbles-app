import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/conversation_fullscreen_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Google Messages–style grid for multi-attachment media collections.
class CollectionGroupGrid extends StatelessWidget {
  const CollectionGroupGrid({
    super.key,
    required this.messagePart,
    required this.cvController,
    this.isEditing = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  static const double _gap = 2.0;
  static const double _maxGridSizeFactor = 0.62;
  static const double _maxGridWidth = 280.0;
  static const double _topRowAspect = 4 / 3;
  static const double _bottomRowHeightRatio = 0.45;

  /// Matches [TailClipper] connected corners when a bubble sits flush to a neighbor.
  static const double _connectedCornerRadius = 5.0;

  List<Attachment> get _attachments => messagePart.attachments;

  double get _cardRadius {
    switch (SettingsSvc.settings.skin.value) {
      case Skins.Samsung:
        return 25.0;
      case Skins.iOS:
        return 8.0;
      case Skins.Material:
        return 16.0;
    }
  }

  /// Subject bubble sits above the leading attachment part (see [MessageHolder]).
  bool _hasSubjectAbove(MessageState messageState) =>
      messageState.isLeadingMessagePart(messagePart) && !isNullOrEmpty(messageState.subject.value);

  /// Body text on this part, or a later text part below the collection.
  bool _hasBodyBelow(MessageState messageState) {
    if (!isNullOrEmpty(messagePart.text)) return true;
    return messageState.parts.any(
      (p) => !messagePart.coversPartId(p.part) && p.part > messagePart.part && !isNullOrEmpty(p.text),
    );
  }

  /// Outer silhouette radii — tighten only the author-edge corner that sits against
  /// subject (top) / body (bottom). Non-author corners keep the full card radius
  /// (Material connected-bubble parity with [TailClipper]).
  BorderRadius _silhouetteBorderRadius({
    required double cardRadius,
    required bool isFromMe,
    required bool tightenTop,
    required bool tightenBottom,
  }) {
    final outer = Radius.circular(cardRadius);
    final connected = const Radius.circular(_connectedCornerRadius);
    return BorderRadius.only(
      topLeft: (tightenTop && !isFromMe) ? connected : outer,
      topRight: (tightenTop && isFromMe) ? connected : outer,
      bottomLeft: (tightenBottom && !isFromMe) ? connected : outer,
      bottomRight: (tightenBottom && isFromMe) ? connected : outer,
    );
  }

  /// One column of the 5+ bottom row (3 columns with two gaps).
  double _columnWidth(double gridWidth) => (gridWidth - 2 * _gap) / 3;

  void _openSeeMoreFullscreen(BuildContext context) {
    // Interim: open the fullscreen carousel on the covered 5th tile (index 4),
    // not the PR6 overview page.
    final attachment = _attachments[4];
    cvController.focusNode.unfocus();
    cvController.subjectFocusNode.unfocus();
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => ConversationFullscreenHolder(
          currentChat: cvController.chat,
          attachment: attachment,
          showInteractions: true,
          galleryAttachments: _attachments,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final isFromMe = messageState.isFromMe.value;
    final count = _attachments.length;
    final cardRadius = _cardRadius;
    // Subject above / body below: tighten only the author-edge corner against the text bubble.
    final silhouette = _silhouetteBorderRadius(
      cardRadius: cardRadius,
      isFromMe: isFromMe,
      tightenTop: _hasSubjectAbove(messageState),
      tightenBottom: _hasBodyBelow(messageState),
    );
    // Calculated against screen width; maxGridWidth caps size on larger screens.
    final gridWidth = min(
      NavigationSvc.width(context) * _maxGridSizeFactor,
      _maxGridWidth,
    );
    final gridHeight = _gridHeight(count, gridWidth);
    final moreCount = count > 5 ? count - 5 : null;

    // Media layer: clipped cells with in-card reactions suppressed.
    final imageLayer = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      borderRadius: silhouette,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        moreCount: moreCount,
        cellBuilder: (index, width, height, cellMoreCount) => ClipRRect(
          borderRadius: _cellBorderRadius(count, index, silhouette),
          child: CollectionAttachmentCard(
            attachment: _attachments[index],
            attachmentIndex: index,
            messagePart: messagePart,
            galleryAttachments: _attachments,
            cvController: cvController,
            isEditing: isEditing,
            enableGestures: true,
            hideReactions: true,
            showCardShadow: false,
            // Parent cell ClipRRect owns silhouette corners; keep media square inside.
            mediaClipBorderRadius: BorderRadius.zero,
          ),
        ),
        moreOverlayBuilder: (index, width, height, cellMoreCount) {
          if (cellMoreCount == null || cellMoreCount <= 0) return null;
          return ClipRRect(
            borderRadius: _cellBorderRadius(count, index, silhouette),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSeeMoreFullscreen(context),
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$cellMoreCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: SettingsSvc.settings.skin.value == Skins.Material
                          ? FontWeight.w500
                          : FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // Reaction overlay paints above every cell so badges aren't covered by neighbors.
    final reactionLayer = SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        moreCount: moreCount,
        cellBuilder: (index, width, height, cellMoreCount) {
          // Overflow "+N" cell is a see-more control, not attachment 4; hide its tapbacks.
          if (cellMoreCount != null && cellMoreCount > 0) {
            return const SizedBox.shrink();
          }
          // Author-edge with a tighter overhang so badges stay nearer their cell.
          return CollectionAttachmentReactions(
            collectionPart: messagePart,
            attachmentIndex: index,
            tightOverhang: true,
            tailType: SettingsSvc.settings.skin.value == Skins.iOS
                ? ReactionTailType.inside
                : ReactionTailType.standard,
          );
        },
      ),
    );

    final grid = Stack(
      clipBehavior: Clip.none,
      children: [
        imageLayer,
        Positioned.fill(child: reactionLayer),
      ],
    );

    return CollectionDownloadButton.wrap(
      isFromMe: isFromMe,
      contentWidth: gridWidth,
      contentHeight: gridHeight,
      attachments: _attachments,
      child: grid,
    );
  }

  double _gridHeight(int count, double gridWidth) {
    if (count == 2) return gridWidth;
    if (count == 3) {
      return gridWidth / _topRowAspect + _gap + gridWidth * _bottomRowHeightRatio;
    }
    if (count == 4) {
      final cellSize = (gridWidth - _gap) / 2;
      return 2 * cellSize + _gap;
    }
    final stackCount = min(count, 5) - 2;
    final colWidth = _columnWidth(gridWidth);
    final bottomHeight = stackCount * colWidth + (stackCount - 1) * _gap;
    return gridWidth / _topRowAspect + _gap + bottomHeight;
  }

  Widget _buildCellLayout({
    required int count,
    required double gridWidth,
    required Widget Function(int index, double width, double height, int? moreCount) cellBuilder,
    Widget? Function(int index, double width, double height, int? moreCount)? moreOverlayBuilder,
    int? moreCount,
  }) {
    Widget gap({bool horizontal = false}) {
      return horizontal ? const SizedBox(width: _gap) : const SizedBox(height: _gap, width: double.infinity);
    }

    Widget buildCell(int index, double width, double height, {int? cellMoreCount}) {
      final overlay = moreOverlayBuilder?.call(index, width, height, cellMoreCount);
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            cellBuilder(index, width, height, cellMoreCount),
            if (overlay != null) Positioned.fill(child: overlay),
          ],
        ),
      );
    }

    if (count == 2) {
      final cellWidth = (gridWidth - _gap) / 2;
      final cellHeight = gridWidth;
      return Row(
        children: [
          buildCell(0, cellWidth, cellHeight),
          gap(horizontal: true),
          buildCell(1, cellWidth, cellHeight),
        ],
      );
    }

    if (count == 3) {
      final topHeight = gridWidth / _topRowAspect;
      final bottomHeight = gridWidth * _bottomRowHeightRatio;
      final bottomCellWidth = (gridWidth - _gap) / 2;
      return Column(
        children: [
          buildCell(0, gridWidth, topHeight),
          gap(),
          Row(
            children: [
              buildCell(1, bottomCellWidth, bottomHeight),
              gap(horizontal: true),
              buildCell(2, bottomCellWidth, bottomHeight),
            ],
          ),
        ],
      );
    }

    if (count == 4) {
      final cellSize = (gridWidth - _gap) / 2;
      return Column(
        children: [
          Row(
            children: [
              buildCell(0, cellSize, cellSize),
              gap(horizontal: true),
              buildCell(1, cellSize, cellSize),
            ],
          ),
          gap(),
          Row(
            children: [
              buildCell(2, cellSize, cellSize),
              gap(horizontal: true),
              buildCell(3, cellSize, cellSize),
            ],
          ),
        ],
      );
    }

    // 5+: hero top + 3-column bottom (item 1 spans 2 cols; stack is 1:1 squares).
    final visibleCount = min(count, 5);
    final stackCount = visibleCount - 2;
    final colWidth = _columnWidth(gridWidth);
    final bottomHeight = stackCount * colWidth + (stackCount - 1) * _gap;
    final spanWidth = 2 * colWidth + _gap;
    final topHeight = gridWidth / _topRowAspect;

    return Column(
      children: [
        buildCell(0, gridWidth, topHeight),
        gap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildCell(1, spanWidth, bottomHeight),
            gap(horizontal: true),
            SizedBox(
              width: colWidth,
              height: bottomHeight,
              child: Column(
                children: [
                  for (int i = 2; i < visibleCount; i++) ...[
                    if (i > 2) gap(),
                    buildCell(
                      i,
                      colWidth,
                      colWidth,
                      cellMoreCount: i == 4 ? moreCount : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
          boxShadow: SettingsSvc.settings.skin.value == Skins.iOS
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }

  /// Per-cell clip: only silhouette corners get radius from [silhouette]; shared edges stay square.
  BorderRadius _cellBorderRadius(int count, int index, BorderRadius silhouette) {
    if (count == 2) {
      if (index == 0) {
        return BorderRadius.only(topLeft: silhouette.topLeft, bottomLeft: silhouette.bottomLeft);
      }
      return BorderRadius.only(topRight: silhouette.topRight, bottomRight: silhouette.bottomRight);
    }
    if (count == 3) {
      if (index == 0) {
        return BorderRadius.only(topLeft: silhouette.topLeft, topRight: silhouette.topRight);
      }
      if (index == 1) return BorderRadius.only(bottomLeft: silhouette.bottomLeft);
      return BorderRadius.only(bottomRight: silhouette.bottomRight);
    }
    if (count == 4) {
      if (index == 0) return BorderRadius.only(topLeft: silhouette.topLeft);
      if (index == 1) return BorderRadius.only(topRight: silhouette.topRight);
      if (index == 2) return BorderRadius.only(bottomLeft: silhouette.bottomLeft);
      return BorderRadius.only(bottomRight: silhouette.bottomRight);
    }
    // 5+: hero top + span + stack
    if (index == 0) {
      return BorderRadius.only(topLeft: silhouette.topLeft, topRight: silhouette.topRight);
    }
    if (index == 1) return BorderRadius.only(bottomLeft: silhouette.bottomLeft);
    final lastVisible = min(count, 5) - 1;
    if (index == lastVisible) return BorderRadius.only(bottomRight: silhouette.bottomRight);
    return BorderRadius.zero;
  }
}
