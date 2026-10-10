import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chat read push delivery', () {
    test('drops the duplicate only when the UI is truly foregrounded with a live socket', () {
      expect(
        shouldDropChatReadPush(
          headless: false,
          isForeground: true,
          socketConnected: true,
        ),
        isTrue,
      );
    });

    test('keeps the push when a stale socket still claims connected in the background', () {
      expect(
        shouldDropChatReadPush(
          headless: false,
          isForeground: false,
          socketConnected: true,
        ),
        isFalse,
      );
    });

    test('keeps the push in a headless handler', () {
      expect(
        shouldDropChatReadPush(
          headless: true,
          isForeground: false,
          socketConnected: false,
        ),
        isFalse,
      );
    });
  });
}
