import 'dart:convert';
import 'dart:typed_data';

/// [bytes]' image type, read from the bytes themselves rather than a name or a header: JPEG, PNG or HEIC (any HEIF
/// brand). Null for anything else.
({String mimeType, String uti, String extension})? imageTypeOf(Uint8List bytes) {
  bool startsWith(List<int> magic, [int offset = 0]) =>
      bytes.length >= offset + magic.length && magic.indexed.every((e) => bytes[offset + e.$1] == e.$2);
  if (startsWith(const [0xFF, 0xD8, 0xFF])) return (mimeType: 'image/jpeg', uti: 'public.jpeg', extension: 'jpg');
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return (mimeType: 'image/png', uti: 'public.png', extension: 'png');
  }
  // An ISO base-media `ftyp` box naming a HEIF brand
  if (bytes.length >= 12 &&
      startsWith(ascii.encode('ftyp'), 4) &&
      const ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return (mimeType: 'image/heic', uti: 'public.heic', extension: 'heic');
  }
  return null;
}

/// Whether [bytes] are a HEIC/HEIF image. Off Apple platforms these must never reach an image decoder: Windows and
/// Linux have none, and Android's corrupts the app's memory on some devices (stickers and Genmoji especially).
bool isHeif(Uint8List bytes) => imageTypeOf(bytes)?.mimeType == 'image/heic';
