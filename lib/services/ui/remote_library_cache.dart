import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// The app's copy of a library kept on the server Mac (its stickers, its Genmoji), of entries [T] keyed by an
/// identifier whose image never changes. On disk, under [rootPath]:
///
/// - `library.json`: the last listing, so the library draws instantly on open, plus the iCloud account it came from.
/// - `thumbnails/<id><fileExtension>`: each entry's picker thumbnail, fetched only for identifiers not already held.
/// - `full/<id><fileExtension>`: the copy that gets sent, fetched the first time it's needed.
///
/// Files for entries no longer listed are removed on each sync. When the server reports a different iCloud account
/// than the cache was built from, the cache is dropped: it's another Mac's library.
abstract class RemoteLibraryCache<T extends Object> {
  RemoteLibraryCache() {
    // Lazily registered, so this only watches once something has read the library
    ever(SettingsSvc.serverDetailsChanges, (details) => unawaited(_followAccount(details.iCloudAccount)));
  }

  /// Every entry in the library, newest first.
  final RxList<T> entries = <T>[].obs;

  /// Identifiers whose thumbnail is on disk. Tiles watch this to swap their placeholder.
  final RxSet<String> cachedThumbnails = <String>{}.obs;

  /// Whether the on-disk cache has been read, so an empty [entries] means "empty" rather than "not loaded yet".
  final RxBool loaded = false.obs;
  final RxBool syncing = false.obs;

  /// The sentence to show for the last failed sync, cleared when one succeeds.
  final RxnString syncError = RxnString();

  /// Set when the Mac answered with an empty library and a reason it couldn't list one.
  final RxnString unavailableReason = RxnString();

  /// The iCloud account (the server's `detected_icloud`) the cache was built from, if known
  String? _account;
  Future<void>? _loading;
  Future<void>? _syncing;

  /// A directory of its own under the app documents directory, which `FilesystemSvc.deleteCacheDirectories` also lists
  @protected
  String get rootPath;

  /// Appended to each identifier's file name. Existing caches were written with it, so it must not change.
  @protected
  String get fileExtension;

  @protected
  String get logTag;

  @protected
  String identifierOf(T entry);

  /// The entry in an index's `entries`, or null to skip one that can't be read
  @protected
  T? entryFromMap(Object? json);

  @protected
  Map<String, dynamic> entryToMap(T entry);

  /// Fetches and writes the thumbnails of [identifiers], none of which are on disk, adding each to
  /// [cachedThumbnails]. The thumbnail directory exists.
  @protected
  Future<void> fetchThumbnails(List<String> identifiers);

  /// Logs a failed sync and returns the sentence for [syncError]
  @protected
  String describeSyncError(Object error, StackTrace stack);

  /// Extra fields to keep in the index
  @protected
  Map<String, dynamic> indexExtras() => const {};

  /// Reads back what [indexExtras] wrote, or with null resets it (an unreadable or dropped cache)
  @protected
  void readIndexExtras(Map<String, dynamic>? json) {}

  Directory get _root => Directory(rootPath);
  File get _indexFile => File(join(_root.path, 'library.json'));
  Directory get _thumbnailDir => Directory(join(_root.path, 'thumbnails'));
  Directory get _fullDir => Directory(join(_root.path, 'full'));

  File thumbnailFile(String identifier) => File(join(_thumbnailDir.path, '${_fileName(identifier)}$fileExtension'));

  @protected
  File fullFile(String identifier) => File(join(_fullDir.path, '${_fileName(identifier)}$fileExtension'));

  /// Identifiers are UUIDs, but they come from the server: never let one name a path.
  static String _fileName(String identifier) => identifier.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// The identifier part of a cached file's name, or null for a file that isn't one
  String? _heldName(File file) {
    final name = basename(file.path);
    if (fileExtension.isEmpty) return name;
    return name.endsWith(fileExtension) ? name.substring(0, name.length - fileExtension.length) : null;
  }

  /// Reads the on-disk cache once. Cheap to call repeatedly.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (kIsWeb) return;
    try {
      if (await _indexFile.exists()) {
        final json = jsonDecode(await _indexFile.readAsString()) as Map<String, dynamic>;
        _account = json['account'] as String?;
        readIndexExtras(json);
        unavailableReason.value = json['reason'] as String?;
        entries.assignAll(((json['entries'] as List?) ?? const []).map(entryFromMap).nonNulls);
      }
      final account = SettingsSvc.serverDetails.iCloudAccount;
      if (_isOtherAccount(account)) {
        await _drop();
        _account = account;
        return;
      }
      if (await _thumbnailDir.exists()) {
        final held = <String>{};
        await for (final file in _thumbnailDir.list()) {
          final name = file is File ? _heldName(file) : null;
          if (name != null) held.add(name);
        }
        cachedThumbnails.assignAll(entries.map(identifierOf).where((id) => held.contains(_fileName(id))));
      }
    } catch (e, s) {
      // A corrupt cache is only a slower first paint: the next sync rebuilds it
      Logger.warn("Discarding unreadable cache", error: e, trace: s, tag: logTag);
      readIndexExtras(null);
      entries.clear();
      cachedThumbnails.clear();
    } finally {
      loaded.value = true;
    }
  }

  /// Brings the cache up to date with the Mac: [refresh] updates [entries] (and anything the subclass keeps beside
  /// them) from the listing and writes the index if it changed, then thumbnails are fetched for whatever is new.
  /// Concurrent callers share one run, whichever [refresh] started it. A thrown error becomes [syncError] through
  /// [describeSyncError].
  @protected
  Future<void> runSync(Future<void> Function() refresh) =>
      _syncing ??= _sync(refresh).whenComplete(() => _syncing = null);

  Future<void> _sync(Future<void> Function() refresh) async {
    if (kIsWeb || SubscriptionSvc.locked) return;
    await load();
    await _followAccount(SettingsSvc.serverDetails.iCloudAccount);
    syncing.value = true;
    try {
      await refresh();
      syncError.value = null;
      await _fetchMissingThumbnails();
      await _pruneFiles();
    } catch (e, s) {
      syncError.value = describeSyncError(e, s);
    } finally {
      syncing.value = false;
    }
  }

  Future<void> _fetchMissingThumbnails() async {
    final missing = entries.map(identifierOf).where((id) => !cachedThumbnails.contains(id)).toList();
    if (missing.isEmpty) return;
    await _thumbnailDir.create(recursive: true);
    await fetchThumbnails(missing);
  }

  /// Removes cached images for entries the library no longer lists.
  Future<void> _pruneFiles() async {
    final keep = entries.map((e) => _fileName(identifierOf(e))).toSet();
    for (final dir in [_thumbnailDir, _fullDir]) {
      if (!await dir.exists()) continue;
      await for (final file in dir.list()) {
        if (file is! File) continue;
        final name = _heldName(file);
        if (name != null && !keep.contains(name)) await file.delete().catchError((_) => file);
      }
    }
    cachedThumbnails.removeWhere((id) => !keep.contains(_fileName(id)));
  }

  @protected
  Future<void> writeIndex() async {
    await _root.create(recursive: true);
    await _indexFile.writeAsString(
      jsonEncode({
        ...indexExtras(),
        'account': _account,
        'reason': unavailableReason.value,
        'entries': entries.map(entryToMap).toList(),
      }),
    );
  }

  /// The kept send copy of [identifier], or [download]ed and kept.
  @protected
  Future<Uint8List> cachedFullImage(String identifier, Future<Uint8List> Function() download) async {
    final file = fullFile(identifier);
    if (await file.exists()) return file.readAsBytes();
    final bytes = await download();
    await _fullDir.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  /// Drops [identifier] from the cache, after the Mac removed it.
  @protected
  Future<void> removeFromCache(String identifier) async {
    entries.removeWhere((e) => identifierOf(e) == identifier);
    cachedThumbnails.remove(identifier);
    await writeIndex();
    for (final file in [thumbnailFile(identifier), fullFile(identifier)]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Drops everything cached on disk and in memory (after a reset, or when the server's account changes).
  Future<void> clearCache() async {
    _account = null;
    await _drop();
  }

  Future<void> _drop() async {
    entries.clear();
    cachedThumbnails.clear();
    unavailableReason.value = null;
    syncError.value = null;
    readIndexExtras(null);
    if (!kIsWeb && await _root.exists()) await _root.delete(recursive: true);
  }

  bool _isOtherAccount(String? account) =>
      account != null && account.isNotEmpty && _account != null && account != _account;

  /// Drops the cache when the server's iCloud account isn't the one it came from, and otherwise remembers the account
  /// for the next write. An unknown account says nothing.
  Future<void> _followAccount(String? account) async {
    if (account == null || account.isEmpty) return;
    if (_isOtherAccount(account)) {
      Logger.info("The server's iCloud account changed; dropping the cached library", tag: logTag);
      await _drop();
    }
    _account = account;
  }
}

/// Drops the sticker and Genmoji caches held in memory, without creating either service. Their files go with
/// `FilesystemSvc.deleteCacheDirectories`.
Future<void> clearRemoteLibraryCaches() async {
  if (GetIt.I.isRegistered<StickerLibraryService>() &&
      GetIt.I.checkLazySingletonInstanceExists<StickerLibraryService>()) {
    await StickerLibrarySvc.clearCache();
  }
  if (GetIt.I.isRegistered<GenmojiLibraryService>() &&
      GetIt.I.checkLazySingletonInstanceExists<GenmojiLibraryService>()) {
    await GenmojiLibrarySvc.clearCache();
  }
}
