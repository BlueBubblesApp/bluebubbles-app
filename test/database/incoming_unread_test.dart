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

  group('clearing notifications for a message from me', () {
    test('clears them directly when Apple already marked the chat read', () {
      // A reply sent from the iPhone after Apple's read sync has no unread flag
      // left to flip, so the read flip would clear nothing.
      expect(clearNotificationsWithoutReadFlip(isFromMe: true, clearIfFromMe: true, wasUnread: false), isTrue);
    });

    test('leaves it to the read flip when the chat was still unread', () {
      expect(clearNotificationsWithoutReadFlip(isFromMe: true, clearIfFromMe: true, wasUnread: true), isFalse);
    });

    test('keeps them when the caller asked to (reply sent from the notification)', () {
      expect(clearNotificationsWithoutReadFlip(isFromMe: true, clearIfFromMe: false, wasUnread: false), isFalse);
    });

    test('never clears them for a message from someone else', () {
      expect(clearNotificationsWithoutReadFlip(isFromMe: false, clearIfFromMe: true, wasUnread: false), isFalse);
    });
  });
}
