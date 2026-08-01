import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/network/metadata/metadata.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:universal_io/io.dart';

export 'package:bluebubbles/helpers/network/metadata/metadata.dart';

/// Entry point for URL preview metadata.
///
/// A thin facade over the pipeline in `helpers/network/metadata/` — see
/// `metadata/metadata.dart` for the layout. Widgets should only ever need
/// [fetchForMessage], [resolveCachedImage] and the [MessageMetadataStore]
/// helpers re-exported here.
abstract final class MetadataHelper {
  static UrlMetadataFetcher? _fetcher;

  /// The shared fetcher. Created lazily so that app startup does not pay for
  /// an HTTP client nobody may use.
  static UrlMetadataFetcher get fetcher => _fetcher ??= UrlMetadataFetcher();

  /// Replaces the shared fetcher. Test seam.
  @visibleForTesting
  static set fetcher(UrlMetadataFetcher value) {
    _fetcher?.dispose();
    _fetcher = value;
  }

  /// Whether the user has left automatic link preview fetching enabled.
  ///
  /// Fetching a preview for a link somebody else sent discloses the user's IP
  /// address and rough read time to whoever controls that URL, so it is worth
  /// being able to turn off. Server-supplied previews (Apple's own payload
  /// data) are unaffected.
  static bool get fetchingEnabled => SettingsSvc.settings.fetchUrlPreviews.value;

  // ---------------------------------------------------------------------------
  // Fetching
  // ---------------------------------------------------------------------------

  /// Fetches metadata for [message]'s URL, or for [urlOverride] when the link
  /// lives somewhere other than the message text (a Photos share link in the
  /// payload data, for example).
  ///
  /// Returns a [MetadataFetchResult] rather than throwing so callers can tell
  /// a permanent failure from a transient one — see
  /// [MetadataFetchResult.isRetryable].
  static Future<MetadataFetchResult> fetchForMessage(
    Message message, {
    String? urlOverride,
  }) async {
    if (!fetchingEnabled) {
      return const MetadataFetchResult.failure(MetadataFetchStatus.disabledByUser);
    }

    final url = urlOverride ?? message.url;
    if (url == null || url.trim().isEmpty) {
      return const MetadataFetchResult.failure(MetadataFetchStatus.invalidUrl);
    }

    return fetcher.fetch(url);
  }

  /// Fetches metadata for a bare URL, outside any message context.
  static Future<MetadataFetchResult> fetchForUrl(String url) {
    if (!fetchingEnabled) {
      return Future.value(const MetadataFetchResult.failure(MetadataFetchStatus.disabledByUser));
    }
    return fetcher.fetch(url);
  }

  /// Forgets any memoised result for [url] so the next fetch hits the network.
  static void invalidate(String url) => fetcher.invalidate(url);

  /// Forgets every memoised result reachable from [message].
  ///
  /// Clearing `message.metadata` alone is not enough to force a refresh: the
  /// in-memory cache is keyed by URL and would keep serving the previous
  /// result. The manual "refresh preview" action needs both.
  static void invalidateForMessage(Message message) {
    final urls = <String>{
      if (message.url != null) message.url!,
      for (final data in message.payloadData?.urlData ?? const <UrlPreviewData>[]) ...[
        if (data.url != null) data.url!,
        if (data.originalUrl != null) data.originalUrl!,
      ],
    };

    for (final url in urls) {
      fetcher.invalidate(url);
    }
  }

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------

  /// Resolves [imageUrl] to a disk-cached file shared across messages.
  ///
  /// If [message] already stores a hash for [slot] and that file exists, it is
  /// returned immediately with `fromDisk: true`. Otherwise the image is
  /// downloaded, validated (content type, size, dimensions), written to the
  /// shared cache, and the hash persisted back onto the message.
  ///
  /// Returns null when the image is missing, unreachable, or fails validation
  /// — including the tracking pixels that used to be blocklisted by hostname.
  static Future<CachedPreviewImage?> resolveCachedImage(
    Message message,
    String imageUrl, {
    MetadataCacheSlot slot = MetadataCacheSlot.urlPreview,
    bool isIcon = false,
  }) async {
    if (kIsWeb) return null;

    final storedHash =
        isIcon ? MessageMetadataStore.iconHash(message, slot) : MessageMetadataStore.imageHash(message, slot);
    if (storedHash != null) {
      final cachedPath = FilesystemSvc.urlPreviewImagePath(storedHash);
      if (await File(cachedPath).exists()) {
        return CachedPreviewImage(path: cachedPath, md5: storedHash, fromDisk: true);
      }
    }

    final downloaded = await fetcher.images.download(imageUrl);
    if (downloaded == null) return null;

    // Persist the hash without disturbing the slot's attempt bookkeeping.
    final map = <String, dynamic>{...?message.metadata};
    if (isIcon) {
      final key = slot.iconHashKey;
      if (key != null) map[key] = downloaded.md5;
    } else {
      map[slot.imageHashKey] = downloaded.md5;
    }
    message.metadata = map;
    if (!kIsWeb && message.id != null) message.save();

    return downloaded;
  }

  // ---------------------------------------------------------------------------
  // Location previews
  // ---------------------------------------------------------------------------

  /// Metadata for an Apple Maps link at [position], used when sharing the
  /// user's current location.
  ///
  /// Returns null when the lookup fails; callers must handle that rather than
  /// force-unwrapping, because Apple Maps does not always serve an image.
  static Future<UrlMetadata?> getLocationMetadata(Position position) async {
    final coordinates = '${position.latitude},${position.longitude}';
    final url = 'https://maps.apple.com/?ll=$coordinates&q=$coordinates';

    // Location sharing is an explicit user action, so it is not gated on the
    // automatic-preview setting.
    final result = await fetcher.fetch(url);
    final metadata = result.metadata;
    if (metadata == null || metadata.isEmpty) {
      Logger.warn('Could not resolve Apple Maps metadata (${result.status.name})', tag: 'MetadataHelper');
      return null;
    }
    return metadata;
  }
}
