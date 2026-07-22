import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collection_attachment_card.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Grid layout for multi-attachment media collections (Material / Samsung skins).
///
/// Google Messages–style collage inside a single rounded card with gap-separated
/// cells. Per-attachment tapbacks render in a sibling overlay layer so they can
/// overflow the card (matching iOS collage behavior). Up to five attachments are
/// shown; the fifth cell may show a "+N" overlay.
///
/// Layouts: 2 side-by-side squares; 3 with a prominent top row; 4 as a 2×2;
/// 5+ with a prominent top row and a 3-column bottom row (2nd item spans two
/// columns; remaining items are 1:1 squares stacked in the third column).
class MessageImageGrid extends StatelessWidget {
  const MessageImageGrid({
    super.key,
    required this.messagePart,
    required this.cvController,
    this.isEditing = false,
  });

  final MessagePart messagePart;
  final ConversationViewController cvController;
  final bool isEditing;

  static const double _gap = 2.0;
  static const double _topRowAspect = 4 / 3;
  /// Bottom-row height as a fraction of grid width (3-item layout only).
  static const double _bottomRowHeightRatio = 0.45;
  static const double _iosCardRadius = 8.0;
  static const double _materialCardRadius = 16.0;
  /// Matches [TailClipper] author-side inset on Material bubbles.
  static const double _materialTailInset = 10.0;

  List<Attachment> get _attachments => messagePart.attachments;

  double get _cardRadius =>
      SettingsSvc.settings.skin.value == Skins.iOS ? _iosCardRadius : _materialCardRadius;

  /// One column of the 5+ bottom row (3 columns with two gaps).
  double _columnWidth(double gridWidth) => (gridWidth - 2 * _gap) / 3;

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final isFromMe = messageState.isFromMe.value;
    final count = _attachments.length;
    final cardRadius = _cardRadius;
    final gridWidth = NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor;
    final gridHeight = _gridHeight(count, gridWidth);
    final moreCount = count > 5 ? count - 5 : null;

    final imageLayer = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      cardRadius: cardRadius,
      child: _buildCellLayout(
        context,
        count: count,
        gridWidth: gridWidth,
        showGapDividers: true,
        cellBuilder: (index, width, height, cellMoreCount) => ClipRRect(
          borderRadius: _cellBorderRadius(count, index, cardRadius),
          child: CollectionAttachmentCard(
            controller: messageState,
            cvController: cvController,
            collectionPart: messagePart,
            attachmentIndex: index,
            collectionAttachments: _attachments,
            isEditing: isEditing,
            inGridCell: true,
            hideReactions: true,
          ),
        ),
        moreOverlayBuilder: (index, width, height, cellMoreCount) {
          if (cellMoreCount == null || cellMoreCount <= 0) return null;
          return ClipRRect(
            borderRadius: _cellBorderRadius(count, index, cardRadius),
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$cellMoreCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        moreCount: moreCount,
      ),
    );

    final reactionLayer = SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: _buildCellLayout(
        context,
        count: count,
        gridWidth: gridWidth,
        showGapDividers: false,
        cellBuilder: (index, width, height, _) => CollectionAttachmentReactions(
          collectionPart: messagePart,
          attachmentIndex: index,
        ),
        moreCount: moreCount,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isFromMe ? 0 : _materialTailInset,
        right: isFromMe ? _materialTailInset : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          imageLayer,
          Positioned.fill(child: reactionLayer),
        ],
      ),
    );
  }

  double _gridHeight(int count, double gridWidth) {
    if (count == 2) return (gridWidth - _gap) / 2;
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

  Widget _buildCellLayout(
    BuildContext context, {
    required int count,
    required double gridWidth,
    required bool showGapDividers,
    required Widget Function(int index, double width, double height, int? moreCount) cellBuilder,
    Widget? Function(int index, double width, double height, int? moreCount)? moreOverlayBuilder,
    int? moreCount,
  }) {
    Widget gap({bool horizontal = false}) {
      if (!showGapDividers) {
        return horizontal ? const SizedBox(width: _gap) : const SizedBox(height: _gap, width: double.infinity);
      }
      final color = Theme.of(context).colorScheme.outline.withValues(alpha: 0.18);
      if (horizontal) {
        return ColoredBox(color: color, child: const SizedBox(width: _gap));
      }
      return ColoredBox(color: color, child: const SizedBox(height: _gap, width: double.infinity));
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
      final cellHeight = cellWidth;
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
    required double cardRadius,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(cardRadius),
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

  BorderRadius _cellBorderRadius(int count, int index, double cardRadius) {
    final r = Radius.circular(cardRadius);
    if (count == 2) {
      if (index == 0) return BorderRadius.only(topLeft: r, bottomLeft: r);
      return BorderRadius.only(topRight: r, bottomRight: r);
    }
    if (count == 3) {
      if (index == 0) return BorderRadius.only(topLeft: r, topRight: r);
      if (index == 1) return BorderRadius.only(bottomLeft: r);
      return BorderRadius.only(bottomRight: r);
    }
    if (count == 4) {
      if (index == 0) return BorderRadius.only(topLeft: r);
      if (index == 1) return BorderRadius.only(topRight: r);
      if (index == 2) return BorderRadius.only(bottomLeft: r);
      return BorderRadius.only(bottomRight: r);
    }
    // 5+: hero top + span + stack
    if (index == 0) return BorderRadius.only(topLeft: r, topRight: r);
    if (index == 1) return BorderRadius.only(bottomLeft: r);
    final lastVisible = min(count, 5) - 1;
    if (index == lastVisible) return BorderRadius.only(bottomRight: r);
    return BorderRadius.zero;
  }
}
