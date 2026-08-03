import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:html/dom.dart';

/// Last-resort preview image, picked out of the page body.
///
/// The pipeline only runs this when no declared image was found anywhere, so
/// the DOM walk is paid for solely by pages with no metadata at all.
///
/// The previous implementation took the *first* `<img>` in the body, which on
/// most pages is a logo, a spacer, or a tracking pixel — that is why the old
/// code needed hardcoded `renderTimingPixel.png` and `fls-na.amazon.com`
/// blocklists downstream. Scoring by intent and declared size generalises
/// instead of chasing individual hostnames, and the downloader independently
/// rejects anything that turns out to be tiny.
class BodyImageParser extends MetadataDocumentParser {
  const BodyImageParser();

  @override
  MetadataSource get source => MetadataSource.htmlMeta;

  /// Never look at more than this many images; long pages have thousands.
  static const int _maxImagesScanned = 40;

  /// Below this, a declared dimension means decoration rather than content.
  static const int _minDeclaredDimension = 120;

  /// Substrings that mark an image as chrome. Matched against the lowercased
  /// URL.
  static const List<String> _chromeImagePatterns = [
    'pixel',
    'tracking',
    'tracker',
    'beacon',
    'spacer',
    'blank.gif',
    'transparent.',
    'clear.gif',
    '1x1',
    'analytics',
    'doubleclick',
    'scorecardresearch',
    'sprite',
    'logo',
    'avatar',
    'placeholder',
    'loading.',
    'spinner',
    '/ads/',
    'advert',
  ];

  /// Ancestors whose images are page chrome rather than content.
  static const Set<String> _chromeContainers = {'header', 'nav', 'footer', 'aside'};

  /// ARIA landmark roles equivalent to [_chromeContainers].
  static const Set<String> _chromeRoles = {'banner', 'navigation', 'contentinfo', 'search', 'complementary'};

  @override
  UrlMetadata parse(MetadataParseContext context) {
    final body = context.document.body;
    if (body == null) return UrlMetadata.empty;

    String? bestSized;
    var bestArea = 0;
    int? bestWidth;
    int? bestHeight;
    String? firstUnsized;

    var scanned = 0;
    for (final image in body.getElementsByTagName('img')) {
      if (++scanned > _maxImagesScanned) break;

      final src = _imageSource(image);
      if (src == null) continue;
      if (_looksLikeChrome(src)) continue;
      if (_isInChrome(image)) continue;

      final width = _dimension(image, 'width');
      final height = _dimension(image, 'height');

      if (width != null && height != null) {
        if (width < _minDeclaredDimension || height < _minDeclaredDimension) continue;
        final area = width * height;
        if (area > bestArea) {
          bestArea = area;
          bestSized = src;
          bestWidth = width;
          bestHeight = height;
        }
        continue;
      }

      firstUnsized ??= src;
    }

    if (bestSized != null) {
      return build(imageUrl: bestSized, imageWidth: bestWidth, imageHeight: bestHeight);
    }
    return build(imageUrl: firstUnsized);
  }

  /// The real source of an image, accounting for lazy-loading attributes that
  /// leave `src` pointing at a placeholder.
  String? _imageSource(Element image) {
    final attributes = image.attributes;

    for (final attribute in const ['data-src', 'data-original', 'data-lazy-src', 'src']) {
      final value = attributes[attribute]?.trim();
      if (value == null || value.isEmpty) continue;
      // Inline data URIs cannot be downloaded and are almost always
      // placeholders for a lazy-loaded image.
      if (value.startsWith('data:')) continue;
      return value;
    }

    // `srcset` as a last resort: take the first candidate.
    final srcset = attributes['srcset']?.trim() ?? attributes['data-srcset']?.trim();
    if (srcset != null && srcset.isNotEmpty) {
      final first = srcset.split(',').first.trim().split(RegExp(r'\s+')).first;
      if (first.isNotEmpty && !first.startsWith('data:')) return first;
    }

    return null;
  }

  bool _looksLikeChrome(String src) {
    final lower = src.toLowerCase();
    for (final pattern in _chromeImagePatterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  bool _isInChrome(Element element) {
    var parent = element.parent;
    var depth = 0;
    while (parent != null && depth++ < 12) {
      final name = parent.localName?.toLowerCase();
      if (name != null && _chromeContainers.contains(name)) return true;

      final role = parent.attributes['role']?.trim().toLowerCase();
      if (role != null && _chromeRoles.contains(role)) return true;

      parent = parent.parent;
    }
    return false;
  }

  int? _dimension(Element image, String attribute) {
    final raw = image.attributes[attribute]?.trim();
    if (raw == null || raw.isEmpty) return null;
    final digits = RegExp(r'^\d+').firstMatch(raw)?.group(0);
    return digits == null ? null : int.tryParse(digits);
  }
}
