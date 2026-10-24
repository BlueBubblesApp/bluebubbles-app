import 'package:bluebubbles/services/backend/sync/chat_state_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a newer authoritative snapshot repairs local state even when the baseline is unchanged', () {
    expect(
      desiredUnreadFromSnapshot(hasTrustedBaseline: true, serverRead: false, localUnread: false),
      isTrue,
    );
  });

  test('the first snapshot seeds without backfilling historical read state', () {
    expect(
      desiredUnreadFromSnapshot(
        hasTrustedBaseline: false,
        serverRead: false,
        localUnread: false,
      ),
      isNull,
    );
  });

  test('a chat that first appears after the baseline takes Apple\'s read state', () {
    // A new chat read on Apple before its live read event reached Android.
    expect(
      desiredUnreadFromSnapshot(hasTrustedBaseline: true, serverRead: true, localUnread: true),
      isFalse,
    );
  });

  test('an authoritative snapshot does nothing when local state already matches', () {
    expect(
      desiredUnreadFromSnapshot(hasTrustedBaseline: true, serverRead: false, localUnread: true),
      isNull,
    );
  });
}
