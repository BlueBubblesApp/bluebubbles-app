import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLiveRecoverableEvent', () {
    test('a hide always applies and is recorded in the baseline', () {
      final r = resolveLiveRecoverableEvent(
          guid: 'm1', hide: true, hasTrustedBaseline: true, baselineGuids: {'m0'});
      expect(r.apply, isTrue);
      expect(r.nextBaseline, {'m0', 'm1'});
    });

    test('a restore applies only to a message this client hid for Apple', () {
      final r = resolveLiveRecoverableEvent(
          guid: 'm1', hide: false, hasTrustedBaseline: true, baselineGuids: {'m1'});
      expect(r.apply, isTrue);
      expect(r.nextBaseline, isEmpty);
    });

    test('a restore never un-hides a message the user deleted in the app', () {
      // Deleted locally, so it was never in the baseline.
      final r = resolveLiveRecoverableEvent(
          guid: 'local-delete', hide: false, hasTrustedBaseline: true, baselineGuids: {'m1'});
      expect(r.apply, isFalse);
      expect(r.nextBaseline, isNull);
    });

    test('an untrusted baseline still applies a hide but is not rewritten', () {
      final r = resolveLiveRecoverableEvent(
          guid: 'm1', hide: true, hasTrustedBaseline: false, baselineGuids: {});
      expect(r.apply, isTrue);
      expect(r.nextBaseline, isNull);
    });

    test('an untrusted baseline refuses every restore', () {
      final r = resolveLiveRecoverableEvent(
          guid: 'm1', hide: false, hasTrustedBaseline: false, baselineGuids: {});
      expect(r.apply, isFalse);
    });
  });
}
