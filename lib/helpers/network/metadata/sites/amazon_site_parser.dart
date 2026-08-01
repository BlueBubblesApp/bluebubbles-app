import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:html/dom.dart';

/// Amazon product pages.
///
/// Amazon emits almost no Open Graph data, buries the product title and hero
/// image in well-known element IDs, and pads its URLs with tracking segments
/// that make every share of the same product look like a different page. It
/// also serves the `renderTimingPixel.png` beacon that the old implementation
/// had to blocklist by name downstream.
class AmazonSiteParser extends SiteMetadataParser {
  const AmazonSiteParser();

  @override
  String get name => 'Amazon';

  static const String _siteName = 'Amazon';

  /// Amazon's storefronts plus the two short-link domains.
  static const List<String> _hosts = [
    'amazon.com',
    'amazon.co.uk',
    'amazon.ca',
    'amazon.de',
    'amazon.fr',
    'amazon.it',
    'amazon.es',
    'amazon.nl',
    'amazon.se',
    'amazon.pl',
    'amazon.com.au',
    'amazon.co.jp',
    'amazon.in',
    'amazon.com.br',
    'amazon.com.mx',
    'amazon.ae',
    'amazon.sa',
    'amazon.sg',
    'a.co',
    'amzn.to',
    'amzn.eu',
    'amzn.asia',
  ];

  /// Query parameters Amazon appends for attribution and session tracking.
  static const Set<String> _noiseParams = {
    'ref',
    'ref_',
    'tag',
    'linkcode',
    'linkid',
    'creative',
    'creativeasin',
    'ascsubtag',
    'psc',
    'th',
    'qid',
    'sr',
    'sprefix',
    'crid',
    'keywords',
    'dib',
    'dib_tag',
    'content-id',
    'pd_rd_i',
    'pd_rd_r',
    'pd_rd_w',
    'pd_rd_wg',
    'pf_rd_i',
    'pf_rd_m',
    'pf_rd_p',
    'pf_rd_r',
    'pf_rd_s',
    'pf_rd_t',
    '_encoding',
    'smid',
  };

  /// Element IDs holding the product title, best first.
  static const List<String> _titleIds = ['productTitle', 'title', 'btAsinTitle'];

  /// Element IDs holding the hero image.
  static const List<String> _imageIds = ['landingImage', 'imgBlkFront', 'main-image', 'ebooksImgBlkFront'];

  /// Attributes on the hero image, highest resolution first.
  static const List<String> _imageAttributes = ['data-old-hires', 'data-a-hires', 'src'];

  /// Product paths look like `/dp/<ASIN>` or `/gp/product/<ASIN>`.
  static final RegExp _asin = RegExp(r'^[A-Z0-9]{10}$');

  @override
  bool matches(Uri url) => MetadataUrls.hostMatchesAny(url.host, _hosts);

  @override
  Uri prepare(Uri url) {
    final stripped = MetadataUrls.stripTrackingParams(url, extra: _noiseParams);

    final asin = _asinFromPath(stripped);
    if (asin == null) return stripped;

    // Collapse the SEO-padded path down to the canonical product URL, which is
    // both smaller and identical across everyone who shares the same item.
    // `resolve` keeps the scheme, host and port while dropping the query and
    // fragment outright, which `replace` cannot express.
    return stripped.resolve('/dp/$asin');
  }

  @override
  UrlMetadata refine(UrlMetadata base, MetadataParseContext context) {
    final document = context.document;

    final image = _heroImage(document);
    // Amazon's beacon lives on a separate host and is never a product image.
    final keepExisting = base.imageUrl != null && !_isBeacon(base.imageUrl!);

    return base.copyWith(
      title: base.title ?? _firstById(document, _titleIds),
      imageUrl: keepExisting ? base.imageUrl : image,
      siteName: base.siteName ?? _siteName,
      sources: {...base.sources, MetadataSource.siteParser},
    );
  }

  String? _asinFromPath(Uri url) {
    final segments = url.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i].toLowerCase();
      if (segment != 'dp' && segment != 'product' && segment != 'gp') continue;

      final candidate = segments[i + 1].toUpperCase();
      if (_asin.hasMatch(candidate)) return candidate;
    }

    // `/gp/product/<ASIN>` puts the ASIN two segments along.
    for (var i = 0; i < segments.length - 2; i++) {
      if (segments[i].toLowerCase() != 'gp') continue;
      final candidate = segments[i + 2].toUpperCase();
      if (_asin.hasMatch(candidate)) return candidate;
    }

    return null;
  }

  String? _firstById(Document document, List<String> ids) {
    for (final id in ids) {
      final text = document.getElementById(id)?.text.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String? _heroImage(Document document) {
    for (final id in _imageIds) {
      final element = document.getElementById(id);
      if (element == null) continue;

      for (final attribute in _imageAttributes) {
        final value = element.attributes[attribute]?.trim();
        if (value == null || value.isEmpty || value.startsWith('data:')) continue;
        if (_isBeacon(value)) continue;
        return value;
      }
    }
    return null;
  }

  /// Amazon's page-timing beacon, which is a 1x1 GIF.
  bool _isBeacon(String url) {
    final lower = url.toLowerCase();
    return lower.contains('fls-na.amazon') || lower.contains('rendertimingpixel') || lower.contains('/1x1.');
  }
}
