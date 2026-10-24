import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRecoverableMessageSnapshot', () {
    Map<String, dynamic> snapshot({
      int schemaVersion = 1,
      bool complete = true,
      int generatedAt = 10,
      List<dynamic>? chats,
    }) =>
        {
          'schemaVersion': schemaVersion,
          'complete': complete,
          'generatedAt': generatedAt,
          'chats': chats ??
              [
                {
                  'guid': 'chat-a',
                  'deletedMessageGuids': ['m1', 'm2'],
                },
              ],
        };

    test('a complete snapshot yields the deleted GUIDs for each chat', () {
      final result = parseRecoverableMessageSnapshot(snapshot());

      expect(result.skipped, isFalse);
      expect(result.generatedAt, 10);
      expect(result.deletedByChat, {
        'chat-a': {'m1', 'm2'},
      });
    });

    test('an empty Recently Deleted folder is a valid snapshot, not a failure', () {
      final result = parseRecoverableMessageSnapshot(snapshot(chats: []));

      expect(result.skipped, isFalse);
      expect(result.deletedByChat, isEmpty);
    });

    test('an incomplete snapshot is refused so nothing gets un-hidden', () {
      final result = parseRecoverableMessageSnapshot(snapshot(complete: false));

      expect(result.skipped, isTrue);
      expect(result.reason, 'incomplete');
    });

    test('an unknown schema version is refused', () {
      final result = parseRecoverableMessageSnapshot(snapshot(schemaVersion: 2));

      expect(result.skipped, isTrue);
      expect(result.reason, 'schema');
    });

    test('a malformed row refuses the whole snapshot rather than half-applying it', () {
      final result = parseRecoverableMessageSnapshot(snapshot(chats: [
        {
          'guid': 'chat-a',
          'deletedMessageGuids': ['ok'],
        },
        {'guid': 'chat-b', 'deletedMessageGuids': 'not-a-list'},
      ]));

      expect(result.skipped, isTrue);
      expect(result.reason, 'malformed');
    });

    test('a missing generation time is refused', () {
      final result = parseRecoverableMessageSnapshot(snapshot(generatedAt: -1));

      expect(result.skipped, isTrue);
      expect(result.reason, 'malformed');
    });
  });

  group('resolveRecoverableMessageActions', () {
    test('a message Apple deleted while the client was offline is hidden', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: {},
        locallyKnownGuids: {'m1', 'm2'},
      );

      expect(actions.toHide, {'m1'});
      expect(actions.toRestore, isEmpty);
    });

    test('a message Apple restored while the client was offline is un-hidden', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: {'m1'},
        serverDeletedGuids: {},
        locallyHiddenGuids: {'m1'},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toRestore, {'m1'});
      expect(actions.toHide, isEmpty);
    });

    test('an already-hidden message that is still deleted is left alone', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: {'m1'},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toHide, isEmpty);
      expect(actions.toRestore, isEmpty);
    });

    test('a deleted message the device never downloaded is not invented', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'never-synced'},
        locallyHiddenGuids: {},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toHide, isEmpty);
      expect(actions.toRestore, isEmpty);
    });

    test('a locally hidden message the server never mentioned is restored only if known', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: {'gone'},
        serverDeletedGuids: {},
        locallyHiddenGuids: {'gone'},
        locallyKnownGuids: {},
      );

      expect(actions.toRestore, isEmpty);
      expect(actions.toHide, isEmpty);
    });
  });
}
