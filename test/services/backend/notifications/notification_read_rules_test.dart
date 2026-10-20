import 'package:bluebubbles/services/backend/notifications/notifications_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a message Apple already reports as read raises no notification', () {
    expect(skipNotificationForReadMessage(DateTime(2026, 10, 20, 20, 40, 14)), isTrue);
  });

  test('an unread message still raises a notification', () {
    expect(skipNotificationForReadMessage(null), isFalse);
  });
}
