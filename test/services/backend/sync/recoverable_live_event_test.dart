import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextBaselineAfterLiveEvent', () {
    test('a hide joins the baseline', () {
      expect(
        nextBaselineAfterLiveEvent(guid: 'm1', hide: true, hasTrustedBaseline: true, baselineGuids: {'m0'}),
        {'m0', 'm1'},
      );
    });

    test('a restore leaves the baseline', () {
      expect(
        nextBaselineAfterLiveEvent(guid: 'm1', hide: false, hasTrustedBaseline: true, baselineGuids: {'m0', 'm1'}),
        {'m0'},
      );
    });

    test('a restore of a message outside the baseline leaves it unchanged', () {
      // Hidden while the baseline was untrusted, or before it existed: Apple
      // restoring it still applies; there is simply nothing to remove.
      expect(
        nextBaselineAfterLiveEvent(guid: 'm2', hide: false, hasTrustedBaseline: true, baselineGuids: {'m0'}),
        {'m0'},
      );
    });

    test('an untrusted baseline is not rewritten', () {
      expect(nextBaselineAfterLiveEvent(guid: 'm1', hide: true, hasTrustedBaseline: false, baselineGuids: {}), isNull);
      expect(nextBaselineAfterLiveEvent(guid: 'm1', hide: false, hasTrustedBaseline: false, baselineGuids: {}), isNull);
    });
  });
}
