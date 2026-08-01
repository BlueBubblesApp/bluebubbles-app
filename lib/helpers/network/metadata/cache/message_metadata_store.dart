import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:flutter/foundation.dart';

/// Identifies which preview a set of keys inside `Message.metadata` belongs to.
///
/// A single message can carry more than one cached preview — the link preview
/// card and, for Photos share links, the slideshow thumbnail — so each one
/// owns a disjoint set of keys.
enum MetadataCacheSlot {
  /// The standard URL preview rendered by `UrlPreview`.
  urlPreview(
    imageHashKey: 'previewImageMd5',
    iconHashKey: 'previewIconMd5',
    attemptedKey: 'previewImageFetched',
    attemptedAtKey: 'previewFetchedAt',
    storesMetadata: true,
  ),

  /// The iCloud Photos share-link thumbnail rendered by `PhotoSlideshow`.
  ///
  /// Only the image is cached here; the card renders its own title, so no
  /// [UrlMetadata] fields are persisted for this slot.
  photoSlideshow(
    imageHashKey: 'photoPreviewImageMd5',
    iconHashKey: null,
    attemptedKey: 'photoPreviewImageFetched',
    attemptedAtKey: 'photoPreviewFetchedAt',
    storesMetadata: false,
  );

  const MetadataCacheSlot({
    required this.imageHashKey,
    required this.iconHashKey,
    required this.attemptedKey,
    required this.attemptedAtKey,
    required this.storesMetadata,
  });

  /// Content hash of the disk-cached preview image.
  ///
  /// The key string still says `Md5` because it is persisted on existing
  /// message rows; the value it holds is now a SHA-256. Renaming the key would
  /// orphan every already-cached image.
  final String imageHashKey;

  /// Content hash of the disk-cached site icon, when the slot renders one.
  final String? iconHashKey;

  /// Legacy boolean flag. Still written so that downgrading the app keeps the
  /// old "don't refetch" behaviour, and still read as a fallback when
  /// [attemptedAtKey] is absent on rows written by older versions.
  final String attemptedKey;

  /// Millisecond timestamp of the last completed attempt. This is what the
  /// retry TTL is measured from.
  final String attemptedAtKey;

  /// Whether [UrlMetadata] fields are persisted alongside the image hash.
  final bool storesMetadata;
}

/// Reads and writes cached preview metadata on a [Message].
///
/// All knowledge of the `Message.metadata` key layout lives here so that
/// widgets never poke at raw map keys, and so that adding a field does not
/// mean auditing every call site.
abstract final class MessageMetadataStore {
  /// How long a completed attempt suppresses refetching.
  ///
  /// The previous implementation set a permanent flag, which meant a single
  /// bot-block or transient 503 left the message without a preview forever.
  static const Duration retryAfter = Duration(hours: 24);

  /// Returns the cached metadata for [slot], or `null` when nothing usable is
  /// stored. Reads legacy `metadata_fetch` keys transparently.
  static UrlMetadata? read(Message message, {MetadataCacheSlot slot = MetadataCacheSlot.urlPreview}) {
    if (!slot.storesMetadata) return null;
    final map = message.metadata;
    if (map == null || map.isEmpty) return null;

    final metadata = UrlMetadata.fromJson(map);
    return metadata.isEmpty ? null : metadata;
  }

  /// The content hash of the disk-cached preview image for [slot], if saved.
  static String? imageHash(Message message, MetadataCacheSlot slot) => _string(message.metadata?[slot.imageHashKey]);

  /// The content hash of the disk-cached icon for [slot], if it caches one.
  static String? iconHash(Message message, MetadataCacheSlot slot) {
    final key = slot.iconHashKey;
    if (key == null) return null;
    return _string(message.metadata?[key]);
  }

  /// Whether a fresh fetch should run for [slot].
  ///
  /// Returns `false` only while a previous completed attempt is still inside
  /// [retryAfter]. Rows carrying only the legacy boolean flag are treated as
  /// expired so they get one retry against the new parser.
  static bool shouldFetch(Message message, {MetadataCacheSlot slot = MetadataCacheSlot.urlPreview}) {
    final map = message.metadata;
    if (map == null || map.isEmpty) return true;

    final attemptedAt = _int(map[slot.attemptedAtKey]);
    if (attemptedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - attemptedAt;
      return age < 0 || age > retryAfter.inMilliseconds;
    }

    // No timestamp: either never attempted, or attempted by an older build.
    return true;
  }

  /// Persists [metadata] for [slot] and marks the attempt as completed.
  ///
  /// Sibling keys (the other slot's hashes, anything the server put there) are
  /// preserved; only this slot's keys and the [UrlMetadata] fields are
  /// rewritten.
  static void write(
    Message message,
    UrlMetadata metadata, {
    MetadataCacheSlot slot = MetadataCacheSlot.urlPreview,
    String? imageHash,
    String? iconHash,
  }) {
    final map = <String, dynamic>{...?message.metadata};

    if (slot.storesMetadata) {
      // Clear stale metadata keys first so a refresh that finds fewer fields
      // does not leave the old ones behind.
      map.removeWhere((key, _) => UrlMetadata.jsonKeys.contains(key));
      map.addAll(metadata.toJson()..removeWhere((_, value) => value == null));
    }

    if (imageHash != null) map[slot.imageHashKey] = imageHash;
    final iconKey = slot.iconHashKey;
    if (iconKey != null && iconHash != null) map[iconKey] = iconHash;

    _stamp(map, slot);
    _save(message, map);
  }

  /// Records that an attempt completed without producing anything, so the
  /// fetch is not retried until the TTL elapses.
  static void markAttempted(Message message, {MetadataCacheSlot slot = MetadataCacheSlot.urlPreview}) {
    final map = <String, dynamic>{...?message.metadata};
    _stamp(map, slot);
    _save(message, map);
  }

  /// Clears everything for [slot] so the next build refetches from scratch.
  /// Used by the manual "refresh preview" action.
  static void clear(Message message, {MetadataCacheSlot slot = MetadataCacheSlot.urlPreview}) {
    final map = <String, dynamic>{...?message.metadata};
    if (slot.storesMetadata) map.removeWhere((key, _) => UrlMetadata.jsonKeys.contains(key));
    map.remove(slot.imageHashKey);
    final iconKey = slot.iconHashKey;
    if (iconKey != null) map.remove(iconKey);
    map.remove(slot.attemptedKey);
    map.remove(slot.attemptedAtKey);
    _save(message, map);
  }

  static void _stamp(Map<String, dynamic> map, MetadataCacheSlot slot) {
    map[slot.attemptedKey] = true;
    map[slot.attemptedAtKey] = DateTime.now().millisecondsSinceEpoch;
  }

  static void _save(Message message, Map<String, dynamic> map) {
    message.metadata = map;
    if (kIsWeb || message.id == null) return;
    message.save();
  }

  static String? _string(dynamic value) => value is String && value.isNotEmpty ? value : null;

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
