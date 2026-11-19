import 'package:bluebubbles/helpers/types/helpers/pin_order_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

PinMigrationChat _chat(String guid, {bool pinned = false, int? index, int? latest}) => (
      guid: guid,
      isPinned: pinned,
      pinIndex: index,
      latestMessageDate: latest == null ? null : DateTime.fromMillisecondsSinceEpoch(latest),
    );

/// Sorts chats described as (guid, pinned, index) by [comparePinOrder], breaking ties by guid.
List<String> _sorted(List<(String, bool, int?)> chats) {
  final sorted = [...chats]
    ..sort((a, b) {
      final byPin = comparePinOrder(aPinned: a.$2, aIndex: a.$3, bPinned: b.$2, bIndex: b.$3);
      return byPin != 0 ? byPin : a.$1.compareTo(b.$1);
    });
  return sorted.map((c) => c.$1).toList();
}

void main() {
  group('mergePinOrder', () {
    test('a full reorder replaces the order', () {
      expect(mergePinOrder(['a', 'b', 'c'], ['c', 'a', 'b']), ['c', 'a', 'b']);
    });

    test('pins left out of a filtered view keep their positions', () {
      // b and d are hidden by a filter; the visible a, c, e are reordered to e, a, c.
      expect(mergePinOrder(['a', 'b', 'c', 'd', 'e'], ['e', 'a', 'c']), ['e', 'b', 'a', 'd', 'c']);
    });

    test('an unchanged visible subset leaves the order alone', () {
      expect(mergePinOrder(['a', 'b', 'c', 'd'], ['b', 'd']), ['a', 'b', 'c', 'd']);
    });

    test('guids that are not pins, and repeats, are ignored', () {
      expect(mergePinOrder(['a', 'b', 'c'], ['x', 'c', 'c', 'a']), ['c', 'b', 'a']);
    });

    test('no visible pins leaves the order alone', () {
      expect(mergePinOrder(['a', 'b'], []), ['a', 'b']);
    });
  });

  group('comparePinOrder', () {
    test('indexed pins sort by index', () {
      expect(_sorted([('a', true, 2), ('b', true, 0), ('c', true, 1)]), ['b', 'c', 'a']);
    });

    test('unindexed pins sort after indexed ones', () {
      expect(_sorted([('a', true, null), ('b', true, 5), ('c', true, 0)]), ['c', 'b', 'a']);
    });

    test('unpinned chats sort after every pin', () {
      expect(_sorted([('a', false, null), ('b', true, null), ('c', false, 0), ('d', true, 3)]), ['d', 'b', 'a', 'c']);
    });

    test('ties are left to the caller', () {
      expect(comparePinOrder(aPinned: false, bPinned: false), 0);
      expect(comparePinOrder(aPinned: false, aIndex: 1, bPinned: false, bIndex: 0), 0);
      expect(comparePinOrder(aPinned: true, aIndex: 1, bPinned: true, bIndex: 1), 0);
      expect(comparePinOrder(aPinned: true, bPinned: true), 0);
    });
  });

  group('migratePinIndexes', () {
    test('indexed pins first by index, then unindexed by latest message, newest first', () {
      final indexes = migratePinIndexes([
        _chat('old', pinned: true, latest: 100),
        _chat('second', pinned: true, index: 7),
        _chat('new', pinned: true, latest: 300),
        _chat('first', pinned: true, index: 2),
        _chat('never', pinned: true),
      ]);
      expect(indexes, {'first': 0, 'second': 1, 'new': 2, 'old': 3, 'never': 4});
    });

    test('unpinned chats lose any index they kept', () {
      final indexes = migratePinIndexes([
        _chat('stale', index: 0, latest: 500),
        _chat('pin', pinned: true, index: 4),
        _chat('plain'),
      ]);
      expect(indexes, {'stale': null, 'pin': 0, 'plain': null});
    });

    test('no chats, no indexes', () {
      expect(migratePinIndexes([]), isEmpty);
    });
  });
}
