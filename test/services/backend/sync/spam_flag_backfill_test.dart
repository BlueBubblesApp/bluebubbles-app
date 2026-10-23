import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/sync/spam_flag_backfill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applySpamFlagsFromServer', () {
    test('fills in a verdict for a chat stored before the server reported one', () {
      final stored = Chat(id: 1, guid: 'a');
      final changed = applySpamFlagsFromServer(
        stored: [stored],
        serverChats: [Chat(guid: 'a', isFilteredAsSpam: true)],
      );

      expect(changed.map((e) => e.guid), ['a']);
      expect(stored.isFilteredAsSpam, true);
    });

    test('clears a stale verdict when Messages no longer files the chat under Spam', () {
      final stored = Chat(id: 1, guid: 'a', isFilteredAsSpam: true);
      final changed = applySpamFlagsFromServer(
        stored: [stored],
        serverChats: [Chat(guid: 'a', isFilteredAsSpam: false)],
      );

      expect(changed.map((e) => e.guid), ['a']);
      expect(stored.isFilteredAsSpam, false);
    });

    test('a second pass over the same data changes nothing', () {
      final stored = Chat(id: 1, guid: 'a', isFilteredAsSpam: true);
      final server = [Chat(guid: 'a', isFilteredAsSpam: true)];

      expect(applySpamFlagsFromServer(stored: [stored], serverChats: server), isEmpty);
      expect(applySpamFlagsFromServer(stored: [stored], serverChats: server), isEmpty);
      expect(stored.isFilteredAsSpam, true);
    });

    test('a server that predates the flag leaves the stored verdict alone', () {
      final stored = Chat(id: 1, guid: 'a', isFilteredAsSpam: true);
      final changed = applySpamFlagsFromServer(
        stored: [stored],
        serverChats: [Chat(guid: 'a')],
      );

      expect(changed, isEmpty);
      expect(stored.isFilteredAsSpam, true);
    });

    test('locally owned fields are never overwritten by the server payload', () {
      final stored = Chat(
        id: 1,
        guid: 'a',
        isPinned: true,
        muteType: 'mute',
        isArchived: true,
        hasUnreadMessage: true,
      );
      applySpamFlagsFromServer(
        stored: [stored],
        serverChats: [
          Chat(
            guid: 'a',
            isFilteredAsSpam: true,
            isPinned: false,
            muteType: null,
            isArchived: false,
            hasUnreadMessage: false,
          ),
        ],
      );

      expect(stored.isFilteredAsSpam, true);
      expect(stored.isPinned, true);
      expect(stored.muteType, 'mute');
      expect(stored.isArchived, true);
      expect(stored.hasUnreadMessage, true);
    });

    test('a chat the server did not mention keeps its stored verdict', () {
      final stored = Chat(id: 1, guid: 'a', isFilteredAsSpam: true);
      final changed = applySpamFlagsFromServer(
        stored: [stored],
        serverChats: [Chat(guid: 'other', isFilteredAsSpam: false)],
      );

      expect(changed, isEmpty);
      expect(stored.isFilteredAsSpam, true);
    });

    test('only the chats that actually changed are returned, so a page can be skipped', () {
      final unchanged = Chat(id: 1, guid: 'a', isFilteredAsSpam: true);
      final changed = Chat(id: 2, guid: 'b');

      final result = applySpamFlagsFromServer(
        stored: [unchanged, changed],
        serverChats: [
          Chat(guid: 'a', isFilteredAsSpam: true),
          Chat(guid: 'b', isFilteredAsSpam: true),
        ],
      );

      expect(result.map((e) => e.guid), ['b']);
    });
  });
}
