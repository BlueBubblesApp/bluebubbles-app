import 'dart:math';

import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
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

typedef _CellBuilder = Widget Function(int index, double width, double height, int? moreCount);

/// Google Messages–style grid for multi-attachment media collections.
///
/// Layouts are composed from three shapes on a shared 3-column unit:
/// banner, hero+stack, and square row (see [_buildCellLayout] recipes).
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
  static const double _maxGridSizeFactor = 0.75; // temporary: match bubble width
  static const double _maxGridWidth = 280.0;
  static const double _bannerAspect = 4 / 3;

  List<Attachment> get _attachments => messagePart.attachments;

  /// Outer silhouette radius by skin (Samsung settings cards use 25; Material M3E `lg`).
  double get _cardRadius {
    switch (SettingsSvc.settings.skin.value) {
      case Skins.Samsung:
        return 25.0;
      case Skins.iOS:
        // Match iOS attachment / collection card corners (CollectionAttachmentCard).
        return 20.0;
      case Skins.Material:
        return M3EShapes.lg;
    }
  }

  /// Author-edge radius when the grid sits flush against subject / body.
  /// Material matches [TailClipper] (5). Samsung stays softer against its 25 outer radius.
  double get _connectedCornerRadius {
    switch (SettingsSvc.settings.skin.value) {
      case Skins.Samsung:
        return 12.0;
      case Skins.iOS:
      case Skins.Material:
        return 5.0;
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
  /// subject (top) / body (bottom). Non-author corners keep the full card radius.
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

  double _columnWidth(double gridWidth) => (gridWidth - 2 * _gap) / 3;

  double _heroStackHeight(double gridWidth, int stackCount) {
    final col = _columnWidth(gridWidth);
    return stackCount * col + (stackCount - 1) * _gap;
  }

  double _squareRowCellSize(double gridWidth, int cellCount) =>
      (gridWidth - (cellCount - 1) * _gap) / cellCount;

  /// Full-width banner height: always [HeroStack](2) × [_bannerAspect].
  double _bannerHeight(double gridWidth) => _heroStackHeight(gridWidth, 2) * _bannerAspect;

  /// Visible tile count before `+N` overflow (collections are 2+).
  int _visibleTileCount(int count) => switch (count) {
        2 || 3 || 4 || 5 || 6 => count,
        _ => 7,
      };

  double _gridHeight(int count, double gridWidth) {
    final banner = _bannerHeight(gridWidth);
    return switch (count) {
      2 => gridWidth / _bannerAspect,
      3 => banner + _gap + _squareRowCellSize(gridWidth, 2),
      4 => banner + _gap + _heroStackHeight(gridWidth, 2),
      5 => banner + _gap + _heroStackHeight(gridWidth, 3),
      6 => banner +
          _gap +
          _heroStackHeight(gridWidth, 2) +
          _gap +
          _squareRowCellSize(gridWidth, 2),
      // 7+: Banner + HeroStack(3) + SquareRow(2)
      _ => banner +
          _gap +
          _heroStackHeight(gridWidth, 3) +
          _gap +
          _squareRowCellSize(gridWidth, 2),
    };
  }

  void _openSeeMoreFullscreen(BuildContext context) {
    // Interim: open the fullscreen carousel on the covered overflow tile,
    // not the PR6 overview page.
    final overflowIndex = _visibleTileCount(_attachments.length) - 1;
    final attachment = _attachments[overflowIndex];
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
      connectedRadius: _connectedCornerRadius,
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
    final visibleCount = _visibleTileCount(count);
    final moreCount = count > visibleCount ? count - visibleCount : null;

    // Media layer: outer clip owns the silhouette; cells fill square.
    final imageLayer = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      borderRadius: silhouette,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        moreCount: moreCount,
        cellBuilder: (index, width, height, cellMoreCount) => CollectionAttachmentCard(
          attachment: _attachments[index],
          attachmentIndex: index,
          messagePart: messagePart,
          galleryAttachments: _attachments,
          cvController: cvController,
          isEditing: isEditing,
          enableGestures: true,
          hideReactions: true,
          showCardShadow: false,
          // Outer grid ClipRRect owns silhouette corners; keep media square inside.
          mediaClipBorderRadius: BorderRadius.zero,
        ),
        moreOverlayBuilder: (index, width, height, cellMoreCount) {
          if (cellMoreCount == null || cellMoreCount <= 0) return null;
          return GestureDetector(
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
          // Overflow "+N" cell is a see-more control; hide its tapbacks.
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

  Widget _buildCellLayout({
    required int count,
    required double gridWidth,
    required _CellBuilder cellBuilder,
    Widget? Function(int index, double width, double height, int? moreCount)? moreOverlayBuilder,
    int? moreCount,
  }) {
    Widget cell(int index, double width, double height, {int? cellMoreCount}) {
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

    Widget hGap() => const SizedBox(width: _gap);
    Widget vGap() => const SizedBox(height: _gap, width: double.infinity);

    // Full-width banner; height is always HeroStack(2) × [_bannerAspect].
    Widget banner(int index, {int? cellMoreCount}) {
      return cell(index, gridWidth, _bannerHeight(gridWidth), cellMoreCount: cellMoreCount);
    }

    // Left tall hero (2 cols) + right column of [stackCount] 1:1 squares.
    Widget heroStack(int startIndex, int stackCount, {int? moreOnLast}) {
      final col = _columnWidth(gridWidth);
      final heroWidth = 2 * col + _gap;
      final h = _heroStackHeight(gridWidth, stackCount);
      final lastIndex = startIndex + stackCount;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(startIndex, heroWidth, h, cellMoreCount: startIndex == lastIndex ? moreOnLast : null),
          hGap(),
          SizedBox(
            width: col,
            height: h,
            child: Column(
              children: [
                for (int i = 0; i < stackCount; i++) ...[
                  if (i > 0) vGap(),
                  cell(
                    startIndex + 1 + i,
                    col,
                    col,
                    cellMoreCount: startIndex + 1 + i == lastIndex ? moreOnLast : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Full-width row of equal cells. [rowHeight] null → square cells.
    Widget squareRow(int startIndex, int cellCount, {double? rowHeight, int? moreOnLast}) {
      final cellWidth = _squareRowCellSize(gridWidth, cellCount);
      final cellHeight = rowHeight ?? cellWidth;
      final lastIndex = startIndex + cellCount - 1;
      return Row(
        children: [
          for (int i = 0; i < cellCount; i++) ...[
            if (i > 0) hGap(),
            cell(
              startIndex + i,
              cellWidth,
              cellHeight,
              cellMoreCount: startIndex + i == lastIndex ? moreOnLast : null,
            ),
          ],
        ],
      );
    }

    return switch (count) {
      2 => squareRow(0, 2, rowHeight: gridWidth / _bannerAspect),
      3 => Column(
          children: [
            banner(0),
            vGap(),
            squareRow(1, 2),
          ],
        ),
      4 => Column(
          children: [
            banner(0),
            vGap(),
            heroStack(1, 2),
          ],
        ),
      5 => Column(
          children: [
            banner(0),
            vGap(),
            heroStack(1, 3),
          ],
        ),
      6 => Column(
          children: [
            banner(0),
            vGap(),
            heroStack(1, 2),
            vGap(),
            squareRow(4, 2),
          ],
        ),
      // 7+: Banner + HeroStack(3) + SquareRow(2); +N on last tile when count > 7.
      _ => Column(
          children: [
            banner(0),
            vGap(),
            heroStack(1, 3),
            vGap(),
            squareRow(5, 2, moreOnLast: moreCount),
          ],
        ),
    };
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
        // Clip media to the silhouette; cells stay square and fill.
        child: ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}
