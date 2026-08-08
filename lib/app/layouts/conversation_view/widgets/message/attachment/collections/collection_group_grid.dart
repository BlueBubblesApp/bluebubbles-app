import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
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

  /// One column of the 5+ bottom row (3 columns with two gaps).
  double _columnWidth(double gridWidth) => (gridWidth - 2 * _gap) / 3;

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final isFromMe = messageState.isFromMe.value;
    final count = _attachments.length;
    final cardRadius = _cardRadius;
    // Calculated against screen width; maxGridWidth caps size on larger screens.
    final gridWidth = min(
      NavigationSvc.width(context) * _maxGridSizeFactor,
      _maxGridWidth,
    );
    final gridHeight = _gridHeight(count, gridWidth);

    final grid = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      cardRadius: cardRadius,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        cellBuilder: (index, width, height) => ClipRRect(
          borderRadius: _cellBorderRadius(count, index, cardRadius),
          child: CollectionAttachmentCard(
            attachment: _attachments[index],
            attachmentIndex: index,
            messagePart: messagePart,
            galleryAttachments: _attachments,
            cvController: cvController,
            isEditing: isEditing,
            enableGestures: true,
          ),
        ),
      ),
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
    required Widget Function(int index, double width, double height) cellBuilder,
  }) {
    Widget gap({bool horizontal = false}) {
      return horizontal ? const SizedBox(width: _gap) : const SizedBox(height: _gap, width: double.infinity);
    }

    Widget buildCell(int index, double width, double height) {
      return SizedBox(
        width: width,
        height: height,
        child: cellBuilder(index, width, height),
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
                    buildCell(i, colWidth, colWidth),
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
