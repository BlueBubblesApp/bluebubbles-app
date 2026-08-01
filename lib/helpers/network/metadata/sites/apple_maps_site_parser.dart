import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';

/// Apple Maps place and location links.
///
/// Apple Maps pages carry Open Graph tags, but the `<title>` is more precise
/// than `og:title` and the page embeds the canonical place link in a widget
/// rather than in `<link rel="canonical">`. Both pieces of knowledge used to
/// live inline in `MetadataHelper.getLocationMetadata` and in the URL preview
/// widget's location branch; they belong here.
class AppleMapsSiteParser extends SiteMetadataParser {
  const AppleMapsSiteParser();

  @override
  String get name => 'Apple Maps';

  static const String _siteName = 'Apple Maps';

  /// The widget holding the "open in Maps" anchor.
  static const String _platterClass = 'sc-platter-cell';

  @override
  bool matches(Uri url) => MetadataUrls.hostMatchesAny(url.host, const ['maps.apple.com']);

  @override
  UrlMetadata refine(UrlMetadata base, MetadataParseContext context) {
    return base
        .copyWith(
          title: _placeTitle(context) ?? base.title,
          siteName: base.siteName ?? _siteName,
          canonicalUrl: _placeLink(context) ?? base.canonicalUrl,
          sources: {...base.sources, MetadataSource.siteParser},
        );
  }

  /// The place name, with Apple's `" - Apple Maps"`-style suffix removed.
  String? _placeTitle(MetadataParseContext context) {
    for (final element in context.document.getElementsByTagName('title')) {
      final text = element.text.trim();
      if (text.isEmpty) continue;

      // Apple appends a locality/product suffix after the last " - ".
      final split = text.lastIndexOf(' - ');
      final title = split > 0 ? text.substring(0, split).trim() : text;
      return title.isEmpty ? null : title;
    }
    return null;
  }

  /// The canonical `maps.apple.com/place?...` link embedded in the page.
  String? _placeLink(MetadataParseContext context) {
    for (final cell in context.document.getElementsByClassName(_platterClass)) {
      for (final child in cell.children) {
        if (child.localName != 'a') continue;
        final resolved = MetadataUrls.resolve(context.baseUri, child.attributes['href']);
        if (resolved != null) return resolved.toString();
      }
    }
    return null;
  }
}
