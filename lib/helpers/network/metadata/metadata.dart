/// URL preview metadata extraction.
///
/// Import this barrel rather than the individual files. The public surface is
/// [MetadataHelper] (in `helpers/network/metadata_helper.dart`, re-exported by
/// `helpers/helpers.dart`) plus the model types below.
///
/// Layout:
///
/// | Directory  | Responsibility |
/// |------------|----------------|
/// | `models/`  | [UrlMetadata], [MetadataFetchResult], source/status enums |
/// | `parsing/` | Document parsers and the pipeline that merges them |
/// | `network/` | HTTP client, safety guard, charset decoding, oEmbed, images |
/// | `sites/`   | Per-site knowledge, registered in `SiteParserRegistry` |
/// | `cache/`   | In-memory single-flight cache and message persistence |
library;

export 'cache/message_metadata_store.dart';
export 'cache/metadata_memory_cache.dart';
export 'models/metadata_fetch_result.dart';
export 'models/metadata_source.dart';
export 'models/url_metadata.dart';
export 'network/metadata_http_client.dart' show MetadataHttpClient, FetchedContentKind;
export 'network/preview_image_downloader.dart' show CachedPreviewImage, PreviewImageDownloader;
export 'network/url_safety_guard.dart';
export 'sites/site_metadata_parser.dart';
export 'sites/site_parser_registry.dart';
export 'url_metadata_fetcher.dart';
export 'util/metadata_text.dart';
export 'util/site_display_names.dart';
export 'util/metadata_urls.dart';
