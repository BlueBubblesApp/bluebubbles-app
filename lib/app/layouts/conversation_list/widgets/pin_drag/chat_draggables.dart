import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The pointers [MouseChatDraggable] handles. Every other kind (touch, stylus) holds then drags with
/// [TouchChatDraggable]. A trackpad's click and drag arrives as a mouse; it is listed for platforms that report it.
const Set<PointerDeviceKind> _mouseKinds = {PointerDeviceKind.mouse, PointerDeviceKind.trackpad};

final Set<PointerDeviceKind> _touchKinds = PointerDeviceKind.values.toSet().difference(_mouseKinds);

/// A chat drag by touch or stylus: hold, then drag. It takes no mouse pointers, so it can wrap a
/// [MouseChatDraggable] of the same chat and each pointer kind gets its own gesture.
class TouchChatDraggable extends LongPressDraggable<String> {
  const TouchChatDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragCompleted,
    super.onDraggableCanceled,
    super.hapticFeedbackOnStart,
    super.delay,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) =>
      super.createRecognizer(onStart)..supportedDevices = _touchKinds;
}

/// A chat drag by mouse: click and drag, with no hold.
///
/// Where dragging that pointer scrolls the list ([scrolls], from the app's scroll behavior: on Linux and Android
/// every pointer kind scrolls), a row's drag starts only on a mostly horizontal move, so a mostly vertical one keeps
/// scrolling. [anyDirection] starts it on any move, for pins, which are reordered across rows; it is also how a row
/// drags where the mouse doesn't scroll, as there is nothing for a vertical move to do instead.
///
/// [Draggable.affinity] with [Axis.horizontal] isn't enough here: it starts once the horizontal part of the move
/// passes a mouse's 1px slop, however far the pointer moved vertically, and the draggable sees each move before the
/// list it sits in does, so it would win most vertical drags.
class MouseChatDraggable extends Draggable<String> {
  const MouseChatDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.childWhenDragging,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragCompleted,
    super.onDraggableCanceled,
    required this.anyDirection,
    required this.scrolls,
  });

  final bool anyDirection;

  /// Whether dragging a pointer of this kind scrolls the list.
  final bool Function(PointerDeviceKind kind) scrolls;

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) {
    // Made once per draggable state, so it reads the settings it was first built with; both are fixed per source.
    final anyDirection = this.anyDirection;
    final scrolls = this.scrolls;
    return _MouseDragGestureRecognizer(
      startsOnAnyMove: (kind) => anyDirection || !scrolls(kind),
      allowedButtonsFilter: allowedButtonsFilter,
    )..onStart = onStart;
  }
}

class _MouseDragGestureRecognizer extends MultiDragGestureRecognizer {
  _MouseDragGestureRecognizer({required this.startsOnAnyMove, super.allowedButtonsFilter})
      : super(debugOwner: null, supportedDevices: _mouseKinds);

  final bool Function(PointerDeviceKind kind) startsOnAnyMove;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _MouseDragPointerState(event.position, event.kind, gestureSettings, anyMove: startsOnAnyMove(event.kind));

  @override
  String get debugDescription => 'chat mouse drag';
}

class _MouseDragPointerState extends MultiDragPointerState {
  _MouseDragPointerState(super.initialPosition, super.kind, super.gestureSettings, {required this.anyMove});

  final bool anyMove;

  @override
  void checkForResolutionAfterMove() {
    final delta = pendingDelta!;
    final slop = computeHitSlop(kind, gestureSettings);
    final horizontal = delta.dx.abs() > slop && delta.dx.abs() > delta.dy.abs();
    if (horizontal || (anyMove && delta.distance > slop)) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) => starter(initialPosition);
}
