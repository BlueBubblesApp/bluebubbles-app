import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// A group-photo row as the server sends it in a listing: no text, the action in `groupActionType`, the photo as its
/// attachment when the server could link it, and the chat it is in.
Map<String, dynamic> _row(String guid, int groupActionType, {required int date, String? photo, String? chatPhoto}) => {
  'guid': guid,
  'itemType': 3,
  'groupActionType': groupActionType,
  'dateCreated': date,
  'attachments': [
    ?(photo == null ? null : {'guid': photo}),
  ],
  'chats': [
    {
      'guid': 'chat',
      'properties': [
        {'groupPhotoGuid': ?chatPhoto},
      ],
    },
  ],
};

Map<String, dynamic> _text(String guid, {required int date}) => {
  'guid': guid,
  'itemType': 0,
  'groupActionType': 0,
  'dateCreated': date,
  'text': 'hi',
};

List<String> _guids(List<Map<String, dynamic>> rows) => rows.map((r) => r['guid'] as String).toList();

void main() {
  group('reading the photo', () {
    test('the chat properties name the photo, last non-empty entry winning', () {
      expect(groupPhotoGuidInProperties(null), isNull);
      expect(groupPhotoGuidInProperties(const []), isNull);
      expect(
        groupPhotoGuidInProperties([
          {'groupPhotoGuid': 'a'},
          {'groupPhotoGuid': ''},
          {'groupPhotoGuid': 'b'},
        ]),
        'b',
      );
      expect(groupPhotoGuidInProperties({'groupPhotoGuid': 'single'}), 'single');
    });

    test("the row's own attachment wins over what the chat names", () {
      // The chat's properties can lag a change; the row carries the photo it is about.
      expect(groupPhotoGuidOfMap(_row('m', 3, date: 1, photo: 'new', chatPhoto: 'old')), 'new');
      expect(groupPhotoGuidOfMap(_row('m', 3, date: 1, chatPhoto: 'old')), 'old');
      expect(groupPhotoGuidOfMap(_row('m', 3, date: 1)), isNull);
    });

    test('a chat from the server carries the photo it names, and keeps it across toMap', () {
      final chat = Chat.fromMap({
        'guid': 'chat',
        'properties': [
          {'groupPhotoGuid': 'photo'},
        ],
      });
      expect(chat.serverGroupPhotoGuid, 'photo');
      expect(Chat.fromMap(chat.toMap()).serverGroupPhotoGuid, 'photo');
    });
  });

  group('isKnownGroupPhoto', () {
    test('only the same photo on both sides is a repeat', () {
      expect(isKnownGroupPhoto('a', 'a'), isTrue);
      expect(isKnownGroupPhoto('a', 'b'), isFalse);
      // Either side unknown cannot be called a repeat, so the event is kept.
      expect(isKnownGroupPhoto(null, 'a'), isFalse);
      expect(isKnownGroupPhoto('a', null), isFalse);
    });
  });

  group('dropKnownGroupPhotoResends', () {
    test('a resend of the known photo is dropped, under any message GUID', () {
      final result = dropKnownGroupPhotoResends([
        _row('same-guid', 3, date: 10, photo: 'p1'),
        _row('other-guid', 3, date: 20, photo: 'p1'),
        _text('t', date: 15),
      ], 'p1');
      expect(_guids(result.kept), ['t']);
      expect(result.known, 'p1');
    });

    test('a new photo is kept and becomes the known one, so its own resend after it is dropped', () {
      final result = dropKnownGroupPhotoResends([
        _row('resend', 3, date: 30, photo: 'p2'),
        _row('first', 3, date: 10, photo: 'p2'),
      ], 'p1');
      expect(_guids(result.kept), ['first'], reason: 'walked oldest first, so the earlier row is the change');
      expect(result.known, 'p2');
    });

    test('a person changing the photo is always kept, and sets the known photo for the rows after it', () {
      final result = dropKnownGroupPhotoResends([
        _row('change', 1, date: 10, photo: 'p2'),
        _row('state', 3, date: 11, photo: 'p2'),
      ], 'p1');
      expect(_guids(result.kept), ['change']);
      expect(result.known, 'p2');
    });

    test('with nothing known, the first photo row is kept', () {
      final result = dropKnownGroupPhotoResends([_row('first', 3, date: 10, photo: 'p1')], null);
      expect(_guids(result.kept), ['first']);
      expect(result.known, 'p1');
    });

    test('a row whose photo cannot be identified is kept and changes nothing', () {
      final result = dropKnownGroupPhotoResends([_row('unknown', 3, date: 10)], 'p1');
      expect(_guids(result.kept), ['unknown']);
      expect(result.known, 'p1');
    });
  });
}
