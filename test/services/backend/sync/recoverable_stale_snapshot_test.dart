import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isStaleRecoverableSnapshot', () {
    test('a snapshot older than the applied one is stale', () {
      expect(isStaleRecoverableSnapshot(snapshotGeneratedAt: 100, baselineGeneratedAt: 200), isTrue);
    });
    test('a newer or equal snapshot is not stale', () {
      expect(isStaleRecoverableSnapshot(snapshotGeneratedAt: 200, baselineGeneratedAt: 200), isFalse);
      expect(isStaleRecoverableSnapshot(snapshotGeneratedAt: 300, baselineGeneratedAt: 200), isFalse);
    });
    test('a baseline without a timestamp never makes a snapshot stale', () {
      expect(isStaleRecoverableSnapshot(snapshotGeneratedAt: 100, baselineGeneratedAt: 0), isFalse);
    });
    test('a snapshot without a timestamp is never treated as stale', () {
      expect(isStaleRecoverableSnapshot(snapshotGeneratedAt: 0, baselineGeneratedAt: 200), isFalse);
    });
  });
}
