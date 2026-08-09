import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Windows/Linux replacement for the stock shared_preferences backend.
///
/// The stock `shared_preferences_windows`/`_linux` stores keep a per-isolate
/// in-memory snapshot of the JSON file, loaded once on first access, and every
/// write rewrites the whole file from that snapshot. With prefs used from the
/// main isolate, GlobalIsolate, and sync isolate, any write from one isolate
/// silently reverts keys written by another since that isolate started
/// (https://github.com/flutter/flutter/issues/143844). The stock store also
/// writes the file in place, so killing the app mid-write truncates it and the
/// legacy `SharedPreferences.getInstance()` then throws on every launch
/// (https://github.com/flutter/flutter/issues/89211).
///
/// This store fixes both:
/// - No cache: every operation re-reads the file, so no isolate ever writes
///   from a stale snapshot.
/// - Writes are serialized across isolates AND processes with an exclusively
///   created lock file. (`RandomAccessFile.lock` is not enough: POSIX fcntl
///   locks are process-owned and do not exclude isolates within one process.)
/// - Writes are atomic: temp file + rename, so the store can never be
///   truncated by a crash mid-write.
/// - Every successful write also refreshes a `.bak` copy (under the same
///   lock), and an unparseable file is quarantined and restored from that
///   backup — at registration and on mid-session reads — instead of crashing
///   the app or losing all settings.
///
/// Storage location and format are identical to the stock implementation, so
/// existing user data carries over untouched. Custom file names via
/// platform-specific [SharedPreferencesOptions] subclasses are not supported;
/// the app only ever uses the defaults.
base class DesktopSharedPreferencesStore extends SharedPreferencesAsyncPlatform {
  DesktopSharedPreferencesStore._();

  static const String _tag = 'DesktopPrefsStore';
  static const String _fileName = 'shared_preferences.json';
  static const String _backupSuffix = '.bak';
  static const Duration _staleLockTimeout = Duration(seconds: 10);
  static const Duration _lockRetryDelay = Duration(milliseconds: 5);
  static const int _renameAttempts = 5;

  String? _cachedDirectoryPath;
  Future<void> _writeQueue = Future.value();

  /// Registers this store as the [SharedPreferencesAsyncPlatform] and
  /// recovers a corrupt preferences file (quarantine + restore from backup)
  /// before the legacy `SharedPreferences.getInstance()` (which throws on
  /// unparseable JSON) gets a chance to read it. Must be called before any
  /// prefs access in every isolate; only valid on Windows and Linux.
  static Future<void> register() async {
    final store = DesktopSharedPreferencesStore._();
    await store._recoverCorruptFile();
    SharedPreferencesAsyncPlatform.instance = store;
  }

  /// This store registers (and recovers/migrates) before [BaseLogger] exists
  /// in every isolate's init sequence, so fall back to the console for
  /// messages logged during that window.
  static void _log(String message) {
    try {
      Logger.warn(message, tag: _tag);
    } catch (_) {
      debugPrint('[$_tag] $message');
    }
  }

  @override
  Future<void> setString(String key, String value, SharedPreferencesOptions options) =>
      _mutate((prefs) => prefs[key] = value);

  @override
  Future<void> setBool(String key, bool value, SharedPreferencesOptions options) =>
      _mutate((prefs) => prefs[key] = value);

  @override
  Future<void> setDouble(String key, double value, SharedPreferencesOptions options) =>
      _mutate((prefs) => prefs[key] = value);

  @override
  Future<void> setInt(String key, int value, SharedPreferencesOptions options) =>
      _mutate((prefs) => prefs[key] = value);

  @override
  Future<void> setStringList(String key, List<String> value, SharedPreferencesOptions options) =>
      _mutate((prefs) => prefs[key] = value);

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) async => (await _readFile())[key] as String?;

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async => (await _readFile())[key] as bool?;

  @override
  Future<double?> getDouble(String key, SharedPreferencesOptions options) async => (await _readFile())[key] as double?;

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async => (await _readFile())[key] as int?;

  @override
  Future<List<String>?> getStringList(String key, SharedPreferencesOptions options) async =>
      ((await _readFile())[key] as List<Object?>?)?.cast<String>().toList();

  @override
  Future<void> clear(ClearPreferencesParameters parameters, SharedPreferencesOptions options) {
    final Set<String>? allowList = parameters.filter.allowList;
    return _mutate((prefs) => prefs.removeWhere((key, _) => allowList == null || allowList.contains(key)));
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final Map<String, Object> prefs = await _readFile();
    final Set<String>? allowList = parameters.filter.allowList;
    if (allowList != null) {
      prefs.removeWhere((key, _) => !allowList.contains(key));
    }
    return prefs;
  }

  @override
  Future<Set<String>> getKeys(GetPreferencesParameters parameters, SharedPreferencesOptions options) async =>
      (await getPreferences(parameters, options)).keys.toSet();

  Future<String> _getDirectoryPath() async {
    if (_cachedDirectoryPath != null) return _cachedDirectoryPath!;
    // Instantiated directly (instead of going through path_provider) so this
    // works in background isolates without plugin registration, exactly like
    // the stock implementations do.
    final String? directory = Platform.isWindows
        ? await PathProviderWindows().getApplicationSupportPath()
        : await PathProviderLinux().getApplicationSupportPath();
    if (directory == null) {
      throw const FileSystemException('Unable to resolve the application support directory for preferences');
    }
    return _cachedDirectoryPath = directory;
  }

  Future<File> _getDataFile() async => File(p.join(await _getDirectoryPath(), _fileName));

  Future<File> _getBackupFile() async => File('${(await _getDataFile()).path}$_backupSuffix');

  /// Returns the parsed contents of [file], `{}` for an existing-but-empty
  /// file, or null when the file is missing or unparseable.
  Map<String, Object>? _parseFile(File file) {
    try {
      if (!file.existsSync()) return null;
      final String contents = file.readAsStringSync();
      if (contents.isEmpty) return <String, Object>{};
      final Object? decoded = json.decode(contents);
      return decoded is Map ? decoded.cast<String, Object>() : null;
    } on FormatException catch (e) {
      _log('Failed to parse ${file.path}: $e');
      return null;
    } on FileSystemException catch (e) {
      _log('Failed to read ${file.path}: $e');
      return null;
    }
  }

  Future<Map<String, Object>> _readFile() async {
    Map<String, Object>? prefs = _parseFile(await _getDataFile());
    if (prefs == null) {
      prefs = _parseFile(await _getBackupFile());
      if (prefs != null) {
        _log('Preferences file unreadable, using backup');
      }
    }
    return prefs ?? <String, Object>{};
  }

  /// Read-modify-write under the cross-isolate lock. Operations within this
  /// isolate are additionally serialized through [_writeQueue] so they queue
  /// up instead of spinning against each other on the lock file.
  Future<void> _mutate(void Function(Map<String, Object> prefs) mutator) {
    final Future<void> result = _writeQueue.then((_) => _locked(() async {
          final Map<String, Object> prefs = await _readFile();
          mutator(prefs);
          await _atomicWrite(prefs);
        }));
    _writeQueue = result.catchError((Object e) {
      _log('Write failed: $e');
    });
    return result;
  }

  /// Runs [action] while holding an exclusively created lock file — the only
  /// primitive that excludes both other isolates and other processes on all
  /// desktop platforms.
  Future<T> _locked<T>(Future<T> Function() action) async {
    final File lockFile = File('${(await _getDataFile()).path}.lock');
    while (true) {
      try {
        lockFile.createSync(recursive: true, exclusive: true);
        break;
      } on FileSystemException {
        _breakStaleLock(lockFile);
        await Future.delayed(_lockRetryDelay);
      }
    }
    try {
      return await action();
    } finally {
      try {
        lockFile.deleteSync();
      } on FileSystemException {
        // Best effort — a leftover lock is broken by _breakStaleLock later.
      }
    }
  }

  /// Deletes the lock file if its holder appears to have died while holding it.
  void _breakStaleLock(File lockFile) {
    try {
      if (DateTime.now().difference(lockFile.lastModifiedSync()) > _staleLockTimeout) {
        _log('Breaking stale preferences lock');
        lockFile.deleteSync();
      }
    } on FileSystemException {
      // Lock was released between the failed create and now — just retry.
    }
  }

  /// Writes to a temp file and renames it over the data file so a crash
  /// mid-write can never leave a truncated store behind. Then refreshes the
  /// backup from the just-written file — encoded from memory and still under
  /// the lock, so the backup is always a complete, parseable snapshot.
  Future<void> _atomicWrite(Map<String, Object> prefs) async {
    final File file = await _getDataFile();
    final File tmp = File('${file.path}.tmp');
    try {
      final RandomAccessFile raf = tmp.openSync(mode: FileMode.write);
      try {
        raf.writeStringSync(json.encode(prefs));
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
      await _renameWithRetry(tmp, file.path);
    } on FileSystemException catch (e) {
      _log('Failed to save preferences: $e');
      return;
    }
    try {
      file.copySync((await _getBackupFile()).path);
    } on FileSystemException catch (e) {
      _log('Failed to refresh preferences backup: $e');
    }
  }

  /// Renaming over the data file fails on Windows while a concurrent reader
  /// (e.g. the stock legacy store reading at startup) briefly holds it open,
  /// so retry a few times before giving up.
  Future<void> _renameWithRetry(File tmp, String targetPath) async {
    for (int attempt = 1;; attempt++) {
      try {
        tmp.renameSync(targetPath);
        return;
      } on FileSystemException {
        if (attempt >= _renameAttempts) rethrow;
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  /// Quarantines an unparseable preferences file and restores the last good
  /// backup in its place, so startup recovers prior settings instead of
  /// throwing on every launch or starting empty. Also seeds the backup on
  /// first run so recovery works before the first write.
  Future<void> _recoverCorruptFile() => _locked(() async {
        final File file = await _getDataFile();
        final File backup = await _getBackupFile();
        try {
          if (_parseFile(file) != null) {
            if (!backup.existsSync()) file.copySync(backup.path);
            return;
          }
          if (file.existsSync()) {
            final String quarantinePath = '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}';
            _log('Quarantining corrupt preferences file to $quarantinePath');
            file.renameSync(quarantinePath);
          }
          if (_parseFile(backup) != null) {
            _log('Restoring preferences from backup');
            backup.copySync(file.path);
          }
        } on FileSystemException catch (e) {
          _log('Corrupt-file recovery failed: $e');
        }
      });
}
