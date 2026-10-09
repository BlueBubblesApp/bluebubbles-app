import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a message from me marks the chat read', () {
    expect(unreadAfterIncomingMessage(isFromMe: true, dateRead: null), isFalse);
  });

  test('an unread message from someone else marks the chat unread', () {
    expect(unreadAfterIncomingMessage(isFromMe: false, dateRead: null), isTrue);
  });

  test('a message Apple already reports as read leaves the read state alone', () {
    // The read event can be applied before the message itself arrives; the
    // message must not undo it.
    expect(unreadAfterIncomingMessage(isFromMe: false, dateRead: DateTime(2026, 10, 8)), isNull);
  });
}
