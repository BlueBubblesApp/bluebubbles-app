import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/network/api/sticker_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

// ignore: non_constant_identifier_names
StickerLibraryService get StickerLibrarySvc => GetIt.I<StickerLibraryService>();

/// The app's copy of the server Mac's sticker library (`/api/v2/sticker`), mirroring the listing and caching the
/// images. On disk, under `<appDocDir>/stickers/`:
///
/// - `library.json`: the last listing, so the library draws instantly on open.
/// - `thumbnails/<id>`: each sticker's picker thumbnail, fetched only for identifiers not already held.
/// - `full/<id>`: the full-size image, fetched the first time the sticker is sent.
///
/// A sticker's image never changes under its identifier, so nothing is downloaded twice. The listing has no ETag, so
/// every sync re-reads it. Files for stickers no longer listed are removed on each sync. v2 servers only: check
/// `ServerDetails.supportsStickers` first. Registered lazily.
class StickerLibraryService {
  /// Thumbnails fetched at once
  static const int _parallel = 6;

  /// Every sticker in the library, newest first.
  final RxList<LibrarySticker> entries = <LibrarySticker>[].obs;

  /// Identifiers whose thumbnail is on disk. Tiles watch this to swap their placeholder.
  final RxSet<String> cachedThumbnails = <String>{}.obs;

  /// Whether the on-disk cache has been read, so an empty [entries] means "empty" rather than "not loaded yet".
  final RxBool loaded = false.obs;
  final RxBool syncing = false.obs;

  /// An upload from this device is in flight
  final RxBool adding = false.obs;

  /// The sentence to show for the last failed sync, cleared when one succeeds. A `402` locks [SubscriptionSvc] instead.
  final RxnString syncError = RxnString();

  /// Set when the Mac answered with an empty library and a reason (no sticker store yet, or no Full Disk Access).
  final RxnString unavailableReason = RxnString();

  Future<void>? _loading;
  Future<void>? _syncing;

  Directory get _root => Directory(join(FilesystemSvc.appDocDir.path, 'stickers'));
  File get _indexFile => File(join(_root.path, 'library.json'));
  Directory get _thumbnailDir => Directory(join(_root.path, 'thumbnails'));
  Directory get _fullDir => Directory(join(_root.path, 'full'));

  File thumbnailFile(String identifier) => File(join(_thumbnailDir.path, _fileName(identifier)));
  File _fullFile(String identifier) => File(join(_fullDir.path, _fileName(identifier)));

  /// Identifiers are UUIDs, but they come from the server: never let one name a path.
  static String _fileName(String identifier) => identifier.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Reads the on-disk cache once. Cheap to call repeatedly.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (kIsWeb) return;
    try {
      if (await _indexFile.exists()) {
        final json = jsonDecode(await _indexFile.readAsString()) as Map<String, dynamic>;
        unavailableReason.value = json['reason'] as String?;
        entries.assignAll(
          ((json['entries'] as List?) ?? const []).map((e) => LibrarySticker.fromMap((e as Map).cast())),
        );
      }
      if (await _thumbnailDir.exists()) {
        final held = <String>{};
        await for (final file in _thumbnailDir.list()) {
          if (file is File) held.add(basename(file.path));
        }
        cachedThumbnails.assignAll(entries.map((e) => e.identifier).where((id) => held.contains(_fileName(id))));
      }
    } catch (e, s) {
      // A corrupt cache is only a slower first paint: the next sync rebuilds it
      Logger.warn("Discarding unreadable sticker cache", error: e, trace: s, tag: 'StickerLibrary');
      entries.clear();
      cachedThumbnails.clear();
    } finally {
      loaded.value = true;
    }
  }

  /// Brings the cache up to date with the Mac: the listing, then thumbnails for whatever is new. Concurrent callers
  /// share one run.
  Future<void> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (kIsWeb || SubscriptionSvc.locked) return;
    await load();
    syncing.value = true;
    try {
      final (:stickers, :reason) = await HttpSvc.sticker.library();
      entries.assignAll(stickers);
      unavailableReason.value = stickers.isEmpty ? reason : null;
      syncError.value = null;
      await _writeIndex();
      await _fetchMissingThumbnails();
      await _pruneFiles();
    } catch (e, s) {
      final refusal = stickerRefusal(e);
      Logger.warn("Sticker library sync failed", error: e, trace: s, tag: 'StickerLibrary');
      syncError.value = refusal.message ?? "Couldn't reach your server to load your stickers.";
    } finally {
      syncing.value = false;
    }
  }

  Future<void> _fetchMissingThumbnails() async {
    final missing = entries.map((e) => e.identifier).where((id) => !cachedThumbnails.contains(id)).toList();
    if (missing.isEmpty) return;
    await _thumbnailDir.create(recursive: true);
    for (var i = 0; i < missing.length; i += _parallel) {
      await Future.wait(missing.skip(i).take(_parallel).map(_fetchThumbnail));
    }
  }

  // One failure leaves a placeholder for that sticker, retried next sync, rather than stopping the rest
  Future<void> _fetchThumbnail(String identifier) async {
    try {
      final bytes = await HttpSvc.sticker.image(identifier, thumbnail: true);
      await thumbnailFile(identifier).writeAsBytes(bytes, flush: true);
      cachedThumbnails.add(identifier);
    } catch (e) {
      Logger.warn("Couldn't fetch the thumbnail of sticker $identifier: $e", tag: 'StickerLibrary');
    }
  }

  /// Removes cached images for stickers the library no longer lists.
  Future<void> _pruneFiles() async {
    final keep = entries.map((e) => _fileName(e.identifier)).toSet();
    for (final dir in [_thumbnailDir, _fullDir]) {
      if (!await dir.exists()) continue;
      await for (final file in dir.list()) {
        if (file is File && !keep.contains(basename(file.path))) {
          await file.delete().catchError((_) => file);
        }
      }
    }
    cachedThumbnails.removeWhere((id) => !keep.contains(_fileName(id)));
  }

  Future<void> _writeIndex() async {
    await _root.create(recursive: true);
    await _indexFile.writeAsString(
      jsonEncode({'reason': unavailableReason.value, 'entries': entries.map((e) => e.toMap()).toList()}),
    );
  }

  /// The full-size image of [sticker], to send. Downloaded once and kept.
  Future<Uint8List> imageForSending(LibrarySticker sticker) async {
    final file = _fullFile(sticker.identifier);
    if (await file.exists()) return file.readAsBytes();
    final bytes = await HttpSvc.sticker.image(sticker.identifier);
    await _fullDir.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  /// The library sticker whose image [file] is, matched against the full-size copies kept for sending, so a sticker
  /// sent from this device is recognised in the message it went out in. Null when none matches.
  Future<String?> identifierOfImage(File file) async {
    if (kIsWeb || !await file.exists()) return null;
    final length = await file.length();
    Uint8List? bytes;
    for (final sticker in entries) {
      final full = _fullFile(sticker.identifier);
      if (!await full.exists() || await full.length() != length) continue;
      bytes ??= await file.readAsBytes();
      if (listEquals(bytes, await full.readAsBytes())) return sticker.identifier;
    }
    return null;
  }

  /// Removes [sticker] from the Mac's library, then from the cache. A saved sticker you've used also has a copy in
  /// Recents under its own identifier, so a sync afterwards shows whatever the Mac still lists. Throws when the server
  /// refuses; [stickerRefusal] reads why.
  Future<void> delete(LibrarySticker sticker) async {
    await HttpSvc.sticker.delete(sticker.identifier);
    entries.removeWhere((e) => e.identifier == sticker.identifier);
    cachedThumbnails.remove(sticker.identifier);
    await _writeIndex();
    for (final file in [thumbnailFile(sticker.identifier), _fullFile(sticker.identifier)]) {
      if (await file.exists()) await file.delete();
    }
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
