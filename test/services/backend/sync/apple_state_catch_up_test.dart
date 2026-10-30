import 'package:bluebubbles/services/backend/sync/apple_state_catch_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRecoverableMessageEvent', () {
    test('a message-deleted payload yields the chat and message GUIDs', () {
      final event = parseRecoverableMessageEvent({'chatGuid': 'chat-a', 'messageGuid': 'm1'}, deleted: true);

      expect(event, isNotNull);
      expect(event!.chatGuid, 'chat-a');
      expect(event.messageGuid, 'm1');
      expect(event.deleted, isTrue);
    });

    test('a message-restored payload is parsed as a restore', () {
      final event = parseRecoverableMessageEvent({'chatGuid': 'chat-a', 'messageGuid': 'm1'}, deleted: false);
      expect(event!.deleted, isFalse);
    });

    test('a payload missing either GUID is rejected', () {
      expect(parseRecoverableMessageEvent({'chatGuid': 'chat-a'}, deleted: true), isNull);
      expect(parseRecoverableMessageEvent({'messageGuid': 'm1'}, deleted: true), isNull);
      expect(parseRecoverableMessageEvent({'chatGuid': '', 'messageGuid': 'm1'}, deleted: true), isNull);
      expect(parseRecoverableMessageEvent('not a map', deleted: true), isNull);
    });
  });

  group('parseAppleStateSnapshot', () {
    test('reads each chat\'s read state', () {
      final snapshot = parseAppleStateSnapshot(chatState: {
        'chats': [
          {'guid': 'read-chat', 'read': true},
          {'guid': 'unread-chat', 'read': false},
        ],
      });

      expect(snapshot.readByChat, {'read-chat': true, 'unread-chat': false});
    });

    test('a single delete hides the message; a chat with nothing left was deleted whole', () {
      final snapshot = parseAppleStateSnapshot(recentlyDeleted: {
        'chats': [
          {'guid': 'chat-a', 'hasMessages': true, 'deletedMessageGuids': ['m1', 'm2']},
          {'guid': 'chat-b', 'hasMessages': false, 'deletedMessageGuids': ['m3']},
        ],
      });

      expect(snapshot.deletedMessages, {'m1', 'm2'});
      expect(snapshot.deletedChats, {'chat-b'});
    });

    test('malformed entries are skipped and the rest still apply', () {
      final snapshot = parseAppleStateSnapshot(
        chatState: {
          'chats': [
            {'guid': 'ok', 'read': true},
            {'guid': '', 'read': true},
            {'guid': 'no-read'},
            'not a map',
          ],
        },
        recentlyDeleted: {
          'chats': [
            {'guid': 'chat-a', 'hasMessages': true, 'deletedMessageGuids': ['m1', '', 7]},
            {'guid': 'chat-b', 'deletedMessageGuids': ['m2']},
          ],
        },
      );

      expect(snapshot.readByChat, {'ok': true});
      expect(snapshot.deletedMessages, {'m1'});
      expect(snapshot.deletedChats, isEmpty);
    });

    test('a missing response contributes nothing', () {
      final snapshot = parseAppleStateSnapshot();

      expect(snapshot.readByChat, isEmpty);
      expect(snapshot.deletedMessages, isEmpty);
      expect(snapshot.deletedChats, isEmpty);
    });
  });
}
