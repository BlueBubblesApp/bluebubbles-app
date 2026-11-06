import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show StickerPlacement;
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

/// Isolated widget for reaction display
/// Only rebuilds when MessageState.associatedMessages changes
///
/// Not used for media-collection parts on any skin — those show tapbacks per
/// attachment (`CollectionAttachmentReactions`), since a collection can bundle
/// several originally-separate message parts (see
/// MessagePart.collapseMediaCollections) and a tapback is only ever
/// associated with one of them.
class ReactionObserver extends StatelessWidget {
  const ReactionObserver({
    super.key,
    required this.part,
    required this.chatGuid,
  });

  final MessagePart part;
  final String chatGuid;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      // Directly observe MessageState for all reactive data
      final isFromMe = state.isFromMe.value;
      final reactionList = state.tapbacksForBubble(part);

      return Positioned(
        top: ReactionHolder.bubbleOverhangTop,
        left: isFromMe ? ReactionHolder.bubbleOverhangSide : null,
        right: isFromMe ? null : ReactionHolder.bubbleOverhangSide,
        child: ReactionHolder(
          reactions: reactionList,
        ),
      );
    });
  }
}

/// Isolated widget for sticker display.
/// Uses its own [Obx] so sticker rebuilds are decoupled from the outer
/// message-holder [Obx] (which tracks isSending, isFromMe, parts, etc.).
class StickerObserver extends StatelessWidget {
  const StickerObserver({
    super.key,
    required this.part,
    required this.cvController,
    this.placed = false,
  });

  final MessagePart part;
  final ConversationViewController cvController;

  /// Only stickers with a sender placement (filling the bubble's Stack), or only those without
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      final stickersForPart = state
          .stickersForBubble(part)
          .where((e) => e.dbAttachments.any((a) => StickerPlacement.tryParse(a.stickerPlacement) != null) == placed)
          .toList();

      if (stickersForPart.isEmpty) return const SizedBox.shrink();

      final holder = StickerHolder(
        stickerMessages: stickersForPart,
        controller: cvController,
        placed: placed,
        hidden: state.showingPopup.value,
        isFromMe: state.message.isFromMe ?? false,
        tailGutter: !part.isMediaCollection,
      );
      return placed ? Positioned.fill(child: holder) : holder;
    });
  }
}

/// Isolated widget for reaction spacing calculation
/// Only rebuilds when reactions change, not the entire message part
class ReactionSpacing extends StatelessWidget {
  const ReactionSpacing({
    super.key,
    required this.part,
    this.minHeightWhenNoReactions = 0,
  });

  final MessagePart part;
  final double minHeightWhenNoReactions;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = MessageStateScope.of(context);
      // Reads associatedMessages, so this rebuilds when tapbacks change. Collapsed collection spans are
      // matched via MessagePart.coversPartId.
      if (state.hasVisibleTapbacks(part)) {
        return const SizedBox(height: 12.5);
      }

      if (minHeightWhenNoReactions > 0) {
        return SizedBox(height: minHeightWhenNoReactions);
      }

      return const SizedBox.shrink();
    });
  }
}

/// Grows [child], the bubble's Stack, by [StickerHolder.space] so its placed stickers always have room in the message
/// list instead of drawing over neighboring messages or off-screen. Presses in that room go to the bubble.
class StickerSpace extends StatelessWidget {
  const StickerSpace({super.key, required this.part, required this.columnWidth, required this.child});

  final MessagePart part;

  /// Width of the message column the bubble sits against; the room around it never grows past this
  final double columnWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() => _StickerOverhang(
          stickers: state
              .stickersForBubble(part)
              .expand((e) => e.dbAttachments)
              .map((a) => PlacedSticker.of(a, a.guid == null ? null : state.stickerSizes[a.guid]))
              .nonNulls
              .toList(),
          isFromMe: state.message.isFromMe ?? false,
          tailGutter: !part.isMediaCollection,
          columnWidth: columnWidth,
          child: child,
        ));
  }
}

class _StickerOverhang extends SingleChildRenderObjectWidget {
  const _StickerOverhang({
    required this.stickers,
    required this.isFromMe,
    required this.tailGutter,
    required this.columnWidth,
    required Widget super.child,
  });

  final List<PlacedSticker> stickers;
  final bool isFromMe;
  final bool tailGutter;
  final double columnWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStickerOverhang(stickers, isFromMe, tailGutter, columnWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderStickerOverhang renderObject) => renderObject
    ..stickers = stickers
    ..isFromMe = isFromMe
    ..tailGutter = tailGutter
    ..columnWidth = columnWidth;
}

// The overhang depends on the bubble's laid-out size, which no Padding can know ahead of time
class _RenderStickerOverhang extends RenderShiftedBox {
  _RenderStickerOverhang(this._stickers, this._isFromMe, this._tailGutter, this._columnWidth) : super(null);

  List<PlacedSticker> _stickers;
  set stickers(List<PlacedSticker> value) {
    if (listEquals(_stickers, value)) return;
    _stickers = value;
    markNeedsLayout();
  }

  bool _isFromMe;
  set isFromMe(bool value) {
    if (_isFromMe == value) return;
    _isFromMe = value;
    markNeedsLayout();
  }

  bool _tailGutter;
  set tailGutter(bool value) {
    if (_tailGutter == value) return;
    _tailGutter = value;
    markNeedsLayout();
  }

  double _columnWidth;
  set columnWidth(double value) {
    if (_columnWidth == value) return;
    _columnWidth = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    final space = StickerHolder.space(_stickers, child.size, _isFromMe, _tailGutter, _columnWidth);
    (child.parentData as BoxParentData).offset = space.topLeft;
    size = constraints.constrain(space.inflateSize(child.size));
  }

  // A press in the room kept for placed stickers lands on the bubble's center, so it opens details like the bubble
  // does. A miss on the bubble itself (its tail gutter, its rounded corners) stays a miss, as it would without this.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTestChildren(result, position: position)) return true;
    final child = this.child!;
    final offset = (child.parentData as BoxParentData).offset;
    if (_stickers.isEmpty || (offset & child.size).contains(position)) return false;
    return super.hitTestChildren(result, position: offset + child.size.center(Offset.zero));
  }
}
