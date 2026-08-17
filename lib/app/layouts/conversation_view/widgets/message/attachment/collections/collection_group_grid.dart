import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_download_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_title.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef _CellBuilder = Widget Function(int index, double width, double height, int? moreCount);

enum _SegmentKind { banner, heroStack, squareRow }

/// Pack units: HS(3)=4 items, HS(2)=3, SR(2)=2.
enum _Chunk { hs3, hs2, sr2 }

/// One composable shape. [param] is stackCount (hero) or cellCount (square row).
class _LayoutSegment {
  const _LayoutSegment(this.kind, this.startIndex, [this.param = 0]);

  final _SegmentKind kind;
  final int startIndex;
  final int param;
}

/// Google Messages–style grid for multi-attachment media collections.
///
/// Built from three composable shapes on a shared 3-column grid: a wide banner, a tall hero
/// with a vertical stack of squares beside it, and a row of equal squares. Collections
/// over 7 tiles show a `+N` overlay — tap opens the collection gallery, long-press expands
/// the remaining items in place. Expanded layouts keep an alternating hero / row rhythm
/// (hero facing flips each time) and avoid leaving a single orphan tile.
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

class _CollectionGroupGridState extends State<CollectionGroupGrid> {
  static const double _gap = 2.0;
  static const double _maxGridSizeFactor = 0.75; // temporary: match bubble width
  static const double _maxGridWidth = 280.0;
  static const double _bannerAspect = 4 / 3;
  static const Duration _expandAnimDuration = Duration(milliseconds: 320);

  bool _expanded = false;

  MessagePart get messagePart => widget.messagePart;
  ConversationViewController get cvController => widget.cvController;
  bool get isEditing => widget.isEditing;
  List<Attachment> get _attachments => messagePart.attachments;

  double get _cardRadius => CollectionAttachmentCard.mediaCardRadius;

  double get _connectedCornerRadius =>
      SettingsSvc.settings.skin.value == Skins.Samsung ? 12.0 : 5.0;

  bool _hasSubjectAbove(MessageState messageState) =>
      messageState.isLeadingMessagePart(messagePart) && !isNullOrEmpty(messageState.subject.value);

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

  double _columnWidth(double gridWidth) => (gridWidth - 2 * _gap) / 3;

  double _heroStackHeight(double gridWidth, int stackCount) {
    final col = _columnWidth(gridWidth);
    return stackCount * col + (stackCount - 1) * _gap;
  }

  double _squareRowCellSize(double gridWidth, int cellCount) =>
      (gridWidth - (cellCount - 1) * _gap) / cellCount;

  double _bannerHeight(double gridWidth) => _heroStackHeight(gridWidth, 2) * _bannerAspect;

  double _segmentHeight(_LayoutSegment segment, double gridWidth) => switch (segment.kind) {
        _SegmentKind.banner => _bannerHeight(gridWidth),
        _SegmentKind.heroStack => _heroStackHeight(gridWidth, segment.param),
        _SegmentKind.squareRow => _squareRowCellSize(gridWidth, segment.param),
      };

  double _heightForSegments(List<_LayoutSegment> segments, double gridWidth) {
    if (segments.isEmpty) return 0;
    return segments.skip(1).fold(
      _segmentHeight(segments.first, gridWidth),
      (h, s) => h + _gap + _segmentHeight(s, gridWidth),
    );
  }

  static int _chunkSize(_Chunk c) => switch (c) {
        _Chunk.hs3 => 4,
        _Chunk.hs2 => 3,
        _Chunk.sr2 => 2,
      };

  static bool _isHero(_Chunk? c) => c == _Chunk.hs3 || c == _Chunk.hs2;

  static List<_Chunk>? _packSearch(
    int remaining,
    _Chunk? previous,
    _Chunk? lastHero, {
    required bool allowAdjacentFlat,
    required bool allowAdjacentHero,
  }) {
    if (remaining == 0) return const [];
    if (remaining < 0 || remaining == 1) return null;

    final candidates = _isHero(previous)
        ? const [_Chunk.sr2]
        : [
            lastHero == _Chunk.hs3 ? _Chunk.hs2 : _Chunk.hs3,
            lastHero == _Chunk.hs3 ? _Chunk.hs3 : _Chunk.hs2,
            _Chunk.sr2,
          ];

    for (final chunk in candidates) {
      final take = _chunkSize(chunk);
      if (take > remaining) continue;
      if (_isHero(chunk) && _isHero(previous) && !allowAdjacentHero) continue;
      if (chunk == _Chunk.sr2 && previous == _Chunk.sr2 && !allowAdjacentFlat) continue;

      final rest = _packSearch(
        remaining - take,
        chunk,
        _isHero(chunk) ? chunk : lastHero,
        allowAdjacentFlat: allowAdjacentFlat,
        allowAdjacentHero: allowAdjacentHero,
      );
      if (rest != null) return [chunk, ...rest];
    }
    return null;
  }

  /// Pack [n] items after a kept SquareRow (so the search starts with a hero).
  List<_LayoutSegment> _packOverflow(int n, int startIndex) {
    if (n == 0) return const [];
    const previous = _Chunk.sr2;
    final chunks = _packSearch(n, previous, null, allowAdjacentFlat: false, allowAdjacentHero: false) ??
        _packSearch(n, previous, null, allowAdjacentFlat: true, allowAdjacentHero: false) ??
        _packSearch(n, previous, null, allowAdjacentFlat: true, allowAdjacentHero: true);
    assert(chunks != null, 'overflow packer failed for n=$n');

    final out = <_LayoutSegment>[];
    var index = startIndex;
    for (final chunk in chunks!) {
      out.add(chunk == _Chunk.sr2
          ? _LayoutSegment(_SegmentKind.squareRow, index, 2)
          : _LayoutSegment(_SegmentKind.heroStack, index, chunk == _Chunk.hs3 ? 3 : 2));
      index += _chunkSize(chunk);
    }
    return out;
  }

  List<_LayoutSegment> _segmentsFor(int count, {required bool expanded}) {
    return switch (count) {
      3 => const [
          _LayoutSegment(_SegmentKind.banner, 0),
          _LayoutSegment(_SegmentKind.squareRow, 1, 2),
        ],
      4 => const [
          _LayoutSegment(_SegmentKind.banner, 0),
          _LayoutSegment(_SegmentKind.heroStack, 1, 2),
        ],
      5 => const [
          _LayoutSegment(_SegmentKind.banner, 0),
          _LayoutSegment(_SegmentKind.heroStack, 1, 3),
        ],
      6 => const [
          _LayoutSegment(_SegmentKind.banner, 0),
          _LayoutSegment(_SegmentKind.heroStack, 1, 2),
          _LayoutSegment(_SegmentKind.squareRow, 4, 2),
        ],
      _ when count == 7 || !expanded => const [
          _LayoutSegment(_SegmentKind.banner, 0),
          _LayoutSegment(_SegmentKind.heroStack, 1, 3),
          _LayoutSegment(_SegmentKind.squareRow, 5, 2),
        ],
      _ => switch (count - 7) {
          1 => const [
              _LayoutSegment(_SegmentKind.banner, 0),
              _LayoutSegment(_SegmentKind.heroStack, 1, 3),
              _LayoutSegment(_SegmentKind.heroStack, 5, 2),
            ],
          2 => const [
              _LayoutSegment(_SegmentKind.banner, 0),
              _LayoutSegment(_SegmentKind.heroStack, 1, 2),
              _LayoutSegment(_SegmentKind.squareRow, 4, 2),
              _LayoutSegment(_SegmentKind.heroStack, 6, 2),
            ],
          final n => [
              const _LayoutSegment(_SegmentKind.banner, 0),
              const _LayoutSegment(_SegmentKind.heroStack, 1, 3),
              const _LayoutSegment(_SegmentKind.squareRow, 5, 2),
              ..._packOverflow(n, 7),
            ],
        },
    };
  }

  double _gridHeight(int count, double gridWidth, {required bool expanded}) {
    if (count == 2) return gridWidth / _bannerAspect;
    return _heightForSegments(_segmentsFor(count, expanded: expanded), gridWidth);
  }

  @override
  Widget build(BuildContext context) {
    final messageState = MessageStateScope.of(context);
    final collectionController = CollectionMediaController(
      chat: cvController.chat,
      media: _attachments,
      messageState: messageState,
      collectionPart: messagePart,
    );
    final isFromMe = messageState.isFromMe.value;
    final isIos = SettingsSvc.settings.skin.value == Skins.iOS;
    // Connected author-edge corners match text-bubble TailClipper: Material/Samsung only.
    final connectCorners = !isIos;
    final count = _attachments.length;
    final silhouette = _silhouetteBorderRadius(
      cardRadius: _cardRadius,
      connectedRadius: _connectedCornerRadius,
      isFromMe: isFromMe,
      tightenTop: connectCorners && _hasSubjectAbove(messageState),
      tightenBottom: connectCorners && _hasBodyBelow(messageState),
    );
    final gridWidth = min(NavigationSvc.width(context) * _maxGridSizeFactor, _maxGridWidth);
    final gridHeight = _gridHeight(count, gridWidth, expanded: _expanded);
    final moreCount = (!_expanded && count > 7) ? count - 7 : null;

    final imageLayer = _wrapGridCard(
      context,
      width: gridWidth,
      height: gridHeight,
      borderRadius: silhouette,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        moreCount: moreCount,
        expanded: _expanded,
        cellBuilder: (index, width, height, cellMoreCount) => CollectionAttachmentCard(
          attachment: _attachments[index],
          attachmentIndex: index,
          messagePart: messagePart,
          collectionController: collectionController,
          cvController: cvController,
          isEditing: isEditing,
          enableGestures: true,
          hideReactions: true,
          showCardShadow: false,
          mediaClipBorderRadius: BorderRadius.zero,
        ),
        moreOverlayBuilder: (index, width, height, cellMoreCount) {
          if (cellMoreCount == null || cellMoreCount <= 0) return null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => collectionController.openGallery(context),
            onLongPress: () {
              HapticFeedback.lightImpact();
              setState(() => _expanded = true);
            },
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

    final reactionLayer = SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: _buildCellLayout(
        count: count,
        gridWidth: gridWidth,
        moreCount: moreCount,
        expanded: _expanded,
        cellBuilder: (index, width, height, cellMoreCount) {
          if (cellMoreCount != null && cellMoreCount > 0) return const SizedBox.shrink();
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

    // iOS stack chrome: title above the card. Material/Samsung stay grid-only.
    if (!isIos) return gridBody;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CollectionTitle(
          label: collectionController.title,
          onTap: () => collectionController.openGallery(context),
        ),
        const SizedBox(height: 4),
        gridBody,
      ],
    );
  }

  Widget _buildCellLayout({
    required int count,
    required double gridWidth,
    required _CellBuilder cellBuilder,
    required bool expanded,
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

    Widget banner(int index, {int? cellMoreCount}) =>
        cell(index, gridWidth, _bannerHeight(gridWidth), cellMoreCount: cellMoreCount);

    Widget heroStack(int startIndex, int stackCount, {int? moreOnLast, bool mirrored = false}) {
      final col = _columnWidth(gridWidth);
      final heroWidth = 2 * col + _gap;
      final h = _heroStackHeight(gridWidth, stackCount);
      final heroIndex = mirrored ? startIndex + stackCount : startIndex;
      final stackBase = mirrored ? startIndex : startIndex + 1;
      final lastIndex = startIndex + stackCount;

      final hero = cell(heroIndex, heroWidth, h, cellMoreCount: heroIndex == lastIndex ? moreOnLast : null);
      final stack = SizedBox(
        width: col,
        height: h,
        child: Column(
          children: [
            for (int i = 0; i < stackCount; i++) ...[
              if (i > 0) vGap(),
              cell(
                stackBase + i,
                col,
                col,
                cellMoreCount: stackBase + i == lastIndex ? moreOnLast : null,
              ),
            ],
          ],
        ),
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mirrored ? [stack, hGap(), hero] : [hero, hGap(), stack],
      );
    }

    // Count 2 uses taller-than-square cells via [rowHeight].
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

    if (count == 2) return squareRow(0, 2, rowHeight: gridWidth / _bannerAspect);

    final segments = _segmentsFor(count, expanded: expanded);
    var heroOrdinal = 0;
    Widget buildSegment(_LayoutSegment segment, {int? moreOnLast}) => switch (segment.kind) {
          _SegmentKind.banner => banner(segment.startIndex, cellMoreCount: moreOnLast),
          _SegmentKind.heroStack => heroStack(
              segment.startIndex,
              segment.param,
              moreOnLast: moreOnLast,
              mirrored: (heroOrdinal++).isOdd,
            ),
          _SegmentKind.squareRow => squareRow(segment.startIndex, segment.param, moreOnLast: moreOnLast),
        };

    return Column(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) vGap(),
          buildSegment(segments[i], moreOnLast: i == segments.length - 1 ? moreCount : null),
        ],
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
        child: ClipRRect(borderRadius: borderRadius, child: child),
      ),
    );
  }
}
