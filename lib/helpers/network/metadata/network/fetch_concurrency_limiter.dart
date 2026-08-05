import 'dart:async';
import 'dart:collection';

/// Bounds how many metadata requests are in flight at once.
///
/// Without this, scrolling a conversation full of links fires one request per
/// message simultaneously — each able to hold a multi-megabyte buffer and a
/// socket. Previews are decorative; they should never be able to saturate the
/// device's connection pool or memory just because a chat contains a lot of
/// links.
///
/// Slots are handed directly from a finishing task to the next waiter, so the
/// active count stays exact even under heavy contention.
class FetchConcurrencyLimiter {
  FetchConcurrencyLimiter(this.maxConcurrent) : assert(maxConcurrent > 0);

  final int maxConcurrent;

  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  /// Requests currently executing.
  int get active => _active;

  /// Requests queued behind the limit.
  int get queued => _waiting.length;

  /// Runs [task] once a slot is free, releasing the slot when it settles.
  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value();
    }

    final completer = Completer<void>();
    _waiting.add(completer);
    // The slot is transferred by [_release], which is why `_active` is not
    // incremented here — doing both would double-count.
    return completer.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
      return;
    }
    _active--;
  }
}
