import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_grid_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _eps = 0.001;
const double _gap = CollectionGridLayout.gap;
const int _maxCollapsed = CollectionGridLayout.maxCollapsedTiles;
const List<double> _widths = [240, 280, 320];

/// Width of one column of the shared 3-column grid.
double _column(double width) => (width - 2 * _gap) / 3;

void _expectRect(Rect actual, Rect expected, String reason) {
  expect(actual.left, closeTo(expected.left, _eps), reason: '$reason (left)');
  expect(actual.top, closeTo(expected.top, _eps), reason: '$reason (top)');
  expect(actual.width, closeTo(expected.width, _eps), reason: '$reason (width)');
  expect(actual.height, closeTo(expected.height, _eps), reason: '$reason (height)');
}

Rect _rectOf(CollectionGridLayout layout, int index) => layout.cells.singleWhere((c) => c.index == index).rect;

void main() {
  group('CollectionGridLayout invariants', () {
    for (final expanded in [false, true]) {
      test(expanded ? 'expanded' : 'collapsed', () {
        for (var count = 2; count <= 40; count++) {
          for (final width in _widths) {
            final layout = CollectionGridLayout.compute(count: count, width: width, expanded: expanded);
            final reason = 'count=$count width=$width expanded=$expanded';
            final visible = expanded ? count : (count < _maxCollapsed ? count : _maxCollapsed);

            // One tile per visible attachment, each index exactly once, in 0..visible-1.
            expect(layout.cells.map((c) => c.index).toList()..sort(), List.generate(visible, (i) => i),
                reason: reason);
            expect(layout.width, width, reason: reason);

            // Tiles stay inside the grid, have positive size, and the grid is exactly as tall as its tiles.
            var bottom = 0.0;
            for (final cell in layout.cells) {
              final r = cell.rect;
              expect(r.width, greaterThan(0), reason: reason);
              expect(r.height, greaterThan(0), reason: reason);
              expect(r.left, greaterThanOrEqualTo(-_eps), reason: reason);
              expect(r.top, greaterThanOrEqualTo(-_eps), reason: reason);
              expect(r.right, lessThanOrEqualTo(width + _eps), reason: reason);
              if (r.bottom > bottom) bottom = r.bottom;
            }
            expect(layout.height, closeTo(bottom, _eps), reason: reason);

            // No two tiles overlap.
            for (var i = 0; i < layout.cells.length; i++) {
              for (var j = i + 1; j < layout.cells.length; j++) {
                final overlap = layout.cells[i].rect.intersect(layout.cells[j].rect);
                final overlaps = overlap.width > _eps && overlap.height > _eps;
                final pair = '${layout.cells[i].index} and ${layout.cells[j].index}';
                expect(overlaps, isFalse, reason: '$reason: tiles $pair');
              }
            }

            // Only the first tile (the banner, or the first of two) spans the full width: no orphan tiles.
            for (final cell in layout.cells.where((c) => c.rect.width > width - _eps)) {
              expect(cell.index, 0, reason: '$reason: full-width tile ${cell.index}');
            }

            // `+N` sits on the last visible tile exactly when a collapsed grid hides attachments.
            final withMore = layout.cells.where((c) => c.moreCount != null).toList();
            if (!expanded && count > _maxCollapsed) {
              expect(withMore, hasLength(1), reason: reason);
              expect(withMore.single.index, _maxCollapsed - 1, reason: reason);
              expect(withMore.single.moreCount, count - _maxCollapsed, reason: reason);
            } else {
              expect(withMore, isEmpty, reason: reason);
            }
          }
        }
      });
    }

    test('expanding never changes a grid that fits without the +N tile', () {
      for (var count = 2; count <= _maxCollapsed; count++) {
        final collapsed = CollectionGridLayout.compute(count: count, width: 280, expanded: false);
        final expanded = CollectionGridLayout.compute(count: count, width: 280, expanded: true);
        expect(expanded.height, collapsed.height, reason: 'count=$count');
        for (var i = 0; i < count; i++) {
          _expectRect(_rectOf(expanded, i), _rectOf(collapsed, i), 'count=$count index=$i');
        }
      }
    });
  });

  group('CollectionGridLayout shapes', () {
    const width = 280.0;
    final col = _column(width);
    // A hero beside a stack of two squares is two squares (plus one gap) tall; the banner is 4:3 of that.
    final heroStack2Height = 2 * col + _gap;
    final bannerHeight = heroStack2Height * CollectionGridLayout.bannerAspect;

    test('2 items: one row of two, 4:3 tall', () {
      final layout = CollectionGridLayout.compute(count: 2, width: width, expanded: false);
      const cellWidth = (width - _gap) / 2;
      const height = width / CollectionGridLayout.bannerAspect;
      _expectRect(_rectOf(layout, 0), const Rect.fromLTWH(0, 0, cellWidth, height), 'index 0');
      _expectRect(_rectOf(layout, 1), const Rect.fromLTWH(cellWidth + _gap, 0, cellWidth, height), 'index 1');
      expect(layout.height, closeTo(height, _eps));
    });

    test('3 items: banner over two squares', () {
      final layout = CollectionGridLayout.compute(count: 3, width: width, expanded: false);
      const square = (width - _gap) / 2;
      _expectRect(_rectOf(layout, 0), Rect.fromLTWH(0, 0, width, bannerHeight), 'banner');
      _expectRect(_rectOf(layout, 1), Rect.fromLTWH(0, bannerHeight + _gap, square, square), 'index 1');
      _expectRect(_rectOf(layout, 2), Rect.fromLTWH(square + _gap, bannerHeight + _gap, square, square), 'index 2');
      expect(layout.height, closeTo(bannerHeight + _gap + square, _eps));
    });

    test('4 items: banner over a hero with two squares beside it', () {
      final layout = CollectionGridLayout.compute(count: 4, width: width, expanded: false);
      final top = bannerHeight + _gap;
      final heroWidth = 2 * col + _gap;
      _expectRect(_rectOf(layout, 0), Rect.fromLTWH(0, 0, width, bannerHeight), 'banner');
      _expectRect(_rectOf(layout, 1), Rect.fromLTWH(0, top, heroWidth, heroStack2Height), 'hero');
      _expectRect(_rectOf(layout, 2), Rect.fromLTWH(heroWidth + _gap, top, col, col), 'stack 1');
      _expectRect(_rectOf(layout, 3), Rect.fromLTWH(heroWidth + _gap, top + col + _gap, col, col), 'stack 2');
      expect(layout.height, closeTo(top + heroStack2Height, _eps));
    });

    test('expanded grids alternate the hero side', () {
      // 9 items expanded: banner, hero + 2 squares (hero left), row of 2, then hero + 2 squares mirrored (hero right,
      // and last: index 8).
      final layout = CollectionGridLayout.compute(count: 9, width: width, expanded: true);
      final firstHero = _rectOf(layout, 1);
      final secondHero = _rectOf(layout, 8);
      expect(firstHero.left, closeTo(0, _eps));
      expect(secondHero.left, closeTo(col + _gap, _eps));
      expect(secondHero.width, closeTo(2 * col + _gap, _eps));
    });
  });
}
