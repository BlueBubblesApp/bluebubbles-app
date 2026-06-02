import 'package:flutter/foundation.dart';

/// Lightweight, always-on load-time instrumentation.
///
/// Emits timestamped console logs at critical startup milestones so total
/// load time can be monitored in any build (including release web, where the
/// app's [Logger] output is suppressed). Uses [print] so it is not throttled
/// and always reaches the browser console.
///
/// Each log line looks like:
///   [BB-LOAD] +1234ms (Δ210ms) — Chats loaded (812)
/// where the first number is elapsed since app start and Δ is the time since
/// the previous milestone.
class LoadTimer {
  static final Stopwatch _sw = Stopwatch();
  static int _lastMs = 0;
  static bool _started = false;

  // Subsystems that must all finish loading before the app is truly "done".
  static final Set<String> _pending = {};
  static bool _expecting = false;

  /// Start (or restart) the timer. Call once as early as possible in main().
  static void start() {
    _sw
      ..reset()
      ..start();
    _lastMs = 0;
    _started = true;
    _pending.clear();
    _expecting = false;
    // ignore: avoid_print
    print('[${DateTime.now().toIso8601String()}] [BB-LOAD] +0ms — App start');
  }

  /// Record a milestone with the time since start and since the last mark.
  static void mark(String label) {
    if (!_started) start();
    final now = _sw.elapsedMilliseconds;
    final delta = now - _lastMs;
    _lastMs = now;
    // ignore: avoid_print
    print('[${DateTime.now().toIso8601String()}] [BB-LOAD] +${now}ms (Δ${delta}ms) — $label');
  }

  /// Register the set of subsystems whose completion together means the app is
  /// fully loaded. Call once before any [completeSubsystem] calls.
  static void expectSubsystems(Iterable<String> keys) {
    _pending
      ..clear()
      ..addAll(keys);
    _expecting = _pending.isNotEmpty;
  }

  /// Mark a subsystem as finished loading. When the last expected subsystem
  /// completes, emits a single "Everything loaded" milestone so the final log
  /// line accurately reflects when all data (chats, contacts, avatars) is ready.
  static void completeSubsystem(String key) {
    if (!_expecting) return;
    if (!_pending.remove(key)) return;
    if (_pending.isEmpty) {
      _expecting = false;
      mark("✓ Everything loaded (all chats, contacts & avatars ready)");
    }
  }
}
