import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/drop_flight.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Unpins a pin dropped on [child], the chat list below the pinned grid. Drops on the grid itself never reach it.
class UnpinDropTarget extends StatelessWidget {
  const UnpinDropTarget({super.key, required this.drag, required this.child});

  final PinDragController drag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        drag.setOverPinArea(false);
        return ChatsSvc.findChatByGuid(details.data)?.isPinned ?? false;
      },
      onAcceptWithDetails: (details) {
        // Released from a hold that never moved, after a select slid the list under it.
        if (!drag.moved) return;
        final chat = ChatsSvc.findChatByGuid(details.data);
        if (chat == null) return;
        drag.markDropped(ChatsSvc.setChatPinned(chat, false));
        // With pointerDragAnchorStrategy the drop offset is the finger, where the pin was drawn.
        DropFlight.show(context, drag, details.data, details.offset, toPin: false);
      },
      // Tiles don't light up under a mouse while it's carrying a chat.
      builder: (context, _, _) => Obx(() {
        final theme = context.theme;
        return Theme(data: drag.active ? theme.copyWith(hoverColor: Colors.transparent) : theme, child: child);
      }),
    );
  }
}
