import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:flutter/material.dart';
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
  });

  final MessagePart part;
  final ConversationViewController cvController;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.of(context);
    return Obx(() {
      final stickersForPart = state.stickersForBubble(part);

      if (stickersForPart.isEmpty) return const SizedBox.shrink();

      return StickerHolder(
        stickerMessages: stickersForPart,
        controller: cvController,
      );
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
