import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/sticker_library_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/sticker_placement.dart';
import 'package:bluebubbles/services/network/api/sticker_api.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/material.dart';

/// Fills a message part's bubble so a sticker dragged from the sticker library (the desktop popover, or the mobile
/// picker's grid) can be dropped on it, placing it where it was dropped. Lets every other pointer event through to the
/// bubble.
class StickerDropTarget extends StatelessWidget {
  const StickerDropTarget({
    super.key,
    required this.message,
    required this.part,
    required this.chat,
    required this.tailGutter,
  });

  final Message message;
  final int part;
  final Chat chat;

  /// As [StickerHolder.tailGutter]
  final bool tailGutter;

  @override
  Widget build(BuildContext context) {
    return DragTarget<StickerDrag>(
      onWillAcceptWithDetails: (_) => !(message.guid?.startsWith("temp") ?? true),
      onAcceptWithDetails: (details) => _place(context, details),
      // Draws nothing and takes no hits, so the bubble underneath keeps working
      builder: (_, _, _) => const SizedBox.expand(),
    );
  }

  Future<void> _place(BuildContext context, DragTargetDetails<StickerDrag> details) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    // The drag feedback is centered on the pointer, which is where the drop reports
    final at = StickerHolder.placementAt(
      box.globalToLocal(details.offset),
      box.size,
      message.isFromMe ?? false,
      tailGutter,
    );
    final transform = details.data.transform.value;
    final sticker = details.data.sticker;
    try {
      final bytes = await StickerLibrarySvc.imageForSending(sticker);
      // As large as it looked while dragged: the drag draws its longest side at dragSize, times the pinch
      final scale = StickerHolder.scaleForPoints(
        StickerLibraryTile.dragSize * transform.scale,
        sticker.longestSide,
      );
      await OutgoingMsgHandler.queuePlacedSticker(
        chat: chat,
        selected: message,
        part: part,
        bytes: bytes,
        fileName: "sticker.${sticker.fileExtension}",
        placement: StickerPlacement(
          xScalar: at.xScalar,
          yScalar: at.yScalar,
          scale: scale,
          rotation: transform.rotation,
          parentPreviewWidth: at.parentPreviewWidth,
        ),
      );
    } catch (e, s) {
      Logger.warn("Failed to place a sticker", error: e, trace: s, tag: "StickerDrop");
      showSnackbar("Error", stickerRefusal(e).message ?? "Couldn't send the sticker", type: SnackbarType.error);
    }
  }
}
