import 'dart:async';
import 'dart:collection';

import 'package:bluebubbles/utils/logger/logger.dart';

/// A unit of work that mutates the message list. Async bodies are allowed —
/// the gate starts them in submission order and does not await them, so the
/// synchronous prefix of each (where list insertion/removal actually happens)
/// still runs in the order it was submitted.
typedef GatedWork = FutureOr<void> Function();

/// Defers structural mutations of the message list while a send animation is in
/// flight.
///
/// [SendAnimation] flies a bubble from the text field down to the bottom of the
/// message list, and its landing target is derived from the live layout of
/// everything sitting below the list — the text field, the typing indicator row
/// and the smart reply row. A message arriving mid-flight inserts into the
/// [SliverAnimatedList], can toggle the smart reply row, and can shift the
/// typing indicator, all of which move that target while `AnimatedPositioned`
/// is still animating toward the old one. The bubble then lands in the wrong
/// place and snaps into position.
///
/// This is deliberately **not** a mutual-exclusion lock. No caller ever blocks
/// on it and it can never delay a send — the send is the thing holding it.
/// While the gate is held, work passed to [run] is appended to a FIFO queue and
/// replayed, in submission order, the moment the gate opens. Work submitted
/// while the gate is open runs inline, synchronously, exactly as if the gate
/// weren't there.
///
/// Callers that represent the send itself (the outgoing message the animation
/// is landing on) must bypass the gate and mutate the list directly — see
/// `MessagesViewState.handleNewMessage`.
class MessageListGate {
  MessageListGate({Duration? maxHold}) : _maxHold = maxHold ?? const Duration(milliseconds: 2000);

  /// Upper bound on a single hold. The send animation runs ~650ms end to end;
  /// this only exists so a hold whose release is lost (dropped frame, animation
  /// callback that never fires) can't strand queued messages forever.
  final Duration _maxHold;

  final Queue<GatedWork> _deferred = Queue<GatedWork>();

  Timer? _watchdog;
  bool _held = false;
  bool _disposed = false;

  /// Whether work submitted right now would be deferred.
  bool get isHeld => _held;

  /// Number of units of work currently waiting for the gate to open.
  int get deferredCount => _deferred.length;

  /// Closes the gate. Calling this while already held is a no-op beyond
  /// restarting the watchdog — a second send extends the current hold rather
  /// than nesting, and anything already queued stays queued.
  void hold() {
    if (_disposed) return;
    _held = true;
    _watchdog?.cancel();
    _watchdog = Timer(_maxHold, () {
      Logger.warn(
        'Gate held for ${_maxHold.inMilliseconds}ms without a release — force-releasing '
        '${_deferred.length} deferred item(s)',
        tag: 'MessageListGate',
      );
      release();
    });
  }

  /// Runs [work] now if the gate is open, otherwise queues it until [release].
  void run(GatedWork work) {
    if (_held && !_disposed) {
      _deferred.add(work);
      return;
    }
    _invoke(work);
  }

  /// Opens the gate and replays everything queued while it was held, in order.
  void release() {
    _watchdog?.cancel();
    _watchdog = null;
    if (!_held) return;
    // Open the gate before draining so that work which re-enters run() during
    // the drain executes inline instead of queueing behind the drain loop.
    _held = false;
    _drain();
  }

  /// Releases the gate permanently. Anything still queued is replayed rather
  /// than dropped — a deferred message that never reaches the list would be
  /// missing from the view until the chat is reopened.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _watchdog?.cancel();
    _watchdog = null;
    _held = false;
    _drain();
  }

  void _drain() {
    while (_deferred.isNotEmpty) {
      _invoke(_deferred.removeFirst());
    }
  }

  void _invoke(GatedWork work) {
    try {
      work();
    } catch (e, s) {
      Logger.error('Deferred message list work threw', error: e, trace: s, tag: 'MessageListGate');
    }
  }
}
