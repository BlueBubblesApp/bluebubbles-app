import 'dart:async';

import 'package:bluebubbles/services/ui/cache/clearable_cache.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
CacheService get CacheSvc => GetIt.I<CacheService>();

/// Per-cache actions for one purge level, keyed by [ClearableCache.id].
///
/// A cache missing from a policy gets [CacheService.defaultActions] for that
/// level, so new caches are covered the moment they register.
typedef CachePurgePolicy = Map<String, CachePurgeAction>;

/// Registry of every in-process cache the app can shrink or drop, plus the
/// policies that decide what happens to each one at each [CachePurgeLevel].
///
/// Why this exists: Android's low memory killer evicts the largest cached
/// process first, and most of what this app holds while backgrounded is
/// rebuildable (decoded images, inline video decoders, GPU textures). Releasing
/// it on pause makes the process a smaller target without changing anything the
/// user sees on resume beyond a reload from disk.
///
/// Usage:
/// ```dart
/// await CacheSvc.clear('images');                  // one cache
/// await CacheSvc.trim('images', 8 * 1024 * 1024);  // by size
/// await CacheSvc.clearMany(['images', 'videoPlayers']);
/// await CacheSvc.purge(CachePurgeLevel.aggressive, reason: 'user request');
/// ```
///
/// The lifecycle service calls [onAppBackgrounded] and [onMemoryPressure];
/// nothing else should need to trigger purges on a schedule.
class CacheService {
  static const String _tag = 'CacheService';

  /// How long an engine purge we requested ourselves is allowed to echo back as
  /// a memory-pressure callback before that callback is treated as genuine.
  static const Duration _enginePressureWindow = Duration(seconds: 10);

  final Map<String, ClearableCache> _caches = {};

  /// Level applied by [onAppBackgrounded]; null disables the automatic purge.
  ///
  /// Deliberately starts at the minor end. The plan is to raise it only as
  /// device testing shows what each step actually buys and costs on resume.
  CachePurgeLevel? backgroundLevel = CachePurgeLevel.light;

  /// Level applied by [onMemoryPressure]; null disables it.
  CachePurgeLevel? memoryPressureLevel = CachePurgeLevel.moderate;

  /// Caches that automatic (policy-driven) purges leave alone. Explicit calls
  /// such as [clear] still work on them. Mutated from settings, see
  /// `CacheServiceSettings.loadFromSettings`.
  final Set<String> excludedIds = {};

  /// The most recent purge, for the developer tools page.
  final Rxn<CachePurgeReport> lastReport = Rxn<CachePurgeReport>();

  /// Action for any cache a policy does not name, per level.
  final Map<CachePurgeLevel, CachePurgeAction> defaultActions = {
    CachePurgeLevel.light: CachePurgeAction.skip,
    CachePurgeLevel.moderate: CachePurgeAction.clear,
    CachePurgeLevel.aggressive: CachePurgeAction.clear,
  };

  /// Per-level, per-cache overrides of [defaultActions]. Mutable so a caller
  /// (or a future setting) can tune a level without subclassing.
  final Map<CachePurgeLevel, CachePurgePolicy> policies = {
    CachePurgeLevel.light: {
      // Keep the most recent quarter of decoded images so the chat that was
      // open still paints instantly on resume.
      'images': const CachePurgeAction.trimToFraction(0.25),
      'engine': CachePurgeAction.clear,
    },
    CachePurgeLevel.moderate: {
      // Inline players are the one thing with a visible cost to rebuild (the
      // bubble falls back to its thumbnail), so moderate leaves them alone.
      'videoPlayers': CachePurgeAction.skip,
    },
    CachePurgeLevel.aggressive: const {},
  };

  Timer? _enginePressureTimer;
  bool _expectingEnginePressure = false;
  Future<CachePurgeReport>? _inFlight;

  // ── Registry ────────────────────────────────────────────────────────────

  void register(ClearableCache cache) {
    if (_caches.containsKey(cache.id)) {
      Logger.warn('Cache "${cache.id}" registered twice; replacing', tag: _tag);
    }
    _caches[cache.id] = cache;
  }

  void registerAll(Iterable<ClearableCache> caches) => caches.forEach(register);

  void unregister(String id) => _caches.remove(id);

  ClearableCache? operator [](String id) => _caches[id];

  List<ClearableCache> get caches => List.unmodifiable(_caches.values);

  List<String> get ids => List.unmodifiable(_caches.keys);

  /// Current size and entry count of every cache that can report them.
  Map<String, ({int? bytes, int? entries})> snapshot() {
    return {for (final c in _caches.values) c.id: (bytes: c.currentSizeBytes, entries: c.entryCount)};
  }

  /// Sum of every measurable cache, for logs and diagnostics.
  int get measurableBytes => _caches.values.fold(0, (sum, c) => sum + (c.currentSizeBytes ?? 0));

  // ── Granular operations ─────────────────────────────────────────────────

  /// Drops everything in one cache.
  Future<CachePurgeEntry> clear(String id, {String reason = 'request'}) async {
    final report = await _run(reason, null, {id: CachePurgeAction.clear});
    return report.entries.first;
  }

  /// Shrinks one cache to at most [maxBytes].
  Future<CachePurgeEntry> trim(String id, int maxBytes, {String reason = 'request'}) async {
    final report = await _run(reason, null, {id: CachePurgeAction.trimTo(maxBytes)});
    return report.entries.first;
  }

  /// Drops everything in each named cache.
  Future<CachePurgeReport> clearMany(Iterable<String> ids, {String reason = 'request'}) {
    return _run(reason, null, {for (final id in ids) id: CachePurgeAction.clear});
  }

  /// Drops everything in every registered cache, memory and disk alike.
  Future<CachePurgeReport> clearAll({String reason = 'request'}) {
    return _run(reason, null, {for (final id in _caches.keys) id: CachePurgeAction.clear});
  }

  /// Applies explicit per-cache actions. Caches not named are left alone.
  Future<CachePurgeReport> apply(CachePurgePolicy actions, {String reason = 'request'}) {
    return _run(reason, null, actions);
  }

  // ── Policy-driven purges ────────────────────────────────────────────────

  /// Purges every memory cache according to [level]'s policy. [overrides]
  /// take precedence over the stored policy for this call only.
  Future<CachePurgeReport> purge(
    CachePurgeLevel level, {
    String reason = 'request',
    CachePurgePolicy? overrides,
    bool includeDisk = false,
  }) {
    final policy = policies[level] ?? const {};
    final fallback = defaultActions[level] ?? CachePurgeAction.clear;
    final actions = <String, CachePurgeAction>{};
    for (final cache in _caches.values) {
      if (!includeDisk && cache.kind == CacheKind.disk) continue;
      if (excludedIds.contains(cache.id)) {
        actions[cache.id] = CachePurgeAction.skip;
        continue;
      }
      actions[cache.id] = overrides?[cache.id] ?? policy[cache.id] ?? fallback;
    }
    return _run(reason, level, actions);
  }

  /// Called by the lifecycle service when the app is backgrounded on mobile.
  /// Returns null when [backgroundLevel] is off.
  Future<CachePurgeReport?> onAppBackgrounded() async {
    final level = backgroundLevel;
    if (level == null) {
      Logger.debug('Background purge is off; holding caches', tag: _tag);
      return null;
    }
    return purge(level, reason: 'app backgrounded');
  }

  /// Called by the lifecycle service on `didHaveMemoryPressure`.
  ///
  /// Returns null when [memoryPressureLevel] is off, or when the signal is the
  /// echo of an engine purge this service requested itself (see
  /// [markEnginePurgeRequested]), which Flutter reports back through the same
  /// channel as a genuine OS warning.
  Future<CachePurgeReport?> onMemoryPressure() async {
    if (_expectingEnginePressure) {
      _clearEnginePressureFlag();
      Logger.debug('Memory pressure callback matches our own engine purge; not purging again', tag: _tag);
      return null;
    }
    final level = memoryPressureLevel;
    if (level == null) {
      Logger.debug('Memory pressure purge is off; holding caches', tag: _tag);
      return null;
    }
    return purge(level, reason: 'memory pressure');
  }

  /// Caches that purge the engine itself call this right before doing so.
  void markEnginePurgeRequested() {
    _expectingEnginePressure = true;
    _enginePressureTimer?.cancel();
    _enginePressureTimer = Timer(_enginePressureWindow, _clearEnginePressureFlag);
  }

  void _clearEnginePressureFlag() {
    _expectingEnginePressure = false;
    _enginePressureTimer?.cancel();
    _enginePressureTimer = null;
  }

  // ── Execution ───────────────────────────────────────────────────────────

  /// Runs [actions] one cache at a time, serialised behind any purge already in
  /// flight so two triggers close together (pause, then the OS trim that
  /// follows it) cannot interleave on the same cache.
  Future<CachePurgeReport> _run(String reason, CachePurgeLevel? level, CachePurgePolicy actions) {
    final previous = _inFlight;
    final current = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // The earlier purge already logged its own failure.
        }
      }
      return _execute(reason, level, actions);
    }();
    _inFlight = current;
    current.whenComplete(() {
      if (identical(_inFlight, current)) _inFlight = null;
    });
    return current;
  }

  Future<CachePurgeReport> _execute(String reason, CachePurgeLevel? level, CachePurgePolicy actions) async {
    final stopwatch = Stopwatch()..start();
    final entries = <CachePurgeEntry>[];

    for (final entry in actions.entries) {
      final cache = _caches[entry.key];
      if (cache == null) {
        Logger.warn('No cache registered as "${entry.key}"; ignoring', tag: _tag);
        continue;
      }
      entries.add(await _applyAction(cache, entry.value));
    }

    stopwatch.stop();
    final report = CachePurgeReport(reason: reason, level: level, entries: entries, elapsed: stopwatch.elapsed);
    lastReport.value = report;
    if (report.hadErrors) {
      Logger.warn(report.summarize(), tag: _tag);
    } else {
      Logger.info(report.summarize(), tag: _tag);
    }
    return report;
  }

  Future<CachePurgeEntry> _applyAction(ClearableCache cache, CachePurgeAction action) async {
    final bytesBefore = cache.currentSizeBytes;
    final entriesBefore = cache.entryCount;

    if (action.type == CachePurgeActionType.skip) {
      return CachePurgeEntry(
        id: cache.id,
        action: action,
        bytesBefore: bytesBefore,
        bytesAfter: bytesBefore,
        entriesBefore: entriesBefore,
        entriesAfter: entriesBefore,
      );
    }

    Object? error;
    try {
      switch (action.type) {
        case CachePurgeActionType.clear:
          await cache.clear();
          break;
        case CachePurgeActionType.trimTo:
          await _trim(cache, action.maxBytes ?? 0);
          break;
        case CachePurgeActionType.trimToFraction:
          final size = bytesBefore;
          if (size == null) {
            // Nothing to scale against; the only honest fallback is a clear.
            await cache.clear();
          } else {
            await _trim(cache, (size * (action.fraction ?? 0)).floor());
          }
          break;
        case CachePurgeActionType.skip:
          break;
      }
    } catch (e, stack) {
      error = e;
      Logger.error('Failed to ${action.describe()} cache "${cache.id}"', error: e, trace: stack, tag: _tag);
    }

    return CachePurgeEntry(
      id: cache.id,
      action: action,
      bytesBefore: bytesBefore,
      bytesAfter: cache.currentSizeBytes,
      entriesBefore: entriesBefore,
      entriesAfter: cache.entryCount,
      error: error,
    );
  }

  Future<void> _trim(ClearableCache cache, int maxBytes) {
    if (!cache.supportsTrim) return cache.clear();
    return cache.trimTo(maxBytes);
  }
}
