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

  /// Start (or restart) the timer. Call once as early as possible in main().
  static void start() {
    _sw
      ..reset()
      ..start();
    _lastMs = 0;
    _started = true;
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
}
