import 'package:bluebubbles/services/backend/notifications/notifications_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a message Apple already reports as read raises no notification', () {
    expect(skipNotificationForReadMessage(DateTime(2026, 10, 20, 20, 40, 14)), isTrue);
  });

  test('an unread message still raises a notification', () {
    expect(skipNotificationForReadMessage(null), isFalse);
  });

  group('a chat read on an Apple device before the notification is posted', () {
    final readAt = DateTime(2026, 10, 28, 0, 35, 10, 287);

    test('raises no notification for a message sent before the read', () {
      // The push carrying the message was serialized before the read, so its
      // dateRead is still null; the read event was handled first and found
      // nothing to clear.
      expect(
        skipNotificationForReadMessage(null, dateCreated: DateTime(2026, 10, 28, 0, 35, 8, 679), chatReadAt: readAt),
        isTrue,
      );
    });

    test('still notifies for a message sent after the read', () {
      expect(
        skipNotificationForReadMessage(null, dateCreated: DateTime(2026, 10, 28, 0, 36), chatReadAt: readAt),
        isFalse,
      );
    });

    test('still notifies when the chat was never read elsewhere', () {
      expect(skipNotificationForReadMessage(null, dateCreated: DateTime(2026, 10, 28, 0, 35, 8)), isFalse);
    });
  });
}
