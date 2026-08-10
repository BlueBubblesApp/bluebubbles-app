import 'package:html/dom.dart';

/// A pre-built lookup of every `<meta>` tag in a document.
///
/// The previous implementation scanned the whole document once per property,
/// which meant sixteen full traversals to read four fields across four
/// parsers. Building the index once turns every subsequent lookup into a map
/// read.
///
/// Keys are lowercased and taken from `property`, `name` and `itemprop`, so a
/// parser does not need to know which attribute a given site chose — plenty of
/// sites write `<meta name="og:title">` even though the spec says `property`.
class MetaTagIndex {
  MetaTagIndex._(this._byKey);

  final Map<String, List<String>> _byKey;

  /// Attributes that can name a meta tag.
  static const List<String> _keyAttributes = ['property', 'name', 'itemprop'];

  /// Attributes that can hold its value. `content` is the standard; a few
  /// older CMSes emit `value`.
  static const List<String> _valueAttributes = ['content', 'value'];

  factory MetaTagIndex.fromDocument(Document document) {
    final byKey = <String, List<String>>{};

    for (final element in document.getElementsByTagName('meta')) {
      final attributes = element.attributes;

      String? content;
      for (final attribute in _valueAttributes) {
        final raw = attributes[attribute];
        if (raw != null && raw.trim().isNotEmpty) {
          content = raw.trim();
          break;
        }
      }

      // A tag with no content carries no information. Skipping it here is what
      // stops empty tags from shadowing a later parser's real value — the old
      // code turned them into the literal string "null" and let that win.
      if (content == null) continue;

      for (final attribute in _keyAttributes) {
        final key = attributes[attribute]?.trim().toLowerCase();
        if (key == null || key.isEmpty) continue;
        byKey.putIfAbsent(key, () => <String>[]).add(content);
      }
    }

    return MetaTagIndex._(byKey);
  }

  /// An empty index, for documents that failed to parse.
  static final MetaTagIndex empty = MetaTagIndex._(const {});

  /// The first value declared for [key], or `null`.
  String? first(String key) {
    final values = _byKey[key.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }

  /// The first value found across [keys], in order. Use this for fields with
  /// several spellings (`og:image:secure_url` before `og:image`).
  String? firstOf(Iterable<String> keys) {
    for (final key in keys) {
      final value = first(key);
      if (value != null) return value;
    }
    return null;
  }

  /// Every value declared for [key] — `og:image` legitimately repeats.
  List<String> all(String key) => List.unmodifiable(_byKey[key.toLowerCase()] ?? const <String>[]);

  /// [first], parsed as an integer. Tolerates values like `"1200px"`.
  int? firstInt(String key) {
    final raw = first(key);
    if (raw == null) return null;
    final digits = RegExp(r'^\d+').firstMatch(raw.trim())?.group(0);
    return digits == null ? null : int.tryParse(digits);
  }

  bool get isEmpty => _byKey.isEmpty;
}
