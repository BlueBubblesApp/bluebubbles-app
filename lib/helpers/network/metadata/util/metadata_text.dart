/// Cleanup routines applied to every string that comes out of a parser.
///
/// Web pages are full of whitespace-padded titles, doubly-escaped entities and
/// literal placeholder strings. Centralising the cleanup here means individual
/// parsers can return raw attribute values and trust that nothing garbage
/// reaches the UI or the database.
abstract final class MetadataText {
  /// Titles longer than this are almost always a page dump rather than a title.
  static const int maxTitleLength = 200;

  /// Descriptions are clamped so a runaway page can't bloat the message row.
  static const int maxDescriptionLength = 500;

  /// Values that appear when a site emits a templated tag it never filled in.
  ///
  /// `"null"` in particular is extremely common — it is what
  /// `String(someUndefinedVar)` produces in most templating languages, and the
  /// previous implementation had to special-case it at the call site.
  static const Set<String> _placeholders = {
    'null',
    'undefined',
    'nan',
    'none',
    '(null)',
    '{{title}}',
    '{{description}}',
    '%s',
  };

  /// Non-breaking / zero-width spaces, plus the byte-order mark. These are
  /// normalised to plain spaces before the whitespace collapse so that a title
  /// made entirely of them is correctly treated as empty.
  static final RegExp _exoticSpaces = RegExp('[\u{00A0}\u{2000}-\u{200B}\u{202F}\u{205F}\u{3000}\u{FEFF}]');

  static final RegExp _whitespaceRun = RegExp(r'\s+');
  static final RegExp _entity = RegExp(r'&(?:#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);');

  /// The handful of named entities worth handling. The `html` package already
  /// decodes entities once while parsing, so this only exists to catch pages
  /// that double-encode their Open Graph values (`&amp;amp;` -> `&amp;` -> `&`).
  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'hellip': '\u{2026}',
    'mdash': '\u{2014}',
    'ndash': '\u{2013}',
    'lsquo': '\u{2018}',
    'rsquo': '\u{2019}',
    'ldquo': '\u{201C}',
    'rdquo': '\u{201D}',
    'middot': '\u{00B7}',
    'bull': '\u{2022}',
    'copy': '\u{00A9}',
    'reg': '\u{00AE}',
    'trade': '\u{2122}',
  };

  /// Normalises [raw] and returns `null` when nothing usable is left.
  ///
  /// Trims, collapses internal whitespace runs (a `<title>` split across
  /// several indented source lines is otherwise rendered with the newlines
  /// intact), unescapes doubled entities and rejects placeholder junk.
  static String? clean(String? raw, {int maxLength = maxTitleLength}) {
    if (raw == null) return null;

    var value = raw.replaceAll(_exoticSpaces, ' ').trim();
    if (value.isEmpty) return null;

    if (_entity.hasMatch(value)) {
      value = _unescape(value);
    }

    value = value.replaceAll(_whitespaceRun, ' ').trim();
    if (value.isEmpty) return null;
    if (_placeholders.contains(value.toLowerCase())) return null;

    if (value.length > maxLength) {
      // Cut on a word boundary when there is one nearby so the ellipsis does
      // not land mid-word.
      final hardCut = value.substring(0, maxLength);
      final lastSpace = hardCut.lastIndexOf(' ');
      final body = lastSpace > maxLength - 40 ? hardCut.substring(0, lastSpace) : hardCut;
      value = '${body.trimRight()}\u{2026}';
    }

    return value;
  }

  /// [clean] with the description length limit applied.
  static String? cleanDescription(String? raw) => clean(raw, maxLength: maxDescriptionLength);

  /// Strips a trailing `" - Site Name"` / `" | Site Name"` suffix from [title].
  ///
  /// Only applied when [siteName] is known and actually matches the suffix, so
  /// legitimate titles that happen to contain a dash are left alone.
  static String? stripSiteSuffix(String? title, String? siteName) {
    if (title == null || siteName == null) return title;
    final trimmedSite = siteName.trim();
    if (trimmedSite.isEmpty) return title;

    for (final separator in const [' - ', ' | ', ' \u{2014} ', ' \u{2013} ', ' :: ', ' \u{00B7} ']) {
      final suffix = '$separator$trimmedSite';
      if (title.length > suffix.length && title.toLowerCase().endsWith(suffix.toLowerCase())) {
        final stripped = title.substring(0, title.length - suffix.length).trim();
        if (stripped.isNotEmpty) return stripped;
      }
    }

    return title;
  }

  static String _unescape(String input) {
    return input.replaceAllMapped(_entity, (match) {
      final entity = match.group(0)!;
      final body = entity.substring(1, entity.length - 1);

      if (body.startsWith('#')) {
        final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
        final digits = isHex ? body.substring(2) : body.substring(1);
        final code = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (code == null || code < 0x20 || code > 0x10FFFF) return entity;
        // Surrogate halves are not valid scalar values.
        if (code >= 0xD800 && code <= 0xDFFF) return entity;
        return String.fromCharCode(code);
      }

      return _namedEntities[body.toLowerCase()] ?? entity;
    });
  }
}
