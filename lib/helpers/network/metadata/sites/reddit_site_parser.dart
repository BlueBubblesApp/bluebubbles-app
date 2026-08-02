import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:bluebubbles/helpers/types/extensions/extensions.dart';

/// Reddit posts, comments and share links.
///
/// The mobile and AMP hosts serve markup without usable metadata, and share
/// links carry a long tail of correlation parameters. Normalising both onto
/// `www.reddit.com` is enough to get proper Open Graph tags back.
class RedditSiteParser extends SiteMetadataParser {
  const RedditSiteParser();

  @override
  String get name => 'Reddit';

  static const String _siteName = 'Reddit';

  static const List<String> _hosts = ['reddit.com', 'redd.it', 'redditmedia.com'];

  /// Share-tracking parameters Reddit's apps append.
  static const Set<String> _noiseParams = {
    'share_id',
    'context',
    'correlation_id',
    'ref',
    'ref_source',
    'ref_campaign',
    'post_fullname',
    'rdt',
    r'$deep_link',
    r'$original_url',
    '_branch_match_id',
    '_branch_referrer',
    'chainedposts',
  };

  /// Hosts that need rewriting to the canonical desktop host.
  static const Set<String> _alternateHosts = {
    'm.reddit.com',
    'i.reddit.com',
    'amp.reddit.com',
    'old.reddit.com',
    'np.reddit.com',
    'new.reddit.com',
    'sh.reddit.com',
  };

  @override
  bool matches(Uri url) => url.hostMatchesAny(_hosts);

  @override
  Uri prepare(Uri url) {
    final stripped = MetadataUrls.stripTrackingParams(url, extra: _noiseParams);

    // `redd.it` short links and the media host redirect on their own; only the
    // alternate reddit.com subdomains need rewriting.
    if (!_alternateHosts.contains(stripped.host.toLowerCase())) return stripped;
    return stripped.replace(host: 'www.reddit.com');
  }

  @override
  UrlMetadata refine(UrlMetadata base, MetadataParseContext context) {
    return base.copyWith(
      siteName: base.siteName ?? _siteName,
      sources: {...base.sources, MetadataSource.siteParser},
    );
  }
}
