import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveRecoverableMessageActions forward-only rules', () {
    test('the first pass seeds a baseline without hiding or restoring anything', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: false,
        baselineGuids: const {},
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: const {},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toHide, isEmpty);
      expect(actions.toRestore, isEmpty);
      expect(actions.seeded, isTrue);
      expect(actions.nextBaseline, {'m1'});
    });

    test('a message the user deleted in the app is never un-hidden by the server', () {
      // 'mine' was hidden locally and is not in the baseline, so this client
      // did not hide it on Apple's behalf and must not undo it.
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: const {},
        locallyHiddenGuids: {'mine'},
        locallyKnownGuids: {'mine'},
      );

      expect(actions.toRestore, isEmpty);
      expect(actions.toHide, isEmpty);
    });

    test('a message this client hid for Apple is restored when Apple brings it back', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: {'m1'},
        serverDeletedGuids: const {},
        locallyHiddenGuids: {'m1'},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toRestore, {'m1'});
    });

    test('the baseline tracks the server set so a restore is not retried forever', () {
      final first = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: {'m1'},
        serverDeletedGuids: const {},
        locallyHiddenGuids: {'m1'},
        locallyKnownGuids: {'m1'},
      );
      expect(first.nextBaseline, isEmpty);

      final second = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: first.nextBaseline,
        serverDeletedGuids: const {},
        locallyHiddenGuids: const {},
        locallyKnownGuids: {'m1'},
      );
      expect(second.toRestore, isEmpty);
    });

    test('a message deleted while offline is hidden and enters the baseline', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: const {},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toHide, {'m1'});
      expect(actions.nextBaseline, {'m1'});
    });

    test('a deleted message the device never downloaded is not invented', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'never-synced'},
        locallyHiddenGuids: const {},
        locallyKnownGuids: {'m1'},
      );

      expect(actions.toHide, isEmpty);
    });

    test('a baseline entry the device no longer holds is dropped, not restored', () {
      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: {'gone'},
        serverDeletedGuids: const {},
        locallyHiddenGuids: const {},
        locallyKnownGuids: const {},
      );

      expect(actions.toRestore, isEmpty);
      expect(actions.nextBaseline, isEmpty);
    });

    test('applying the same snapshot twice changes nothing the second time', () {
      final first = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: const {},
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: const {},
        locallyKnownGuids: {'m1'},
      );

      final second = resolveRecoverableMessageActions(
        hasTrustedBaseline: true,
        baselineGuids: first.nextBaseline,
        serverDeletedGuids: {'m1'},
        locallyHiddenGuids: {'m1'},
        locallyKnownGuids: {'m1'},
      );

      expect(second.toHide, isEmpty);
      expect(second.toRestore, isEmpty);
    });
  });
}
