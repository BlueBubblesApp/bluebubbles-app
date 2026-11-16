import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/drop_slot.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One pin in the pinned grid, and a drop target: a drag entering it previews the dragged chat in its place.
///
/// Only its own look reads the drag: faded while it is the chat being dragged, hidden while a drop's flight carries
/// it in.
class PinGridSlot extends StatelessWidget {
  const PinGridSlot({
    super.key,
    required this.chat,
    required this.listController,
    required this.avatarSize,
    required this.onHover,
    required this.onDrop,
  });

  final Chat chat;
  final ConversationListController listController;
  final double avatarSize;

  /// A drag of the given chat over this pin.
  final void Function(String dragged) onHover;
  final void Function(DragTargetDetails<String> details) onDrop;

  @override
  Widget build(BuildContext context) {
    final drag = listController.pinDrag;
    final tile = PinnedConversationTile(
      chat: chat,
      avatarSize: avatarSize,
      controller: listController,
      pinDrag: drag,
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        drag.setOverPinArea(true);
        onHover(details.data);
        return true;
      },
      // An entry during the slide cooldown is dropped, so retried until it takes.
      onMove: (details) => onHover(details.data),
      onAcceptWithDetails: onDrop,
      builder: (context, _, _) => Obx(() {
        final dragged = drag.movedGuid == chat.guid;
        final faded = Opacity(opacity: drag.flyingGuid == chat.guid ? 0 : (dragged ? 0.3 : 1), child: tile);
        return dragged ? DropSlot(drag: drag, pin: true, child: faded) : faded;
      }),
    );
  }
}
