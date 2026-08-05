import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// Extracts the site icon from `<link rel="...icon">` tags.
///
/// The preview card has always had a slot for an icon, but nothing ever filled
/// it for fetched previews — only server-supplied Apple payloads had one. This
/// closes that gap.
class IconParser extends MetadataDocumentParser {
  const IconParser();

  @override
  MetadataSource get source => MetadataSource.htmlMeta;

  /// `rel` tokens that identify an icon, best first.
  ///
  /// Apple touch icons are preferred because they are guaranteed to be a
  /// reasonable size and are almost always PNG; `mask-icon` is last because it
  /// is a monochrome SVG that renders poorly at card size.
  static const List<String> _iconRels = [
    'apple-touch-icon',
    'apple-touch-icon-precomposed',
    'fluid-icon',
    'icon',
    'shortcut',
    'mask-icon',
  ];

  /// Icons smaller than this are too blurry for the card.
  static const int _minSize = 32;

  /// Anything larger is a wasteful download for a 45px slot.
  static const int _maxSize = 512;

  @override
  UrlMetadata parse(MetadataParseContext context) {
    _Candidate? best;

    for (final element in context.document.getElementsByTagName('link')) {
      final rel = element.attributes['rel']?.trim().toLowerCase();
      if (rel == null || rel.isEmpty) continue;

      final tokens = rel.split(RegExp(r'\s+'));
      final relIndex = _relPriority(tokens);
      if (relIndex == null) continue;

      final href = element.attributes['href']?.trim();
      if (href == null || href.isEmpty || href.startsWith('data:')) continue;

      // SVG icons cannot be rendered by the Image widget the card uses.
      final type = element.attributes['type']?.trim().toLowerCase();
      if (type == 'image/svg+xml' || href.toLowerCase().endsWith('.svg')) continue;

      final candidate = _Candidate(href, relIndex, _largestSize(element.attributes['sizes']));
      if (best == null || candidate.isBetterThan(best)) best = candidate;
    }

    if (best != null) return build(iconUrl: best.href);

    // Every site serves /favicon.ico from the origin whether or not it
    // declares one, so fall back to that. `resolve` preserves scheme, host and
    // port while dropping the path, query and fragment.
    return build(iconUrl: context.baseUri.resolve('/favicon.ico').toString());
  }

  /// The index of the best-matching rel token, or `null` when none match.
  int? _relPriority(List<String> tokens) {
    for (var i = 0; i < _iconRels.length; i++) {
      if (tokens.contains(_iconRels[i])) return i;
    }
    return null;
  }

  /// Parses a `sizes="16x16 32x32"` attribute and returns the largest usable
  /// edge length, or `null` for `any`/absent.
  int? _largestSize(String? sizes) {
    if (sizes == null) return null;
    final trimmed = sizes.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'any') return null;

    int? largest;
    for (final token in trimmed.split(RegExp(r'\s+'))) {
      final edge = int.tryParse(token.split('x').first);
      if (edge == null) continue;
      if (largest == null || edge > largest) largest = edge;
    }
    return largest;
  }

  static bool _isUsableSize(int? size) => size == null || (size >= _minSize && size <= _maxSize);
}

class _Candidate {
  _Candidate(this.href, this.relIndex, this.size);

  final String href;
  final int relIndex;
  final int? size;

  bool get isUsableSize => IconParser._isUsableSize(size);

  /// Prefers a usable size, then the higher-priority `rel`, then the larger
  /// icon (which downscales better than a 16px favicon upscales).
  bool isBetterThan(_Candidate other) {
    if (isUsableSize != other.isUsableSize) return isUsableSize;
    if (relIndex != other.relIndex) return relIndex < other.relIndex;
    return (size ?? 0) > (other.size ?? 0);
  }
}
