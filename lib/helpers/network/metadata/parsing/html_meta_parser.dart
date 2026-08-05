import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:html/dom.dart';

/// Plain HTML: `<title>`, `<meta name="description">`, `<link rel="canonical">`.
///
/// Runs after the structured vocabularies, so it only ever fills gaps they
/// left. Picking an image out of the page body is deliberately *not* done here
/// — see [BodyImageParser], which the pipeline only runs when nothing else
/// produced an image.
class HtmlMetaParser extends MetadataDocumentParser {
  const HtmlMetaParser();

  @override
  MetadataSource get source => MetadataSource.htmlMeta;

  @override
  UrlMetadata parse(MetadataParseContext context) {
    final tags = context.metaTags;
    final document = context.document;

    return build(
      title: _documentTitle(document),
      description: tags.firstOf(const ['description', 'dc.description', 'sailthru.description']),
      // `rel="image_src"` is the pre-Open-Graph standard and is still emitted
      // by older CMSes. It is an explicit declaration, unlike a body scan.
      imageUrl: _linkHref(document, const {'image_src'}),
      siteName: tags.firstOf(const ['application-name', 'apple-mobile-web-app-title', 'dc.publisher']),
      canonicalUrl: _linkHref(document, const {'canonical'}),
      themeColor: tags.first('theme-color'),
    );
  }

  String? _documentTitle(Document document) {
    for (final element in document.getElementsByTagName('title')) {
      final text = element.text.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// The `href` of the first `<link>` whose `rel` contains one of [rels].
  String? _linkHref(Document document, Set<String> rels) {
    for (final element in document.getElementsByTagName('link')) {
      final rel = element.attributes['rel']?.trim().toLowerCase();
      if (rel == null || rel.isEmpty) continue;
      // `rel` is a space-separated token list.
      if (!rel.split(RegExp(r'\s+')).any(rels.contains)) continue;

      final href = element.attributes['href']?.trim();
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }
}
