import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:flutter/material.dart';

/// Marks where a drop lands, for its [DropFlight] to aim at: the dragged chat's slot among the pins ([pin]), or the
/// room the list made for an unpin.
class DropSlot extends StatefulWidget {
  const DropSlot({super.key, required this.drag, required this.pin, required this.child});

  final PinDragController drag;
  final bool pin;
  final Widget child;

  @override
  State<DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<DropSlot> {
  @override
  void initState() {
    super.initState();
    widget.drag.attachSlot(context, pin: widget.pin);
  }

  @override
  void dispose() {
    widget.drag.detachSlot(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
