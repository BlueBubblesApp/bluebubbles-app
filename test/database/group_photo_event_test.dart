import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/incoming_message_handler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A group-photo row as the server sends it: no text, `itemType` 3, and the action in `groupActionType`.
Message _photoRow(int groupActionType, {String guid = 'photo-row', bool isFromMe = false}) =>
    Message(guid: guid, itemType: 3, groupActionType: groupActionType, isFromMe: isFromMe, handleId: 0);

void main() {
  group('group photo event text', () {
    test('the photo state row (3/3) is labelled, and names nobody', () {
      // No sender is recorded on this row. Passing "You" is what the fallback for a missing handle produces, and
      // the label must not repeat it.
      final text = _photoRow(3).buildGroupEventText('You');
      expect(text, 'The group photo was updated.');
      expect(text, isNot(contains('You')));
      expect(text, isNot('Unknown group event'));
    });

    test('a person changing or removing the photo keeps their name', () {
      expect(_photoRow(1).buildGroupEventText('Alex'), 'Alex changed the group photo.');
      expect(_photoRow(2).buildGroupEventText('Alex'), 'Alex removed the group photo.');
    });

    test('only 3/3 is the photo state', () {
      expect(_photoRow(3).isGroupPhotoState, isTrue);
      expect(_photoRow(1).isGroupPhotoState, isFalse);
      expect(_photoRow(2).isGroupPhotoState, isFalse);
      // Still a photo event, so the chat icon is refetched as before.
      expect(_photoRow(3).isGroupPhotoEvent, isTrue);
    });
  });

  group('isGroupPhotoResend', () {
    test('the same photo state arriving again is a resend', () {
      expect(isGroupPhotoResend(incoming: _photoRow(3), stored: _photoRow(3)), isTrue);
    });

    test('a different GUID is a different row, not a resend', () {
      expect(
        isGroupPhotoResend(
          incoming: _photoRow(3, guid: 'a'),
          stored: _photoRow(3, guid: 'b'),
        ),
        isFalse,
      );
    });

    test('a person changing the photo is never swallowed', () {
      expect(isGroupPhotoResend(incoming: _photoRow(1), stored: _photoRow(1)), isFalse);
      expect(isGroupPhotoResend(incoming: _photoRow(3), stored: _photoRow(1)), isFalse);
    });

    test('an ordinary message update is not affected', () {
      final message = Message(guid: 'm', text: 'hello', itemType: 0, groupActionType: 0, isFromMe: false);
      expect(isGroupPhotoResend(incoming: message, stored: message), isFalse);
    });
  });
}
