import 'package:bluebubbles/services/backend/sync/recoverable_message_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRecoverableMessageEvent', () {
    test('a message-deleted payload yields the chat and message GUIDs', () {
      final event = parseRecoverableMessageEvent(
        {'chatGuid': 'chat-a', 'messageGuid': 'm1'},
        deleted: true,
      );

      expect(event, isNotNull);
      expect(event!.chatGuid, 'chat-a');
      expect(event.messageGuid, 'm1');
      expect(event.deleted, isTrue);
    });

    test('a message-restored payload is parsed as a restore', () {
      final event = parseRecoverableMessageEvent(
        {'chatGuid': 'chat-a', 'messageGuid': 'm1'},
        deleted: false,
      );

      expect(event!.deleted, isFalse);
    });

    test('a payload missing the message GUID is refused', () {
      expect(parseRecoverableMessageEvent({'chatGuid': 'chat-a'}, deleted: true), isNull);
    });

    test('a payload missing the chat GUID is refused', () {
      expect(parseRecoverableMessageEvent({'messageGuid': 'm1'}, deleted: true), isNull);
    });

    test('empty GUIDs are refused rather than acted on', () {
      expect(
        parseRecoverableMessageEvent({'chatGuid': '', 'messageGuid': 'm1'}, deleted: true),
        isNull,
      );
      expect(
        parseRecoverableMessageEvent({'chatGuid': 'chat-a', 'messageGuid': ''}, deleted: true),
        isNull,
      );
    });

    test('non-string GUIDs are refused', () {
      expect(
        parseRecoverableMessageEvent({'chatGuid': 'chat-a', 'messageGuid': 7}, deleted: true),
        isNull,
      );
    });

    test('a null payload is refused', () {
      expect(parseRecoverableMessageEvent(null, deleted: true), isNull);
      expect(parseRecoverableMessageEvent('not-a-map', deleted: true), isNull);
    });

    test('extra fields are ignored, so the server can add some later', () {
      final event = parseRecoverableMessageEvent(
        {'chatGuid': 'chat-a', 'messageGuid': 'm1', 'somethingNew': 1},
        deleted: true,
      );

      expect(event, isNotNull);
      expect(event!.messageGuid, 'm1');
    });
  });
}
