import 'package:bluebubbles/helpers/network/metadata/parsing/meta_tag_index.dart';
import 'package:html/dom.dart';

/// Everything a parser needs to read one document.
///
/// Built once per fetch and handed to every parser, so the DOM is walked once
/// and the meta-tag index is shared.
class MetadataParseContext {
  MetadataParseContext._({
    required this.document,
    required this.metaTags,
    required this.requestUri,
    required this.finalUri,
    required this.baseUri,
  });

  /// The parsed document.
  final Document document;

  /// Indexed `<meta>` tags.
  final MetaTagIndex metaTags;

  /// The URL originally requested (what the user tapped).
  final Uri requestUri;

  /// The URL the request landed on after following redirects.
  final Uri finalUri;

  /// The base for resolving relative URLs: the document's `<base href>` when
  /// it declares one, otherwise [finalUri].
  ///
  /// Resolving against the *final* URL rather than the requested one matters
  /// for shorteners — a relative `/img/hero.png` on the page a `t.co` link
  /// redirects to belongs to the destination host, not to `t.co`.
  final Uri baseUri;

  factory MetadataParseContext({
    required Document document,
    required Uri requestUri,
    required Uri finalUri,
  }) {
    return MetadataParseContext._(
      document: document,
      metaTags: MetaTagIndex.fromDocument(document),
      requestUri: requestUri,
      finalUri: finalUri,
      baseUri: _resolveBase(document, finalUri),
    );
  }

  static Uri _resolveBase(Document document, Uri finalUri) {
    for (final element in document.getElementsByTagName('base')) {
      final href = element.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;
      try {
        final resolved = finalUri.resolve(href);
        if (resolved.scheme == 'http' || resolved.scheme == 'https') return resolved;
      } on FormatException {
        // Malformed <base href>; fall through to the request URL.
      }
    }
    return finalUri;
  }
}
