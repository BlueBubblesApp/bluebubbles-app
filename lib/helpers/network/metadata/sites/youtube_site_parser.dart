import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';

/// YouTube links in all their forms.
///
/// Worth special-casing for two reasons: the short and embed URL shapes do not
/// serve metadata directly, and every video has a predictable thumbnail URL,
/// so a preview image is available even when the page itself gives us nothing.
class YouTubeSiteParser extends SiteMetadataParser {
  const YouTubeSiteParser();

  @override
  String get name => 'YouTube';

  static const String _siteName = 'YouTube';

  static const List<String> _hosts = ['youtube.com', 'youtu.be', 'youtube-nocookie.com'];

  /// Path prefixes that carry the video ID as the next segment.
  static const List<String> _idBearingSegments = ['shorts', 'live', 'embed', 'v'];

  /// Share and playlist-position parameters that fragment the cache without
  /// changing which video loads.
  static const Set<String> _noiseParams = {'si', 'pp', 'feature', 'ab_channel', 'app', 'start_radio'};

  /// Video IDs are always 11 URL-safe base64 characters.
  static final RegExp _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  @override
  bool matches(Uri url) => MetadataUrls.hostMatchesAny(url.host, _hosts);

  @override
  Uri prepare(Uri url) {
    final id = videoId(url);
    if (id == null) {
      // Not a video link (a channel, a search). Still worth normalising the
      // mobile host so the desktop markup is served.
      return MetadataUrls.stripTrackingParams(_desktopHost(url), extra: _noiseParams);
    }

    // Collapse every shape onto the canonical watch URL, preserving a playlist
    // timestamp if one was present.
    final query = <String, String>{'v': id};
    final start = url.queryParameters['t'] ?? url.queryParameters['start'];
    if (start != null && start.isNotEmpty) query['t'] = start;

    return Uri.https('www.youtube.com', '/watch', query);
  }

  @override
  UrlMetadata refine(UrlMetadata base, MetadataParseContext context) {
    final id = videoId(context.requestUri) ?? videoId(context.finalUri);

    return base.copyWith(
      siteName: base.siteName ?? _siteName,
      imageUrl: base.imageUrl ?? (id == null ? null : thumbnailUrl(id)),
      sources: {...base.sources, MetadataSource.siteParser},
    );
  }

  @override
  UrlMetadata? fallback(Uri url) {
    final id = videoId(url);
    if (id == null) return null;

    // No title or description is invented here — only the two facts that
    // follow directly from the URL.
    return UrlMetadata(
      siteName: _siteName,
      imageUrl: thumbnailUrl(id),
      imageWidth: 480,
      imageHeight: 360,
      sources: const {MetadataSource.siteParser},
    );
  }

  /// The canonical thumbnail for [id].
  ///
  /// `hqdefault` is used rather than `maxresdefault` because it exists for
  /// every video, including ones never uploaded in HD — `maxresdefault`
  /// 404s for those, which would show a broken image.
  static String thumbnailUrl(String id) => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  /// Extracts the video ID from any YouTube URL shape, or null.
  static String? videoId(Uri url) {
    if (!MetadataUrls.hostMatchesAny(url.host, _hosts)) return null;

    // youtu.be/<id>
    if (MetadataUrls.hostMatches(url.host, 'youtu.be')) {
      final first = url.pathSegments.isEmpty ? null : url.pathSegments.first;
      return _validate(first);
    }

    // /watch?v=<id>
    final queryId = _validate(url.queryParameters['v']);
    if (queryId != null) return queryId;

    // /shorts/<id>, /live/<id>, /embed/<id>, /v/<id>
    final segments = url.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (_idBearingSegments.contains(segments[i].toLowerCase())) {
        return _validate(segments[i + 1]);
      }
    }

    return null;
  }

  static String? _validate(String? candidate) {
    if (candidate == null) return null;
    final trimmed = candidate.trim();
    return _videoId.hasMatch(trimmed) ? trimmed : null;
  }

  Uri _desktopHost(Uri url) {
    if (MetadataUrls.hostMatches(url.host, 'youtube.com') && url.host.toLowerCase() != 'www.youtube.com') {
      return url.replace(host: 'www.youtube.com');
    }
    return url;
  }
}
