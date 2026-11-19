import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/types/helpers/image_type_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// An ISO base-media file's first box, naming [brand].
Uint8List ftyp(String brand) => Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftyp'), ...ascii.encode(brand), 0]);

void main() {
  test('JPEG and PNG are read from their magic numbers', () {
    expect(imageTypeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]))?.mimeType, 'image/jpeg');
    expect(imageTypeOf(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]))?.mimeType,
        'image/png');
  });

  test('Every HEIF brand is HEIC, stills and sequences alike', () {
    for (final brand in ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1']) {
      expect(isHeif(ftyp(brand)), isTrue, reason: brand);
    }
  });

  test('Other ISO base-media files and short or unknown bytes are not HEIC', () {
    expect(isHeif(ftyp('isom')), isFalse); // an MP4
    expect(isHeif(Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftyp')])), isFalse);
    expect(isHeif(Uint8List(0)), isFalse);
    expect(imageTypeOf(Uint8List.fromList(ascii.encode('GIF89a'))), isNull);
  });
}
