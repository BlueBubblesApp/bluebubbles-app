import 'dart:async';

import 'package:bluebubbles/helpers/network/metadata/models/metadata_fetch_result.dart';

/// Process-lifetime cache in front of [UrlMetadataFetcher].
///
/// Serves two jobs:
///
///  * **Single-flight** — many bubbles can request the same link in the same
///    frame (a list plus a reply preview plus the popup). Only one network
///    request runs; everyone else awaits the same future.
///  * **Short-lived result cache** — repeated scrolls over the same message do
///    not re-hit the network.
///
/// Keys are the *normalised URL*, not the message GUID. Keying by GUID meant
/// two messages linking the same page each paid for a fetch, and it was the
/// source of the old cache-key mismatch between insertion and eviction.
class MetadataMemoryCache {
  MetadataMemoryCache({
    this.successTtl = const Duration(minutes: 30),
    this.failureTtl = const Duration(minutes: 2),
    this.maxEntries = 128,
  });

  /// How long a successful result is reused.
  final Duration successTtl;

  /// How long a failure is remembered, to avoid hammering a dead host while
  /// the user scrolls past the same message repeatedly.
  final Duration failureTtl;

  /// Upper bound on retained entries; the oldest are dropped past this.
  final int maxEntries;

  final Map<String, _CacheEntry> _entries = {};
  final Map<String, Future<MetadataFetchResult>> _inFlight = {};

  /// Runs [task] for [key], collapsing concurrent callers onto one execution
  /// and reusing a recent result when there is one.
  Future<MetadataFetchResult> runOnce(String key, Future<MetadataFetchResult> Function() task) {
    final cached = _entries[key];
    if (cached != null) {
      if (!cached.isExpired) return Future.value(cached.result);
      _entries.remove(key);
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    // `whenComplete` runs on both the success and the error path, so the
    // in-flight entry can never be left behind — which is what previously
    // pinned a failed URL in the cache for the life of the process.
    final future = Future<MetadataFetchResult>(task).then((result) {
      _store(key, result);
      return result;
    });

    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
  }

  /// Drops any memoised entry for [key], so the next call refetches.
  void invalidate(String key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
  }

  void _store(String key, MetadataFetchResult result) {
    // A retryable failure is not worth remembering for long, and caching
    // "disabled by user" would survive the user flipping the setting back on.
    if (result.status == MetadataFetchStatus.disabledByUser) return;

    final ttl = result.isSuccess ? successTtl : failureTtl;
    _entries[key] = _CacheEntry(result, DateTime.now().add(ttl));

    if (_entries.length <= maxEntries) return;

    // Evict expired entries first, then the entries closest to expiry.
    _entries.removeWhere((_, entry) => entry.isExpired);
    if (_entries.length <= maxEntries) return;

    final ordered = _entries.entries.toList()..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));
    for (final entry in ordered.take(_entries.length - maxEntries)) {
      _entries.remove(entry.key);
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.result, this.expiresAt);

  final MetadataFetchResult result;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
