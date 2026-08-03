import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/network/metadata/metadata.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
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

  /// The user's automatic-fetch policy.
  static LinkPreviewPolicy get policy => SettingsSvc.settings.linkPreviewPolicy.value;

  /// Whether fetching is permitted at all, regardless of sender.
  static bool get fetchingEnabled => policy != LinkPreviewPolicy.never;

  /// Whether [message]'s link may be fetched without the user asking.
  ///
  /// Under [LinkPreviewPolicy.contactsOnly] this is the difference between
  /// "anyone who knows your number can make your phone issue a request" and
  /// "only people you have saved can". It is evaluated per *message sender*,
  /// not per chat: in a group containing both a contact and a stranger, the
  /// stranger's messages are still gated.
  ///
  /// Fails closed: a sender that cannot be confirmed as a contact counts as
  /// unknown, including when contacts access is unavailable entirely. That
  /// means denying the contacts permission turns every link into tap-to-load
  /// rather than quietly reverting to fetching everything.
  ///
  /// A manual tap bypasses this entirely — see [fetchForMessage], which does
  /// not consult it.
  static Future<bool> shouldAutoFetch(Message message) async {
    switch (policy) {
      case LinkPreviewPolicy.never:
        return false;
      case LinkPreviewPolicy.always:
        return true;
      case LinkPreviewPolicy.contactsOnly:
        break;
    }

    // The user chose to send this link themselves.
    if (message.isFromMe ?? false) return true;

    // Everything below fails closed. A sender we cannot confirm is a contact is
    // treated as unknown, whatever the reason — no handle, contacts permission
    // denied, a server without the contacts API, or a lookup error. The user
    // asked for previews from saved contacts only, and "we could not check"
    // is not the same as "yes".
    //
    // `getContactForHandle` already returns null when access is unavailable, so
    // no separate permission check is needed here.
    final handleId = message.handle?.id;
    if (handleId == null) {
      Logger.debug('No handle on ${message.guid}; treating sender as unknown', tag: 'MetadataHelper');
      return false;
    }

    try {
      final isContact = (await ContactsSvcV2.getContactForHandle(handleId)) != null;
      Logger.debug('Sender of ${message.guid} ${isContact ? "is" : "is not"} a saved contact', tag: 'MetadataHelper');
      return isContact;
    } catch (ex, stack) {
      Logger.warn('Could not resolve sender contact; treating as unknown',
          error: ex, trace: stack, tag: 'MetadataHelper');
      return false;
    }
  }

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
  ///
  /// Set [manual] when the user explicitly asked for this preview. A tap is
  /// consent, so it bypasses the policy check — including
  /// [LinkPreviewPolicy.never], where tap-to-load is the *only* way a preview
  /// ever loads. Every other protection still applies.
  static Future<MetadataFetchResult> fetchForMessage(
    Message message, {
    String? urlOverride,
    bool manual = false,
  }) async {
    if (!manual && !fetchingEnabled) {
      return const MetadataFetchResult.failure(MetadataFetchStatus.disabledByUser);
    }

    final url = urlOverride ?? message.url;
    if (url == null || url.trim().isEmpty) {
      return const MetadataFetchResult.failure(MetadataFetchStatus.invalidUrl);
    }

    return fetcher.fetch(url);
  }

  /// Fetches metadata for a bare URL, outside any message context.
  ///
  /// There is no sender to evaluate here, so [LinkPreviewPolicy.contactsOnly]
  /// behaves like [LinkPreviewPolicy.always]. The only caller is the Apple Maps
  /// location card, whose URL is always `maps.apple.com`.
  static Future<MetadataFetchResult> fetchForUrl(String url, {bool manual = false}) {
    if (!manual && !fetchingEnabled) {
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
  ///
  /// Also drops the image downloader's record of permanently-failed URLs. A
  /// refresh is a deliberate request for a real retry, and the icon/image URLs
  /// are not reachable from the message — they live inside the metadata being
  /// discarded — so there is nothing per-URL to invalidate here.
  static void invalidateForMessage(Message message) {
    fetcher.images.clearFailures();

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
  ///
  /// Set [bypassGate] when the caller has already cleared this message through
  /// [shouldAutoFetch], or when the user asked for the preview explicitly.
  /// Otherwise a **download** (never a disk hit) is gated on the sender policy:
  /// a cache the user cleared from the Storage Analyzer must not silently
  /// re-fetch from a sender whose previews they chose not to load
  /// automatically.
  static Future<CachedPreviewImage?> resolveCachedImage(
    Message message,
    String imageUrl, {
    MetadataCacheSlot slot = MetadataCacheSlot.urlPreview,
    bool isIcon = false,
    bool bypassGate = false,
  }) async {
    if (kIsWeb) return null;

    final storedHash =
        isIcon ? MessageMetadataStore.iconHash(message, slot) : MessageMetadataStore.imageHash(message, slot);
    if (storedHash != null) {
      final cachedPath = FilesystemSvc.urlPreviewImagePath(storedHash);
      if (await File(cachedPath).exists()) {
        return CachedPreviewImage(path: cachedPath, hash: storedHash, fromDisk: true);
      }
    }

    // Only reached on a cache miss, so the policy check costs nothing on the
    // common path.
    if (!bypassGate && !await shouldAutoFetch(message)) {
      Logger.debug('Not downloading ${isIcon ? "icon" : "image"} $imageUrl; sender policy declined',
          tag: 'MetadataHelper');
      return null;
    }

    Logger.debug('Downloading ${isIcon ? "icon" : "image"} $imageUrl', tag: 'MetadataHelper');

    // Only the hero image is downsampled. A favicon is already small, and
    // re-encoding one as JPEG would flatten its alpha.
    final downloaded = await fetcher.images.download(imageUrl, optimize: !isIcon);
    if (downloaded == null) return null;

    // Persist the hash without disturbing the slot's attempt bookkeeping.
    final map = <String, dynamic>{...?message.metadata};
    if (isIcon) {
      final key = slot.iconHashKey;
      if (key != null) map[key] = downloaded.hash;
    } else {
      map[slot.imageHashKey] = downloaded.hash;
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
