import 'package:bluebubbles/helpers/network/metadata/sites/amazon_site_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/apple_maps_site_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/reddit_site_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/youtube_site_parser.dart';

/// Resolves the [SiteMetadataParser] responsible for a URL.
///
/// Registration order is match order, so put more specific parsers first if
/// two ever overlap.
abstract final class SiteParserRegistry {
  static const List<SiteMetadataParser> _parsers = [
    AppleMapsSiteParser(),
    YouTubeSiteParser(),
    AmazonSiteParser(),
    RedditSiteParser(),
  ];

  /// The parser handling [url], or null when the generic pipeline is enough.
  static SiteMetadataParser? forUrl(Uri url) {
    for (final parser in _parsers) {
      if (parser.matches(url)) return parser;
    }
    return null;
  }

  /// All registered parsers, for diagnostics.
  static List<SiteMetadataParser> get all => List.unmodifiable(_parsers);
}
