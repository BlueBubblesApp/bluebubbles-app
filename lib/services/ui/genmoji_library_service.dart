import 'dart:math' as math;

import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/network/api/genmoji_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
GenmojiLibraryService get GenmojiLibrarySvc => GetIt.I<GenmojiLibraryService>();

/// The app's copy of the server Mac's Genmoji library (`/api/v2/genmoji/library`).
///
/// The library itself is the Mac's sticker store — the set Messages shows on every one of the
/// user's Apple devices — so this never invents entries; it mirrors the listing and caches the
/// images. On disk, under `<appDocDir>/genmoji/`:
///
/// - `library.json`: the last listing and its `ETag`, so the picker draws instantly on open
///   and an unchanged library revalidates as a body-less 304.
/// - `thumbnails/<id>.png`: each Genmoji at [thumbnailSize], fetched in batches of 50 and only
///   for identifiers not already held. A library image never changes under its identifier, so
///   nothing here is ever re-downloaded.
/// - `full/<id>.png`: the larger copy attached to a message, fetched the first time one is sent.
///
/// Files for Genmoji no longer listed are removed on each sync. v2 servers only — check
/// `ServerDetails.supportsGenmoji` before calling anything here. Registered lazily: nothing
/// is read until a picker first asks. The shared caching is [RemoteLibraryCache]'s.
class GenmojiLibraryService extends RemoteLibraryCache<GenmojiLibraryEntry> {
  /// The grid's image size, and the largest the batch route serves.
  static const int thumbnailSize = GenmojiApi.libraryBatchMaxSize;

  /// The longest edge of the copy attached to a message. Messages draws a sent Genmoji at
  /// sticker size, so the Mac's 1024 strike would only make the message heavier.
  static const int sendSize = 512;

  String? _entityTag;

  @override
  String get rootPath => FilesystemSvc.genmojiLibraryPath;

  @override
  String get fileExtension => '.png';

  @override
  String get logTag => 'GenmojiLibrary';

  @override
  String identifierOf(GenmojiLibraryEntry entry) => entry.identifier;

  @override
  GenmojiLibraryEntry? entryFromMap(Object? json) {
    if (json is! Map) return null;
    try {
      return GenmojiLibraryEntry.fromMap(json.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic> entryToMap(GenmojiLibraryEntry entry) => entry.toMap();

  @override
  Map<String, dynamic> indexExtras() => {'etag': _entityTag};

  @override
  void readIndexExtras(Map<String, dynamic>? json) => _entityTag = json?['etag'] as String?;

  /// Brings the cache up to date with the Mac: one revalidating listing (a 304 when nothing
  /// changed), then thumbnails for whatever is new. Concurrent callers share one run.
  ///
  /// [force] skips the `ETag`, for a pull-to-refresh that should re-read the listing even if
  /// the server would call it current.
  Future<void> sync({bool force = false}) => runSync(() => _refreshListing(force));

  Future<void> _refreshListing(bool force) async {
    final listed = await _fetchListing(force ? null : _entityTag);
    if (listed == null) return;
    entries.assignAll(listed.entries);
    _entityTag = listed.entityTag;
    unavailableReason.value = listed.entries.isEmpty ? listed.reason : null;
    await writeIndex();
  }

  @override
  String describeSyncError(Object error, StackTrace stack) {
    if (error is GenmojiException) {
      Logger.warn("Genmoji library sync refused: ${error.reason ?? error.statusCode}", tag: logTag);
      return error.message;
    }
    Logger.error("Genmoji library sync failed", error: error, trace: stack, tag: logTag);
    return "Couldn't reach your server to load your Genmoji.";
  }

  /// Every page of the listing, or null when the first page's tag says nothing changed. The
  /// tag is a revision of the whole library, so a current first page means current pages.
  Future<GenmojiLibraryPage?> _fetchListing(String? ifNoneMatch) async {
    const limit = GenmojiApi.libraryPageLimit;
    final first = await HttpSvc.genmoji.library(limit: limit, ifNoneMatch: ifNoneMatch);
    if (first == null) return null;

    final all = [...first.entries];
    var offset = first.entries.length;
    while (offset < first.total) {
      final page = await HttpSvc.genmoji.library(limit: limit, offset: offset);
      if (page == null || page.entries.isEmpty) break;
      all.addAll(page.entries);
      offset += page.entries.length;
    }
    return GenmojiLibraryPage(
      entries: all,
      total: first.total,
      revision: first.revision,
      reason: first.reason,
      entityTag: first.entityTag,
    );
  }

  @override
  Future<void> fetchThumbnails(List<String> identifiers) async {
    for (var i = 0; i < identifiers.length; i += GenmojiApi.libraryBatchLimit) {
      final chunk = identifiers.sublist(i, math.min(i + GenmojiApi.libraryBatchLimit, identifiers.length));
      final batch = await HttpSvc.genmoji.libraryImages(chunk, size: thumbnailSize);
      for (final image in batch.images) {
        final id = image.identifier;
        if (id == null) continue;
        await thumbnailFile(id).writeAsBytes(image.png, flush: true);
        cachedThumbnails.add(id);
      }
      // Deleted on the Mac between the listing and this read: drop them now rather than show
      // a tile that can never load.
      if (batch.missing.isNotEmpty) {
        entries.removeWhere((e) => batch.missing.contains(e.identifier));
        _entityTag = null;
        await writeIndex();
      }
    }
  }

  /// The PNG to attach for [entry], at [sendSize] (or the largest size the Mac stores, if
  /// smaller). Downloaded once and kept; falls back to the thumbnail when the download fails
  /// so a flaky connection still sends something.
  Future<Uint8List> imageForSending(GenmojiLibraryEntry entry, {CancelToken? cancelToken}) async {
    final size = math.min(sendSize, entry.largestSize ?? sendSize);
    try {
      return await cachedFullImage(
        entry.identifier,
        () => HttpSvc.genmoji.libraryImage(entry.identifier, size: size, cancelToken: cancelToken),
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      final thumbnail = thumbnailFile(entry.identifier);
      if (await thumbnail.exists()) {
        Logger.warn("Sending Genmoji thumbnail; full image failed: $e", tag: logTag);
        return thumbnail.readAsBytes();
      }
      rethrow;
    }
  }

  /// Deletes [entry] from the Mac's library — and so, through iCloud, from every device on the
  /// account — then from the cache. Throws [GenmojiException] with the server's sentence when
  /// it refuses (no Private API helper, or the store kept it).
  Future<void> delete(GenmojiLibraryEntry entry) async {
    await HttpSvc.genmoji.deleteFromLibrary(entry.identifier);
    // The library's revision moved; the old tag would only earn a pointless full listing later.
    _entityTag = null;
    await removeFromCache(entry.identifier);
  }
}
