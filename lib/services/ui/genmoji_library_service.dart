import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/network/api/genmoji_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

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
/// is read until a picker first asks.
class GenmojiLibraryService {
  /// The grid's image size, and the largest the batch route serves.
  static const int thumbnailSize = GenmojiApi.libraryBatchMaxSize;

  /// The longest edge of the copy attached to a message. Messages draws a sent Genmoji at
  /// sticker size, so the Mac's 1024 strike would only make the message heavier.
  static const int sendSize = 512;

  /// Every Genmoji in the library, newest first.
  final RxList<GenmojiLibraryEntry> entries = <GenmojiLibraryEntry>[].obs;

  /// Identifiers whose thumbnail is on disk. Tiles watch this to swap their placeholder.
  final RxSet<String> cachedThumbnails = <String>{}.obs;

  /// Whether the on-disk cache has been read, so an empty [entries] means "empty" rather than
  /// "not loaded yet".
  final RxBool loaded = false.obs;
  final RxBool syncing = false.obs;

  /// The sentence to show for the last failed sync, cleared when one succeeds.
  final RxnString syncError = RxnString();

  /// Set when the Mac answered with an empty library and a reason (its store can't be read,
  /// or its macOS keeps no Genmoji).
  final RxnString unavailableReason = RxnString();

  String? _entityTag;
  Future<void>? _loading;
  Future<void>? _syncing;

  Directory get _root => Directory(join(FilesystemSvc.appDocDir.path, 'genmoji'));
  File get _indexFile => File(join(_root.path, 'library.json'));
  Directory get _thumbnailDir => Directory(join(_root.path, 'thumbnails'));
  Directory get _fullDir => Directory(join(_root.path, 'full'));

  File thumbnailFile(String identifier) => File(join(_thumbnailDir.path, '${_fileName(identifier)}.png'));
  File _fullFile(String identifier) => File(join(_fullDir.path, '${_fileName(identifier)}.png'));

  /// Identifiers are UUIDs, but they come from the server: never let one name a path.
  static String _fileName(String identifier) => identifier.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Reads the on-disk cache once. Cheap to call repeatedly.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (kIsWeb) return;
    try {
      if (await _indexFile.exists()) {
        final json = jsonDecode(await _indexFile.readAsString()) as Map<String, dynamic>;
        _entityTag = json['etag'] as String?;
        unavailableReason.value = json['reason'] as String?;
        entries.assignAll(
          ((json['entries'] as List?) ?? const []).map(
            (e) => GenmojiLibraryEntry.fromMap((e as Map).cast<String, dynamic>()),
          ),
        );
      }
      if (await _thumbnailDir.exists()) {
        final held = <String>{};
        await for (final file in _thumbnailDir.list()) {
          if (file is File && file.path.endsWith('.png')) held.add(basenameWithoutExtension(file.path));
        }
        cachedThumbnails.assignAll(entries.map((e) => e.identifier).where((id) => held.contains(_fileName(id))));
      }
    } catch (e, s) {
      // A corrupt cache is only a slower first paint: the next sync rebuilds it.
      Logger.warn("Discarding unreadable Genmoji cache", error: e, trace: s, tag: 'GenmojiLibrary');
      _entityTag = null;
      entries.clear();
      cachedThumbnails.clear();
    } finally {
      loaded.value = true;
    }
  }

  /// Brings the cache up to date with the Mac: one revalidating listing (a 304 when nothing
  /// changed), then thumbnails for whatever is new. Concurrent callers share one run.
  ///
  /// [force] skips the `ETag`, for a pull-to-refresh that should re-read the listing even if
  /// the server would call it current.
  Future<void> sync({bool force = false}) => _syncing ??= _sync(force).whenComplete(() => _syncing = null);

  Future<void> _sync(bool force) async {
    if (kIsWeb) return;
    await load();
    syncing.value = true;
    try {
      final listed = await _fetchListing(force ? null : _entityTag);
      if (listed != null) {
        entries.assignAll(listed.entries);
        _entityTag = listed.entityTag;
        unavailableReason.value = listed.entries.isEmpty ? listed.reason : null;
        await _writeIndex();
      }
      syncError.value = null;
      await _fetchMissingThumbnails();
      await _pruneFiles();
    } on GenmojiException catch (e) {
      Logger.warn("Genmoji library sync refused: ${e.reason ?? e.statusCode}", tag: 'GenmojiLibrary');
      syncError.value = e.message;
    } catch (e, s) {
      Logger.error("Genmoji library sync failed", error: e, trace: s, tag: 'GenmojiLibrary');
      syncError.value = "Couldn't reach your server to load your Genmoji.";
    } finally {
      syncing.value = false;
    }
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

  Future<void> _fetchMissingThumbnails() async {
    final missing = entries.map((e) => e.identifier).where((id) => !cachedThumbnails.contains(id)).toList();
    if (missing.isEmpty) return;
    await _thumbnailDir.create(recursive: true);

    for (var i = 0; i < missing.length; i += GenmojiApi.libraryBatchLimit) {
      final chunk = missing.sublist(i, math.min(i + GenmojiApi.libraryBatchLimit, missing.length));
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
        await _writeIndex();
      }
    }
  }

  /// Removes cached images for Genmoji the library no longer lists.
  Future<void> _pruneFiles() async {
    final keep = entries.map((e) => _fileName(e.identifier)).toSet();
    for (final dir in [_thumbnailDir, _fullDir]) {
      if (!await dir.exists()) continue;
      await for (final file in dir.list()) {
        if (file is File && !keep.contains(basenameWithoutExtension(file.path))) {
          await file.delete().catchError((_) => file);
        }
      }
    }
    cachedThumbnails.removeWhere((id) => !keep.contains(_fileName(id)));
  }

  Future<void> _writeIndex() async {
    await _root.create(recursive: true);
    await _indexFile.writeAsString(
      jsonEncode({
        'etag': _entityTag,
        'reason': unavailableReason.value,
        'entries': entries.map((e) => e.toMap()).toList(),
      }),
    );
  }

  /// The PNG to attach for [entry], at [sendSize] (or the largest size the Mac stores, if
  /// smaller). Downloaded once and kept; falls back to the thumbnail when the download fails
  /// so a flaky connection still sends something.
  Future<Uint8List> imageForSending(GenmojiLibraryEntry entry, {CancelToken? cancelToken}) async {
    final file = _fullFile(entry.identifier);
    if (await file.exists()) return file.readAsBytes();

    final size = math.min(sendSize, entry.largestSize ?? sendSize);
    try {
      final bytes = await HttpSvc.genmoji.libraryImage(entry.identifier, size: size, cancelToken: cancelToken);
      await _fullDir.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      final thumbnail = thumbnailFile(entry.identifier);
      if (await thumbnail.exists()) {
        Logger.warn("Sending Genmoji thumbnail; full image failed: $e", tag: 'GenmojiLibrary');
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
    entries.removeWhere((e) => e.identifier == entry.identifier);
    cachedThumbnails.remove(entry.identifier);
    // The library's revision moved; the old tag would only earn a pointless full listing later.
    _entityTag = null;
    await _writeIndex();
    for (final file in [thumbnailFile(entry.identifier), _fullFile(entry.identifier)]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Drops everything cached on disk and in memory (e.g. after switching servers).
  Future<void> clearCache() async {
    entries.clear();
    cachedThumbnails.clear();
    unavailableReason.value = null;
    syncError.value = null;
    _entityTag = null;
    if (await _root.exists()) await _root.delete(recursive: true);
  }
}
