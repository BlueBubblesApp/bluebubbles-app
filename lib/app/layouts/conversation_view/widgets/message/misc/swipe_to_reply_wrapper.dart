import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/models/models.dart' show MessageReplyContext;
import 'package:bluebubbles/services/ui/chat/conversation_view_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Handles swipe-to-reply gesture detection and haptic feedback
/// Extracted from MessageHolder to improve readability and reusability
class SwipeToReplyWrapper extends StatefulWidget {
  const SwipeToReplyWrapper({
    super.key,
    required this.enabled,
    required this.partIndex,
    required this.replyOffset,
    required this.cvController,
    required this.child,
    this.attachmentGuid,
  });

  final bool enabled;

  /// Message-part id being replied to
  final int partIndex;
  final RxDouble replyOffset;
  final ConversationViewController cvController;
  final Widget child;

  /// When set, reply preview / send target a specific attachment within the part.
  final String? attachmentGuid;

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper> {
  bool gaveHapticFeedback = false;

  void _handleHapticFeedback() {
    if (!gaveHapticFeedback && widget.replyOffset.value.abs() >= SlideToReply.replyThreshold) {
      HapticFeedback.lightImpact();
      gaveHapticFeedback = true;
    } else if (widget.replyOffset.value.abs() < SlideToReply.replyThreshold) {
      gaveHapticFeedback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final message = MessageStateScope.messageOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragUpdate: (details) {
        if (ReplyScope.maybeOf(context) != null) return;

        widget.replyOffset.value += details.delta.dx * 0.5;

        // Clamp based on message direction
        if (message.isFromMe!) {
          widget.replyOffset.value = widget.replyOffset.value.clamp(-double.infinity, 0);
        } else {
          widget.replyOffset.value = widget.replyOffset.value.clamp(0, double.infinity);
        }

        _handleHapticFeedback();
      },
      onHorizontalDragEnd: (details) {
        if (ReplyScope.maybeOf(context) != null) return;

        // Trigger reply if threshold reached
        if (widget.replyOffset.value.abs() >= SlideToReply.replyThreshold) {
          widget.cvController.replyToMessage = MessageReplyContext(
            message,
            widget.partIndex,
            attachmentGuid: widget.attachmentGuid,
          );
        }

        widget.replyOffset.value = 0;
      },
      onHorizontalDragCancel: () {
        if (ReplyScope.maybeOf(context) != null) return;
        widget.replyOffset.value = 0;
      },
      child: widget.child,
    );
  }
}
