import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

String randomString(int length) =>
    String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(Random().nextInt(_chars.length))));

String sanitizeString(String? input) {
  return input?.replaceAll(String.fromCharCode(65532), '') ?? "";
}

/// Cap on the number of code points handed to on-device ML models (ML Kit smart
/// reply / entity extraction). These native models have crashed (SIGSEGV) on raw,
/// unbounded message text in the past, so we bound length and strip constructs
/// their tokenizers weren't validated against before crossing the platform channel.
const int _mlKitMaxTextLength = 500;

/// Sanitizes text before handing it to ML Kit's native smart reply / entity
/// extraction APIs. Strips control/bidi-override characters, repairs unpaired
/// UTF-16 surrogates (which can otherwise reach the native tokenizer as invalid
/// input), and truncates to a safe length. Not intended for display text.
String sanitizeForMlKit(String input) {
  final sanitized = sanitizeString(input);
  final buffer = StringBuffer();
  final units = sanitized.codeUnits;
  int written = 0;
  for (int i = 0; i < units.length && written < _mlKitMaxTextLength; i++) {
    final unit = units[i];

    // Surrogate pair handling: keep valid pairs together, replace lone halves.
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (next >= 0xDC00 && next <= 0xDFFF) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(next);
        i++;
      } else {
        buffer.writeCharCode(0xFFFD);
      }
      written++;
      continue;
    }
    if (unit >= 0xDC00 && unit <= 0xDFFF) {
      buffer.writeCharCode(0xFFFD);
      written++;
      continue;
    }

    // Drop control chars (except newline) and bidi-override/format chars.
    final isC0Control = unit < 0x20 && unit != 0x0A;
    final isC1Control = unit >= 0x7F && unit <= 0x9F;
    final isBidiOverride = (unit >= 0x202A && unit <= 0x202E) || (unit >= 0x2066 && unit <= 0x2069);
    final isBom = unit == 0xFEFF;
    if (isC0Control || isC1Control || isBidiOverride || isBom) {
      continue;
    }

    buffer.writeCharCode(unit);
    written++;
  }
  return buffer.toString();
}

bool isNullOrEmptyString(String? input) {
  return sanitizeString(input).isEmpty;
}

List<RegExpMatch> parseLinks(String text) {
  return urlRegex.allMatches(text).toList();
}
