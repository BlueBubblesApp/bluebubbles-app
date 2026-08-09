import 'dart:convert';
import 'dart:typed_data';

/// Decodes a fetched HTML body to a string using the document's own encoding.
///
/// The previous implementation called `utf8.decode` with no fallback, so any
/// page served as ISO-8859-1 or Windows-1252 threw a `FormatException`, the
/// document came back null, and the preview silently degraded to the URL.
abstract final class HtmlBodyDecoder {
  /// How many leading bytes to sniff for a `<meta charset>` declaration. The
  /// HTML spec requires the declaration within the first 1024 bytes; a little
  /// headroom covers sites that pad the head with comments.
  static const int _sniffLength = 2048;

  static final RegExp _charsetInContentType = RegExp(r'charset\s*=\s*"?([\w\-]+)"?', caseSensitive: false);
  static final RegExp _charsetInMetaTag = RegExp(
    r'''<meta[^>]+charset\s*=\s*["']?\s*([\w\-]+)''',
    caseSensitive: false,
  );

  /// Decodes [bytes], preferring the charset named in [contentType], then one
  /// declared by a `<meta>` tag, and finally UTF-8.
  ///
  /// Never throws: unmappable bytes are replaced rather than rejected, because
  /// a slightly mangled character is far better than no preview at all.
  static String decode(Uint8List bytes, {String? contentType}) {
    if (bytes.isEmpty) return '';

    final charset = _fromContentType(contentType) ?? _fromMetaTag(bytes);
    return _decodeWith(bytes, charset);
  }

  static String? _fromContentType(String? contentType) {
    if (contentType == null) return null;
    final match = _charsetInContentType.firstMatch(contentType);
    return match?.group(1)?.trim().toLowerCase();
  }

  static String? _fromMetaTag(Uint8List bytes) {
    // Sniff as Latin-1 so every byte maps to a character; we only care about
    // the ASCII range of the declaration itself.
    final limit = bytes.length < _sniffLength ? bytes.length : _sniffLength;
    final head = latin1.decode(bytes.sublist(0, limit), allowInvalid: true);
    final match = _charsetInMetaTag.firstMatch(head);
    return match?.group(1)?.trim().toLowerCase();
  }

  static String _decodeWith(Uint8List bytes, String? charset) {
    switch (charset) {
      case 'iso-8859-1':
      case 'iso8859-1':
      case 'latin1':
      case 'latin-1':
      case 'l1':
      case 'windows-1252':
      case 'cp1252':
      case 'cp-1252':
      case 'ansi':
        return _decodeWindows1252(bytes);
      default:
        // UTF-8 covers the declared-UTF-8 and ASCII cases, and is the
        // least-bad option for an encoding Dart has no codec for (Shift_JIS,
        // GBK, EUC-KR...): replacement characters still leave the ASCII-range
        // markup intact, which is where the metadata lives.
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// Windows-1252 differs from Latin-1 only in the 0x80-0x9F range, which is
  /// where the smart quotes and dashes that infest real-world titles live.
  ///
  /// Pages labelled `iso-8859-1` are overwhelmingly Windows-1252 in practice,
  /// and the HTML spec mandates treating them as such.
  static const List<int> _cp1252Overrides = [
    0x20AC, // 0x80 euro
    0x0081, // unused
    0x201A, // single low-9 quote
    0x0192, // florin
    0x201E, // double low-9 quote
    0x2026, // ellipsis
    0x2020, // dagger
    0x2021, // double dagger
    0x02C6, // circumflex
    0x2030, // per mille
    0x0160, // S caron
    0x2039, // single left angle quote
    0x0152, // OE ligature
    0x008D, // unused
    0x017D, // Z caron
    0x008F, // unused
    0x0090, // unused
    0x2018, // left single quote
    0x2019, // right single quote
    0x201C, // left double quote
    0x201D, // right double quote
    0x2022, // bullet
    0x2013, // en dash
    0x2014, // em dash
    0x02DC, // small tilde
    0x2122, // trademark
    0x0161, // s caron
    0x203A, // single right angle quote
    0x0153, // oe ligature
    0x009D, // unused
    0x017E, // z caron
    0x0178, // Y diaeresis
  ];

  static String _decodeWindows1252(Uint8List bytes) {
    final codeUnits = List<int>.filled(bytes.length, 0);
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      codeUnits[i] = byte >= 0x80 && byte <= 0x9F ? _cp1252Overrides[byte - 0x80] : byte;
    }
    return String.fromCharCodes(codeUnits);
  }
}
