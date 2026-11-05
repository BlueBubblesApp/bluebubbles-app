import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _media(String guid, {String mime = 'image/jpeg'}) => Attachment(guid: guid, mimeType: mime);

MessagePart _mediaPart(int part, List<String> guids, {bool shouldRedact = false, bool isUnsent = false}) =>
    MessagePart(
      part: part,
      attachments: [for (final g in guids) _media(g)],
      shouldRedact: shouldRedact,
      isUnsent: isUnsent,
    );

MessagePart _textPart(int part, String text) => MessagePart(part: part, text: text);

void main() {
  group('MessagePart.collapseMediaCollections', () {
    test('passes non-media parts and lone single-attachment parts through unchanged', () {
      final text = _textPart(0, 'hello');
      final image = _mediaPart(1, ['a']);
      final pdf = MessagePart(part: 2, attachments: [_media('b', mime: 'application/pdf')]);
      final collapsed = MessagePart.collapseMediaCollections([text, image, pdf]);
      expect(collapsed, hasLength(3));
      expect(identical(collapsed[0], text), isTrue);
      expect(identical(collapsed[1], image), isTrue);
      expect(identical(collapsed[2], pdf), isTrue);
    });

    test('merges a run of media-only parts into one collection covering the whole span', () {
      final a = _mediaPart(1, ['a']);
      final b = _mediaPart(2, ['b']);
      final c = _mediaPart(3, ['c']);
      final collapsed = MessagePart.collapseMediaCollections([_textPart(0, 'hi'), a, b, c, _textPart(4, 'bye')]);

      expect(collapsed, hasLength(3));
      final collection = collapsed[1];
      expect(collection.isMediaCollection, isTrue);
      expect(collection.part, 1, reason: 'keeps the first raw id');
      expect(collection.attachments.map((e) => e.guid), ['a', 'b', 'c']);
      expect(collection.attachmentPartIndices, [1, 2, 3]);
      expect(collection.coveredPartIds, [1, 2, 3]);
      for (final id in [1, 2, 3]) {
        expect(collection.coversPartId(id), isTrue, reason: 'covers $id');
      }
      expect(collection.coversPartId(0), isFalse);
      expect(collection.coversPartId(4), isFalse);
    });

    test('a text part breaks the run', () {
      final collapsed = MessagePart.collapseMediaCollections([
        _mediaPart(0, ['a']),
        _mediaPart(1, ['b']),
        _textPart(2, 'between'),
        _mediaPart(3, ['c']),
        _mediaPart(4, ['d']),
      ]);
      expect(collapsed, hasLength(3));
      expect(collapsed[0].attachmentPartIndices, [0, 1]);
      expect(collapsed[2].attachmentPartIndices, [3, 4]);
    });

    test('per-attachment parts reuse single-attachment raw parts, so their flags stay live', () {
      final a = _mediaPart(0, ['a']);
      final b = _mediaPart(1, ['b']);
      final collection = MessagePart.collapseMediaCollections([a, b]).single;

      expect(identical(collection.itemPartFor(0), a), isTrue);
      expect(identical(collection.itemPartFor(1), b), isTrue);
      expect(identical(collection.itemPartFor(0), collection.itemPartFor(0)), isTrue, reason: 'stable identity');

      b.shouldRedact = true;
      expect(collection.itemPartFor(1).shouldRedact, isTrue);
    });

    test('a raw part with several attachments gets one item per attachment, carrying its flags', () {
      final multi = _mediaPart(5, ['a', 'b', 'c'], shouldRedact: true, isUnsent: true);
      final collection = MessagePart.collapseMediaCollections([multi]).single;

      expect(collection.isMediaCollection, isTrue);
      expect(collection.attachmentPartIndices, [5, 5, 5]);
      for (var i = 0; i < 3; i++) {
        final item = collection.itemPartFor(i);
        expect(item.part, 5);
        expect(item.attachments.single.guid, ['a', 'b', 'c'][i]);
        expect(item.shouldRedact, isTrue);
        expect(item.isUnsent, isTrue);
      }
    });

    test('itemPartFor falls back to a built part when the collection was not collapsed', () {
      final part = MessagePart(part: 2, attachments: [_media('a'), _media('b')]);
      final item = part.itemPartFor(1);
      expect(item.part, 2);
      expect(item.attachments.single.guid, 'b');
    });
  });
}
