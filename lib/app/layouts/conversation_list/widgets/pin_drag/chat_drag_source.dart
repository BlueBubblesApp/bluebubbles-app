import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_drag_feedback.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_draggables.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/drop_flight.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Drags a chat (a pin or a list tile) for the pinned grid and [UnpinDropTarget].
///
/// The gesture follows the pointer, not the platform, since desktop has both. On touch (or a stylus) the drag starts
/// on the hold, so [onHold] runs right then (opening the peek, say) and returns how to undo it; the undo runs once
/// the finger moves, which is what turns the hold into a drag. With a mouse a click and drag starts it and there is
/// no hold; on a list row, where dragging the mouse scrolls the list, only a mostly horizontal move starts it (see
/// [MouseChatDraggable]).
class ChatDragSource extends StatefulWidget {
  const ChatDragSource({
    super.key,
    required this.drag,
    required this.chat,
    required this.startsInPinArea,
    required this.onHold,
    required this.child,
  });

  final PinDragController drag;
  final Chat chat;
  final bool startsInPinArea;
  final VoidCallback? Function(Offset position) onHold;
  final Widget child;

  @override
  State<ChatDragSource> createState() => _ChatDragSourceState();
}

class _ChatDragSourceState extends State<ChatDragSource> {
  /// How far the finger moves before a hold becomes a drag.
  static const double _holdSlop = 12;

  Offset _downPosition = Offset.zero;
  VoidCallback? _undoHold;
  bool _moved = false;

  /// The list row, for a drag that doesn't pin to fly back into.
  final GlobalKey _rowKey = GlobalKey();

  int _generation = 0;

  PinDragController get drag => widget.drag;

  void _onStart({required bool touch}) {
    // A mouse drag only starts once it has moved.
    _generation = drag.start(widget.chat.guid, fromPins: widget.startsInPinArea, moved: !touch);
    _moved = false;
    if (!touch) return;
    _undoHold = widget.onHold(_downPosition);
    final peeking = _undoHold == closeChatPeek;
    // The peek buzzes on its own.
    if (!peeking) HapticFeedback.mediumImpact();
    // A hold with nothing of its own to do (no peek in tablet mode) is the drag already.
    if (_undoHold == null) {
      _moved = true;
      drag.markMoved();
    }
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_moved || (details.globalPosition - _downPosition).distance < _holdSlop) return;
    _moved = true;
    drag.markMoved();
    _undoHold?.call();
    _undoHold = null;
  }

  void _onCanceled(Offset offset) {
    if (drag.moved) {
      if (widget.startsInPinArea) {
        // Released off both the pins and the list: still a pin, so back to its place. The pin left the grid when
        // the drag left it, so this state may be gone.
        final grid = drag.gridContext;
        drag.setOverPinArea(true);
        if (grid != null && grid.mounted) DropFlight.show(grid, drag, widget.chat.guid, offset, toPin: true);
      } else if (mounted) {
        // Not pinned after all: back into its row, turning from a pin into it on the way.
        drag.setOverPinArea(false);
        DropFlight.show(context, drag, widget.chat.guid, offset, toPin: false, rowKey: _rowKey);
      }
    }
    _onEnd();
  }

  void _onEnd() {
    _undoHold = null;
    drag.finish(_generation);
  }

  /// The list row as it shows while a drag is on: hidden while a flight carries it in, gone while it hovers the pins,
  /// faded where it would land otherwise.
  Widget _listLook({required bool dragging}) => Obx(() {
        // Inside the fades, so a snapshot of it shows the row as it lands.
        final row = RepaintBoundary(key: _rowKey, child: widget.child);
        if (drag.flyingGuid == widget.chat.guid) return Opacity(opacity: 0, child: row);
        final mine = drag.draggedGuid == widget.chat.guid;
        if (mine && drag.overPinArea) return const SizedBox.shrink();
        return mine && dragging && drag.moved ? Opacity(opacity: 0.3, child: row) : row;
      });

  @override
  Widget build(BuildContext context) {
    final feedback = ChatDragFeedback(
      drag: drag,
      chat: widget.chat,
      listWidth: min(MediaQuery.sizeOf(context).width - 24, 480),
      alwaysPin: true,
    );
    final Widget child = widget.startsInPinArea ? widget.child : _listLook(dragging: false);
    final Widget whileDragging = widget.startsInPinArea ? widget.child : _listLook(dragging: true);
    final data = widget.chat.guid;
    // Each takes only its own pointer kinds, so nesting them gives each pointer its own gesture.
    final Widget draggable = TouchChatDraggable(
      data: data,
      feedback: feedback,
      childWhenDragging: whileDragging,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Beats the tile's own long press to the gesture; the hold action runs from here instead.
      delay: kLongPressTimeout - const Duration(milliseconds: 100),
      hapticFeedbackOnStart: false,
      onDragStarted: () => _onStart(touch: true),
      onDragUpdate: _onUpdate,
      // Not onDragEnd: Flutter skips it once the source is unmounted, which a pin is as soon as hovering the list
      // takes it out of the grid. These two always run.
      onDragCompleted: _onEnd,
      onDraggableCanceled: (_, offset) => _onCanceled(offset),
      child: MouseChatDraggable(
        data: data,
        feedback: feedback,
        childWhenDragging: whileDragging,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        anyDirection: widget.startsInPinArea,
        scrolls: (kind) => ScrollConfiguration.of(context).dragDevices.contains(kind),
        onDragStarted: () => _onStart(touch: false),
        onDragCompleted: _onEnd,
        onDraggableCanceled: (_, offset) => _onCanceled(offset),
        child: child,
      ),
    );
    return Listener(
      onPointerDown: (event) => _downPosition = event.position,
      child: widget.startsInPinArea
          ? draggable
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: draggable,
            ),
    );
  }
}
