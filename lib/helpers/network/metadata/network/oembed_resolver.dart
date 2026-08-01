import 'dart:convert';

import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/network/html_body_decoder.dart';
import 'package:bluebubbles/helpers/network/metadata/network/metadata_http_client.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// A provider that exposes an oEmbed endpoint.
class OEmbedProvider {
  const OEmbedProvider({required this.name, required this.endpoint, required this.hosts});

  /// Display name, used as the site name when the response omits one.
  final String name;

  /// The JSON endpoint. The page URL is appended as the `url` parameter.
  final String endpoint;

  /// Hosts (and their subdomains) this provider serves.
  final List<String> hosts;

  bool matches(Uri uri) => MetadataUrls.hostMatchesAny(uri.host, hosts);
}

/// Fetches oEmbed metadata for pages that expose it.
///
/// oEmbed is how video and audio platforms publish clean titles and
/// thumbnails. Several of them (notably YouTube) serve richer data here than
/// they put in their Open Graph tags, and some serve oEmbed to clients they
/// would otherwise answer with a consent interstitial.
///
/// Only consulted when the document pipeline left a gap, so the common case
/// still costs exactly one request.
class OEmbedResolver {
  OEmbedResolver(this._client);

  final MetadataHttpClient _client;

  /// Providers worth a lookup without any discovery tag present.
  static const List<OEmbedProvider> knownProviders = [
    OEmbedProvider(
      name: 'YouTube',
      endpoint: 'https://www.youtube.com/oembed',
      hosts: ['youtube.com', 'youtu.be', 'youtube-nocookie.com'],
    ),
    OEmbedProvider(
      name: 'Vimeo',
      endpoint: 'https://vimeo.com/api/oembed.json',
      hosts: ['vimeo.com'],
    ),
    OEmbedProvider(
      name: 'SoundCloud',
      endpoint: 'https://soundcloud.com/oembed',
      hosts: ['soundcloud.com'],
    ),
    OEmbedProvider(
      name: 'Spotify',
      endpoint: 'https://open.spotify.com/oembed',
      hosts: ['spotify.com'],
    ),
    OEmbedProvider(
      name: 'Flickr',
      endpoint: 'https://www.flickr.com/services/oembed',
      hosts: ['flickr.com', 'flic.kr'],
    ),
    OEmbedProvider(
      name: 'TikTok',
      endpoint: 'https://www.tiktok.com/oembed',
      hosts: ['tiktok.com'],
    ),
    OEmbedProvider(
      name: 'Reddit',
      endpoint: 'https://www.reddit.com/oembed',
      hosts: ['reddit.com', 'redd.it'],
    ),
    OEmbedProvider(
      name: 'Giphy',
      endpoint: 'https://giphy.com/services/oembed',
      hosts: ['giphy.com', 'gph.is'],
    ),
    OEmbedProvider(
      name: 'Dailymotion',
      endpoint: 'https://www.dailymotion.com/services/oembed',
      hosts: ['dailymotion.com', 'dai.ly'],
    ),
  ];

  /// Resolves oEmbed metadata for [pageUrl].
  ///
  /// [context] supplies the discovery tag when the page was fetched; pass null
  /// to rely on [knownProviders] alone. Returns null when there is no endpoint
  /// or the lookup fails — oEmbed is always an enhancement, never a
  /// requirement.
  Future<UrlMetadata?> resolve(Uri pageUrl, {MetadataParseContext? context}) async {
    final endpoint = _discoverEndpoint(pageUrl, context);
    if (endpoint == null) return null;

    try {
      final resource = await _client.fetch(
        endpoint.uri,
        maxBytes: MetadataHttpClient.maxJsonBytes,
        accept: const {FetchedContentKind.json, FetchedContentKind.html},
      );

      final body = HtmlBodyDecoder.decode(resource.bytes, contentType: resource.contentType);
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;

      return _fromJson(decoded.cast<String, dynamic>(), endpoint.providerName);
    } catch (ex) {
      Logger.debug('oEmbed lookup failed for $pageUrl: $ex', tag: 'OEmbedResolver');
      return null;
    }
  }

  _Endpoint? _discoverEndpoint(Uri pageUrl, MetadataParseContext? context) {
    // A discovery tag on the page is authoritative.
    if (context != null) {
      for (final element in context.document.getElementsByTagName('link')) {
        final type = element.attributes['type']?.trim().toLowerCase();
        if (type != 'application/json+oembed' && type != 'text/json+oembed') continue;

        final rel = element.attributes['rel']?.trim().toLowerCase();
        if (rel != null && rel.isNotEmpty && !rel.split(RegExp(r'\s+')).contains('alternate')) continue;

        final href = MetadataUrls.resolve(context.baseUri, element.attributes['href']);
        if (href != null) return _Endpoint(href, null);
      }
    }

    for (final provider in knownProviders) {
      if (!provider.matches(pageUrl)) continue;
      final endpoint = Uri.parse(provider.endpoint).replace(queryParameters: {
        'url': pageUrl.toString(),
        'format': 'json',
      });
      return _Endpoint(endpoint, provider.name);
    }

    return null;
  }

  UrlMetadata _fromJson(Map<String, dynamic> json, String? fallbackProvider) {
    final width = _int(json['thumbnail_width']);
    final height = _int(json['thumbnail_height']);

    return UrlMetadata(
      title: _string(json['title']),
      // oEmbed has no description field. `author_name` is the closest useful
      // thing for video/audio, and is what the platforms' own embeds show.
      description: _string(json['author_name']),
      imageUrl: _string(json['thumbnail_url']),
      imageWidth: width,
      imageHeight: height,
      siteName: _string(json['provider_name']) ?? fallbackProvider,
      canonicalUrl: _string(json['web_page']) ?? _string(json['author_url']),
      sources: const {MetadataSource.oEmbed},
    );
  }

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _Endpoint {
  const _Endpoint(this.uri, this.providerName);

  final Uri uri;
  final String? providerName;
}
