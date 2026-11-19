import 'dart:async';

import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/network/api/sticker_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:universal_io/io.dart';

// ignore: non_constant_identifier_names
StickerLibraryService get StickerLibrarySvc => GetIt.I<StickerLibraryService>();

/// The app's copy of the server Mac's sticker library (`/api/v2/sticker`), mirroring the listing and caching the
/// images. On disk, under `<appDocDir>/stickers/`:
///
/// - `library.json`: the last listing, so the library draws instantly on open, and the account it came from.
/// - `thumbnails/<id>`: each sticker's picker thumbnail, fetched only for identifiers not already held.
/// - `full/<id>`: the full-size image, fetched the first time the sticker is sent.
///
/// A sticker's image never changes under its identifier, so nothing is downloaded twice. The listing has no ETag, so
/// every sync re-reads it. Files for stickers no longer listed are removed on each sync, and so are their entries in
/// the recent tapbacks (unless the library is unavailable). v2 servers only: check
/// `ServerDetails.supportsStickers` first. Registered lazily. The shared caching is [RemoteLibraryCache]'s.
class StickerLibraryService extends RemoteLibraryCache<LibrarySticker> {
  StickerLibraryService() {
    // Both lookups are rebuilt from entries on next use, so they can't go stale
    ever(entries, (_) {
      _byIdentifier = null;
      _fullImagesByLength = null;
    });
  }

  /// Thumbnails fetched at once
  static const int _parallel = 6;

  final RxBool adding = false.obs;

  Map<String, LibrarySticker>? _byIdentifier;

  /// Full-size copies on disk by file length, so [identifierOfImage] reads only same-size candidates
  Future<Map<int, List<String>>>? _fullImagesByLength;

  /// The listed sticker with [identifier], or null when the library no longer has it. Not reactive: read [entries] in
  /// an `Obx` to follow the library.
  LibrarySticker? byIdentifier(String identifier) =>
      (_byIdentifier ??= {for (final sticker in entries) sticker.identifier: sticker})[identifier];

  @override
  String get rootPath => FilesystemSvc.stickerLibraryPath;

  @override
  String get fileExtension => '';

  @override
  String get logTag => 'StickerLibrary';

  @override
  String identifierOf(LibrarySticker entry) => entry.identifier;

  @override
  LibrarySticker? entryFromMap(Object? json) => LibrarySticker.tryFromMap(json);

  @override
  Map<String, dynamic> entryToMap(LibrarySticker entry) => entry.toMap();

  /// Brings the cache up to date with the Mac: the listing, then thumbnails for whatever is new. Concurrent callers
  /// share one run. A `402` locks [SubscriptionSvc] instead of setting [syncError].
  Future<void> sync() => runSync(_refreshListing);

  Future<void> _refreshListing() async {
    final (:stickers, :reason) = await HttpSvc.sticker.library();
    entries.assignAll(stickers);
    unavailableReason.value = stickers.isEmpty ? reason : null;
    await writeIndex();
    // An unavailable library says nothing about which stickers are gone
    if (unavailableReason.value == null) {
      await PrefsSvc.messaging.pruneStickerTapbacks(stickers.map((e) => e.identifier).toSet());
    }
  }

  @override
  String describeSyncError(Object error, StackTrace stack) {
    Logger.warn("Sticker library sync failed", error: error, trace: stack, tag: logTag);
    return stickerRefusal(error).message ?? "Couldn't reach your server to load your stickers.";
  }

  @override
  Future<void> fetchThumbnails(List<String> identifiers) async {
    for (var i = 0; i < identifiers.length; i += _parallel) {
      await Future.wait(identifiers.skip(i).take(_parallel).map(_fetchThumbnail));
    }
  }

  // One failure leaves a placeholder for that sticker, retried next sync, rather than stopping the rest
  Future<void> _fetchThumbnail(String identifier) async {
    try {
      final bytes = await HttpSvc.sticker.image(identifier, thumbnail: true);
      await thumbnailFile(identifier).writeAsBytes(bytes, flush: true);
      cachedThumbnails.add(identifier);
    } catch (e) {
      Logger.warn("Couldn't fetch the thumbnail of sticker $identifier: $e", tag: logTag);
    }
  }

  /// The full-size image of [sticker], to send. Downloaded once and kept.
  Future<Uint8List> imageForSending(LibrarySticker sticker) async {
    final bytes = await cachedFullImage(sticker.identifier, () => HttpSvc.sticker.image(sticker.identifier));
    final index = await _fullImagesByLength;
    if (index != null) {
      final sameLength = index.putIfAbsent(bytes.length, () => []);
      if (!sameLength.contains(sticker.identifier)) sameLength.add(sticker.identifier);
    }
    return bytes;
  }

  /// The library sticker whose image [file] is, matched against the full-size copies kept for sending, so a sticker
  /// sent from this device is recognised in the message it went out in. Null when none matches.
  Future<String?> identifierOfImage(File file) async {
    if (kIsWeb || !await file.exists()) return null;
    final candidates = (await (_fullImagesByLength ??= _indexFullImages()))[await file.length()];
    if (candidates == null) return null;
    final bytes = await file.readAsBytes();
    for (final identifier in candidates) {
      final full = fullFile(identifier);
      // A copy pruned or removed since the index was built
      if (!await full.exists()) continue;
      if (listEquals(bytes, await full.readAsBytes())) return identifier;
    }
    return null;
  }

  Future<Map<int, List<String>>> _indexFullImages() async {
    final index = <int, List<String>>{};
    for (final sticker in entries.toList()) {
      final full = fullFile(sticker.identifier);
      if (!await full.exists()) continue;
      index.putIfAbsent(await full.length(), () => []).add(sticker.identifier);
    }
    return index;
  }

  /// Removes [sticker] from the Mac's library, then from the cache. A saved sticker you've used also has a copy in
  /// Recents under its own identifier, so a sync afterwards shows whatever the Mac still lists. Throws when the server
  /// refuses; [stickerRefusal] reads why.
  Future<void> delete(LibrarySticker sticker) async {
    await HttpSvc.sticker.delete(sticker.identifier);
    await removeFromCache(sticker.identifier);
    unawaited(sync());
  }

  /// Adds the image in [bytes] to the Mac's library (it lands in Recents), then syncs so it shows. Throws when the
  /// server refuses; [stickerRefusal] reads why.
  Future<void> add(Uint8List bytes, String fileName) async {
    adding.value = true;
    try {
      await HttpSvc.sticker.save(bytes: bytes, fileName: fileName);
      await sync();
    } finally {
      adding.value = false;
    }
  }
}
