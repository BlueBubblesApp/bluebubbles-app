import 'dart:async';

/// Where a cache's contents live.
///
/// Memory caches are what the lifecycle service purges when the app is
/// backgrounded. Disk caches are only ever cleared on explicit request.
enum CacheKind { memory, disk }

/// How hard to purge.
///
/// Each level is a policy over every registered cache (see
/// `CacheService.policies`), not a single global switch, so the same level can
/// trim one cache by size while leaving another untouched.
enum CachePurgeLevel {
  /// Shrink the heavy caches but keep what makes resuming feel instant.
  light,

  /// Drop everything that can be rebuilt from disk or recomputed. The default
  /// when the app goes to the background.
  moderate,

  /// Drop everything, including live media controllers. Used on an OS memory
  /// pressure signal and when explicitly requested.
  aggressive,
}

/// A memory- or disk-resident cache that can be shrunk or dropped on demand.
///
/// Implementations register with `CacheService`. Each one owns the knowledge
/// of how to measure and release its contents; the service only sequences
/// them, applies policies, and logs the outcome.
abstract class ClearableCache {
  /// Stable identifier used for lookups and policies, e.g. `images`.
  String get id;

  /// One line for logs and any future settings UI.
  String get description;

  CacheKind get kind => CacheKind.memory;

  /// Current footprint in bytes, or null when the cache cannot measure itself.
  ///
  /// Prefer a cheap estimate over null: the service logs it before and after
  /// every purge, which is how a change here gets verified on a device.
  int? get currentSizeBytes => null;

  /// Number of entries held, or null when that has no meaning for this cache.
  int? get entryCount => null;

  /// Whether [trimTo] can do something more precise than [clear].
  bool get supportsTrim => false;

  /// Releases everything held.
  Future<void> clear();

  /// Shrinks the cache to at most [maxBytes].
  ///
  /// The default falls back to [clear], which is correct for any cache that
  /// cannot trim by size. Override alongside [supportsTrim].
  Future<void> trimTo(int maxBytes) => clear();
}

enum CachePurgeActionType { skip, clear, trimTo, trimToFraction }

/// What a policy asks of one cache at one purge level.
class CachePurgeAction {
  final CachePurgeActionType type;

  /// Byte ceiling for [CachePurgeActionType.trimTo].
  final int? maxBytes;

  /// Fraction of the cache's current size to keep for
  /// [CachePurgeActionType.trimToFraction], in `0.0..1.0`.
  final double? fraction;

  const CachePurgeAction._(this.type, {this.maxBytes, this.fraction});

  /// Leave the cache alone.
  static const CachePurgeAction skip = CachePurgeAction._(CachePurgeActionType.skip);

  /// Drop everything.
  static const CachePurgeAction clear = CachePurgeAction._(CachePurgeActionType.clear);

  /// Shrink to at most [bytes]. Falls back to clearing when the cache cannot
  /// trim by size.
  const CachePurgeAction.trimTo(int bytes) : this._(CachePurgeActionType.trimTo, maxBytes: bytes);

  /// Keep only [fraction] of what the cache currently holds. Falls back to
  /// clearing when the cache cannot measure itself.
  const CachePurgeAction.trimToFraction(double fraction)
      : this._(CachePurgeActionType.trimToFraction, fraction: fraction);

  String describe() {
    switch (type) {
      case CachePurgeActionType.skip:
        return 'skip';
      case CachePurgeActionType.clear:
        return 'clear';
      case CachePurgeActionType.trimTo:
        return 'trim to ${formatCacheBytes(maxBytes ?? 0)}';
      case CachePurgeActionType.trimToFraction:
        return 'trim to ${((fraction ?? 0) * 100).round()}%';
    }
  }
}

/// What a purge did to one cache.
class CachePurgeEntry {
  final String id;
  final CachePurgeAction action;
  final int? bytesBefore;
  final int? bytesAfter;
  final int? entriesBefore;
  final int? entriesAfter;
  final Object? error;

  const CachePurgeEntry({
    required this.id,
    required this.action,
    this.bytesBefore,
    this.bytesAfter,
    this.entriesBefore,
    this.entriesAfter,
    this.error,
  });

  /// Bytes released, or null when the cache cannot measure itself.
  int? get bytesFreed => (bytesBefore == null || bytesAfter == null) ? null : bytesBefore! - bytesAfter!;

  bool get skipped => action.type == CachePurgeActionType.skip;

  String describe() {
    if (error != null) return '$id: ${action.describe()} FAILED ($error)';
    if (skipped) return '$id: skipped';
    final parts = <String>[];
    if (bytesBefore != null || bytesAfter != null) {
      parts.add('${formatCacheBytes(bytesBefore ?? 0)} -> ${formatCacheBytes(bytesAfter ?? 0)}');
    }
    if (entriesBefore != null || entriesAfter != null) {
      parts.add('${entriesBefore ?? 0} -> ${entriesAfter ?? 0} entries');
    }
    return '$id: ${action.describe()}${parts.isEmpty ? '' : ' (${parts.join(', ')})'}';
  }
}

/// Outcome of a whole purge.
class CachePurgeReport {
  final String reason;
  final CachePurgeLevel? level;
  final List<CachePurgeEntry> entries;
  final Duration elapsed;

  const CachePurgeReport({
    required this.reason,
    required this.entries,
    required this.elapsed,
    this.level,
  });

  /// Total bytes released across every cache that could measure itself.
  int get bytesFreed => entries.fold(0, (sum, e) => sum + (e.bytesFreed ?? 0));

  bool get hadErrors => entries.any((e) => e.error != null);

  String summarize() {
    final touched = entries.where((e) => !e.skipped).length;
    final head = 'purge ($reason${level == null ? '' : ', ${level!.name}}): '
        '$touched cache(s) touched, ${formatCacheBytes(bytesFreed)} measurable freed in ${elapsed.inMilliseconds}ms';
    if (entries.isEmpty) return head;
    return '$head\n  ${entries.map((e) => e.describe()).join('\n  ')}';
  }
}

/// Human-readable byte count for logs.
String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
