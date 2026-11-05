import 'package:flutter/widgets.dart';

/// One tile of a [CollectionGridLayout]: which attachment goes where.
@immutable
class CollectionGridCell {
  const CollectionGridCell(this.index, this.rect, {this.moreCount});

  /// Index into the collection's attachments.
  final int index;

  /// Frame relative to the grid's top-left corner.
  final Rect rect;

  /// When set, this tile is the last visible one and shows "+[moreCount]" for the attachments not displayed.
  final int? moreCount;
}

/// Pure geometry for `CollectionGroupGrid`: packs attachments into tiles on a shared 3-column grid.
///
/// Google Messages–style. Built from three composable shapes: a wide banner, a tall hero with a vertical
/// stack of squares beside it, and a row of equal squares. Collapsed grids show at most [maxCollapsedTiles]
/// tiles, with a `+N` overlay on the last one. Expanded layouts keep an alternating hero / row rhythm (hero
/// facing flips each time) and avoid leaving a single orphan tile.
///
/// No widgets or settings here, so the packing can be reasoned about (and tested) on its own.
@immutable
class CollectionGridLayout {
  const CollectionGridLayout._(this.width, this.height, this.cells);

  static const double gap = 2.0;

  /// Banner (and the two-item row) aspect ratio, width:height.
  static const double bannerAspect = 4 / 3;

  /// A collapsed grid shows this many tiles at most; the rest are summarized by a `+N` tile.
  static const int maxCollapsedTiles = 7;

  /// Lays out [count] attachments in a grid [width] wide. [expanded] shows every attachment instead of
  /// stopping at [maxCollapsedTiles].
  factory CollectionGridLayout.compute({required int count, required double width, required bool expanded}) {
    final builder = _GridBuilder(width);
    if (count == 2) {
      builder.squareRow(0, 2, rowHeight: width / bannerAspect);
    } else {
      final segments = _segmentsFor(count, expanded: expanded);
      final moreCount = (!expanded && count > maxCollapsedTiles) ? count - maxCollapsedTiles : null;
      var heroOrdinal = 0;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final moreOnLast = i == segments.length - 1 ? moreCount : null;
        switch (segment.kind) {
          case _SegmentKind.banner:
            builder.banner(segment.startIndex, moreCount: moreOnLast);
          case _SegmentKind.heroStack:
            builder.heroStack(segment.startIndex, segment.param,
                moreOnLast: moreOnLast, mirrored: (heroOrdinal++).isOdd);
          case _SegmentKind.squareRow:
            builder.squareRow(segment.startIndex, segment.param, moreOnLast: moreOnLast);
        }
      }
    }
    return CollectionGridLayout._(width, builder.height, List.unmodifiable(builder.cells));
  }

  final double width;
  final double height;
  final List<CollectionGridCell> cells;
}

/// Appends segments top to bottom, separated by [CollectionGridLayout.gap].
class _GridBuilder {
  _GridBuilder(this.width);

  static const double _gap = CollectionGridLayout.gap;

  final double width;
  final List<CollectionGridCell> cells = [];
  double height = 0;

  double get _columnWidth => (width - 2 * _gap) / 3;

  double _heroStackHeight(int stackCount) => stackCount * _columnWidth + (stackCount - 1) * _gap;

  /// Starts a new segment and returns its top edge.
  double _nextTop(double segmentHeight) {
    final top = cells.isEmpty ? 0.0 : height + _gap;
    height = top + segmentHeight;
    return top;
  }

  void _add(int index, double left, double top, double w, double h, {int? moreCount}) =>
      cells.add(CollectionGridCell(index, Rect.fromLTWH(left, top, w, h), moreCount: moreCount));

  void banner(int index, {int? moreCount}) {
    final h = _heroStackHeight(2) * CollectionGridLayout.bannerAspect;
    _add(index, 0, _nextTop(h), width, h, moreCount: moreCount);
  }

  /// A hero tile (two columns wide) beside a vertical stack of [stackCount] squares. [mirrored] puts the
  /// stack on the left and the hero last.
  void heroStack(int startIndex, int stackCount, {int? moreOnLast, bool mirrored = false}) {
    final col = _columnWidth;
    final heroWidth = 2 * col + _gap;
    final h = _heroStackHeight(stackCount);
    final top = _nextTop(h);
    final heroIndex = mirrored ? startIndex + stackCount : startIndex;
    final stackBase = mirrored ? startIndex : startIndex + 1;
    final lastIndex = startIndex + stackCount;
    final heroLeft = mirrored ? col + _gap : 0.0;
    final stackLeft = mirrored ? 0.0 : heroWidth + _gap;

    _add(heroIndex, heroLeft, top, heroWidth, h, moreCount: heroIndex == lastIndex ? moreOnLast : null);
    for (var i = 0; i < stackCount; i++) {
      final index = stackBase + i;
      _add(index, stackLeft, top + i * (col + _gap), col, col, moreCount: index == lastIndex ? moreOnLast : null);
    }
  }

  /// [cellCount] equal tiles in a row; square unless [rowHeight] is given.
  void squareRow(int startIndex, int cellCount, {double? rowHeight, int? moreOnLast}) {
    final cellWidth = (width - (cellCount - 1) * _gap) / cellCount;
    final cellHeight = rowHeight ?? cellWidth;
    final top = _nextTop(cellHeight);
    final lastIndex = startIndex + cellCount - 1;
    for (var i = 0; i < cellCount; i++) {
      final index = startIndex + i;
      _add(index, i * (cellWidth + _gap), top, cellWidth, cellHeight,
          moreCount: index == lastIndex ? moreOnLast : null);
    }
  }
}

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

int _chunkSize(_Chunk c) => switch (c) {
      _Chunk.hs3 => 4,
      _Chunk.hs2 => 3,
      _Chunk.sr2 => 2,
    };

bool _isHero(_Chunk? c) => c == _Chunk.hs3 || c == _Chunk.hs2;

List<_Chunk>? _packSearch(
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
    _ when count == CollectionGridLayout.maxCollapsedTiles || !expanded => const [
        _LayoutSegment(_SegmentKind.banner, 0),
        _LayoutSegment(_SegmentKind.heroStack, 1, 3),
        _LayoutSegment(_SegmentKind.squareRow, 5, 2),
      ],
    _ => switch (count - CollectionGridLayout.maxCollapsedTiles) {
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
            ..._packOverflow(n, CollectionGridLayout.maxCollapsedTiles),
          ],
      },
  };
}
