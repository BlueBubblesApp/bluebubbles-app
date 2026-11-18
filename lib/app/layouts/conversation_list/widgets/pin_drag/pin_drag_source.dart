import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/chat_drag_source.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/drop_slot.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/grow_in.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/pin_drag/pin_drag_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Makes a chat list tile draggable into the pinned grid to pin it: hold then drag on touch, click and drag with
/// a mouse. A hold that doesn't move does what the tile's long press does: peek on iOS, select otherwise.
///
/// The row for [PinDragController.unpinPreviewGuid] is the room the list made for a pin dragged over it; the list
/// rebuilds its rows when that changes, so this reads it without an `Obx` of its own.
class PinDragSource extends StatelessWidget {
  const PinDragSource({super.key, required this.drag, required this.chat, required this.child});

  final PinDragController drag;
  final Chat chat;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The room made for a pin being dragged over the list, which stays until its own row takes over.
    if (drag.unpinPreviewGuid == chat.guid) {
      return DropSlot(
        drag: drag,
        pin: false,
        child: GrowIn(
          child: IgnorePointer(
            // Faded while the drag hovers; hidden once dropped, while the flight carries the pin into it.
            child: Obx(() => Opacity(
                  opacity: drag.flyingGuid == chat.guid ? 0 : 0.3,
                  child: RepaintBoundary(key: drag.unpinRowBoundary, child: child),
                )),
          ),
        ),
      );
    }
    // Keyed by chat: the lists build rows by index, so after a drop the row a chat left would otherwise hand its
    // drag state (a collapsed size, mid-animation) to whichever chat moves into it.
    return ChatDragSource(
      key: ValueKey(chat.guid),
      drag: drag,
      chat: chat,
      startsInPinArea: false,
      onHold: (position) {
        if (context.iOS) {
          if (NavigationSvc.isTabletMode(context)) return null;
          peekChat(context, chat, position);
          return closeChatPeek;
        }
        if (!Get.isRegistered<ConversationTileController>(tag: chat.guid)) return null;
        final tile = Get.find<ConversationTileController>(tag: chat.guid)..onSelected();
        return tile.onSelected;
      },
      child: child,
    );
  }
}
