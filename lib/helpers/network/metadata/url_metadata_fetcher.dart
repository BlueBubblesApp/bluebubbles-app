import 'package:bluebubbles/helpers/network/metadata/cache/metadata_memory_cache.dart';
import 'package:bluebubbles/helpers/network/metadata/models/metadata_fetch_result.dart';
import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/network/html_body_decoder.dart';
import 'package:bluebubbles/helpers/network/metadata/network/metadata_http_client.dart';
import 'package:bluebubbles/helpers/network/metadata/network/oembed_resolver.dart';
import 'package:bluebubbles/helpers/network/metadata/network/preview_image_downloader.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_pipeline.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_metadata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/sites/site_parser_registry.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_text.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:html/parser.dart' as html_parser;

/// Fetches and parses link preview metadata for a URL.
///
/// The whole pipeline in one place:
///
/// ```
/// parse URL -> safety guard -> site parser prepare -> strip trackers
///           -> HTTP fetch (capped, charset-aware)
///           -> document pipeline (OG -> Twitter -> JSON-LD -> HTML -> ...)
///           -> oEmbed (only if a gap remains)
///           -> site parser refine
/// ```
///
/// Every stage failure produces a specific [MetadataFetchStatus] rather than a
/// thrown exception, so callers can distinguish "this link has no preview"
/// from "the network was down" and cache accordingly.
class UrlMetadataFetcher {
  UrlMetadataFetcher({
    MetadataHttpClient? client,
    MetadataMemoryCache? cache,
  })  : _client = client ?? MetadataHttpClient(),
        _cache = cache ?? MetadataMemoryCache() {
    _oEmbed = OEmbedResolver(_client);
    images = PreviewImageDownloader(_client);
  }

  final MetadataHttpClient _client;
  final MetadataMemoryCache _cache;
  late final OEmbedResolver _oEmbed;

  /// Downloads and disk-caches preview images found by this fetcher.
  late final PreviewImageDownloader images;

  /// Fetches metadata for [rawUrl].
  ///
  /// Concurrent calls for the same URL share one request, and a recent result
  /// is reused without touching the network.
  Future<MetadataFetchResult> fetch(String rawUrl) async {
    final requestUri = MetadataUrls.parse(rawUrl);
    if (requestUri == null) {
      return const MetadataFetchResult.failure(MetadataFetchStatus.invalidUrl);
    }

    final key = MetadataUrls.cacheKey(requestUri);
    return _cache.runOnce(key, () => _fetchUncached(requestUri));
  }

  /// Drops the memoised entry for [rawUrl] so the next fetch hits the network.
  void invalidate(String rawUrl) {
    final uri = MetadataUrls.parse(rawUrl);
    if (uri != null) _cache.invalidate(MetadataUrls.cacheKey(uri));
  }

  Future<MetadataFetchResult> _fetchUncached(Uri requestUri) async {
    final site = SiteParserRegistry.forUrl(requestUri);

    final prepared = _prepare(requestUri, site);

    // No safety check here: [MetadataHttpClient] guards every request it makes,
    // including each redirect hop and the oEmbed endpoint discovered from page
    // markup. A blocked host surfaces as a MetadataFetchException below.
    try {
      final resource = await _client.fetch(
        prepared,
        maxBytes: MetadataHttpClient.maxHtmlBytes,
        accept: const {FetchedContentKind.html, FetchedContentKind.image},
      );

      // The URL pointed straight at an image.
      if (resource.kind == FetchedContentKind.image) {
        return MetadataFetchResult.success(
          UrlMetadata(
            imageUrl: resource.finalUri.toString(),
            siteName: MetadataUrls.displayHost(resource.finalUri),
            requestUrl: requestUri.toString(),
            finalUrl: resource.finalUri.toString(),
            sources: const {MetadataSource.directImage},
            fetchedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          httpStatusCode: resource.statusCode,
        );
      }

      final body = HtmlBodyDecoder.decode(resource.bytes, contentType: resource.contentType);
      if (body.trim().isEmpty) {
        return MetadataFetchResult.failure(
          MetadataFetchStatus.empty,
          httpStatusCode: resource.statusCode,
          metadata: _fallbackFor(requestUri, site),
        );
      }

      final context = MetadataParseContext(
        document: html_parser.parse(body),
        requestUri: requestUri,
        finalUri: resource.finalUri,
      );

      var metadata = MetadataDocumentPipeline.run(context);

      // oEmbed costs an extra request, so it is only consulted when the
      // document left a gap the card would actually show.
      if (metadata.title == null || metadata.imageUrl == null) {
        final oembed = await _oEmbed.resolve(prepared, context: context);
        if (oembed != null) metadata = metadata.fillMissingFrom(oembed.normalized(context.baseUri));
      }

      if (site != null) {
        metadata = _refine(site, metadata, context);
      }

      metadata = _finalize(metadata, requestUri, resource.finalUri);

      if (metadata.isEmpty) {
        return MetadataFetchResult.failure(
          MetadataFetchStatus.empty,
          httpStatusCode: resource.statusCode,
          metadata: _fallbackFor(requestUri, site),
        );
      }

      return MetadataFetchResult.success(metadata, httpStatusCode: resource.statusCode);
    } on MetadataFetchException catch (ex) {
      Logger.debug('Metadata fetch failed for $prepared: $ex', tag: 'UrlMetadataFetcher');
      return MetadataFetchResult.failure(
        ex.status,
        httpStatusCode: ex.httpStatusCode,
        error: ex.cause,
        metadata: _fallbackFor(requestUri, site),
      );
    } catch (ex, stack) {
      Logger.warn('Unexpected error fetching metadata for $prepared',
          error: ex, trace: stack, tag: 'UrlMetadataFetcher');
      return MetadataFetchResult.failure(
        MetadataFetchStatus.parseError,
        error: ex,
        metadata: _fallbackFor(requestUri, site),
      );
    }
  }

  Uri _prepare(Uri requestUri, SiteMetadataParser? site) {
    try {
      final prepared = site?.prepare(requestUri) ?? requestUri;
      return MetadataUrls.stripTrackingParams(prepared);
    } catch (ex) {
      Logger.debug('Site parser ${site?.name} failed to prepare $requestUri: $ex', tag: 'UrlMetadataFetcher');
      return MetadataUrls.stripTrackingParams(requestUri);
    }
  }

  UrlMetadata _refine(SiteMetadataParser site, UrlMetadata metadata, MetadataParseContext context) {
    try {
      return site.refine(metadata, context).normalized(context.baseUri);
    } catch (ex, stack) {
      Logger.debug('Site parser ${site.name} failed to refine ${context.finalUri}: $ex',
          error: ex, trace: stack, tag: 'UrlMetadataFetcher');
      return metadata;
    }
  }

  /// What a site parser can say about a URL without a successful fetch.
  ///
  /// Attached to failure results so a bot-blocked link still renders a
  /// recognisable card. Never used to fabricate a title or description.
  UrlMetadata? _fallbackFor(Uri requestUri, SiteMetadataParser? site) {
    UrlMetadata? fallback;
    try {
      fallback = site?.fallback(requestUri);
    } catch (_) {
      fallback = null;
    }

    final host = MetadataUrls.displayHost(requestUri);
    final merged = (fallback ?? UrlMetadata.empty).copyWith(
      siteName: fallback?.siteName ?? host,
      requestUrl: requestUri.toString(),
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return merged.isEmpty ? null : merged;
  }

  /// Applies the finishing touches every successful result gets.
  UrlMetadata _finalize(UrlMetadata metadata, Uri requestUri, Uri finalUri) {
    // Fall back to the host for the site line so the card is never blank, and
    // drop a title that merely repeats it.
    final siteName = metadata.siteName ?? MetadataUrls.displayHost(finalUri);

    return metadata.copyWith(
      title: _titleFor(metadata, siteName),
      siteName: siteName,
      requestUrl: requestUri.toString(),
      finalUrl: finalUri.toString(),
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? _titleFor(UrlMetadata metadata, String? siteName) {
    final title = metadata.title;
    if (title == null) return null;
    if (siteName == null) return title;

    // Most sites suffix their title with the site name; the card renders the
    // site on its own line, so the suffix is pure duplication.
    final stripped = MetadataText.stripSiteSuffix(title, siteName);
    return stripped == null || stripped.isEmpty ? title : stripped;
  }

  /// Releases the underlying HTTP connections.
  void dispose() {
    _cache.clear();
    _client.close();
  }
}
