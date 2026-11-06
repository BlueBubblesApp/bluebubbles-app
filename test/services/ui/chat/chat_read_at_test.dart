import 'package:bluebubbles/services/ui/chat/chats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a read event takes its time from the server', () {
    // 2026-10-28 05:35:08.971 UTC, the Schwab chat read on an Apple device.
    expect(chatReadAtFromEvent({'chatGuid': 'SMS;-;87047', 'read': true, 'readAt': 1793165708971}),
        DateTime.fromMillisecondsSinceEpoch(1793165708971));
  });

  test('a read event from an older server records nothing', () {
    // Without the server's time the phone's clock would have to stand in, which
    // could silence a message sent just after the read.
    expect(chatReadAtFromEvent({'chatGuid': 'SMS;-;87047', 'read': true}), isNull);
  });

  test('an unread event records nothing', () {
    expect(chatReadAtFromEvent({'chatGuid': 'SMS;-;87047', 'read': false, 'readAt': 1793165708971}), isNull);
  });
}
