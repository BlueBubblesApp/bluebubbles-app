/// The rules for ordering pinned chats, over guids, indexes and dates so they run without a database.
///
/// Used by `ChatsService` (sorting, reordering) and the version 11 migration in `Database`.
library;

/// Where a pin that somehow lacks an index sorts: after every indexed one, so it still shows instead of jumping to
/// the front.
const int unindexedPinIndex = 1 << 30;

/// Merges [visibleOrder], the pins the grid shows (possibly a filtered subset) in their new order, back into the
/// full [pinOrder].
///
/// The pins [visibleOrder] leaves out keep their positions; the visible ones fill the remaining positions in their
/// new order. Guids in [visibleOrder] that aren't pins, and repeats, are ignored.
List<String> mergePinOrder(List<String> pinOrder, List<String> visibleOrder) {
  final pins = pinOrder.toSet();
  final visible = visibleOrder.where(pins.contains).toSet();
  final reordered = visible.iterator;
  return [for (final guid in pinOrder) visible.contains(guid) ? (reordered..moveNext()).current : guid];
}

/// Orders pins before everything else, and pins by index with unindexed ones after the indexed.
///
/// Returns 0 when that leaves the two tied (both unpinned, or pins with the same index), for the caller to break by
/// latest message.
int comparePinOrder({required bool aPinned, int? aIndex, required bool bPinned, int? bIndex}) {
  if (aPinned != bPinned) return aPinned ? -1 : 1;
  if (!aPinned) return 0;
  return (aIndex ?? unindexedPinIndex).compareTo(bIndex ?? unindexedPinIndex);
}

/// A chat as the version 11 migration sees it.
typedef PinMigrationChat = ({String guid, bool isPinned, int? pinIndex, DateTime? latestMessageDate});

/// The index each of [chats] gets in the version 11 migration, where every pin gets one.
///
/// Pins that had an index come first, in index order; pins without one follow by latest message, newest first;
/// unpinned chats map to null, dropping any index they kept.
Map<String, int?> migratePinIndexes(List<PinMigrationChat> chats) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final pinned = chats.where((c) => c.isPinned).toList()
    ..sort((a, b) {
      final byIndex = comparePinOrder(aPinned: true, aIndex: a.pinIndex, bPinned: true, bIndex: b.pinIndex);
      if (byIndex != 0) return byIndex;
      return (b.latestMessageDate ?? epoch).compareTo(a.latestMessageDate ?? epoch);
    });
  return {
    for (final chat in chats) chat.guid: null,
    for (final (i, chat) in pinned.indexed) chat.guid: i,
  };
}
