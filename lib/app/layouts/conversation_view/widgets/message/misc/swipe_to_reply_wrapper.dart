import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/helpers/helpers.dart';
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

/// Self-contained swipe-to-reply for a single attachment card: owns its own offset and draws the
/// [SlideToReply] chevron beside [child] (on the author's side).
///
/// For layouts that render attachments individually inside one message part (e.g. the collage), where
/// [MessageHolder]'s per-part swipe row doesn't apply. The reply targets [partIndex] and, when set,
/// [attachmentGuid].
class SwipeToReplyRow extends StatefulWidget {
  const SwipeToReplyRow({
    super.key,
    required this.partIndex,
    required this.attachmentGuid,
    required this.cvController,
    required this.isFromMe,
    required this.child,
  });

  final int partIndex;
  final String? attachmentGuid;
  final ConversationViewController cvController;
  final bool isFromMe;
  final Widget child;

  @override
  State<SwipeToReplyRow> createState() => _SwipeToReplyRowState();
}

class _SwipeToReplyRowState extends State<SwipeToReplyRow> {
  final RxDouble _replyOffset = 0.0.obs;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offset = _replyOffset.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwipeToReplyWrapper(
            enabled: true,
            partIndex: widget.partIndex,
            attachmentGuid: widget.attachmentGuid,
            replyOffset: _replyOffset,
            cvController: widget.cvController,
            child: widget.child,
          ),
          AnimatedPadding(
            duration: Duration(milliseconds: offset == 0 ? 150 : 0),
            padding: EdgeInsets.only(
              left: widget.isFromMe && offset != 0 ? 10 : 0,
              right: !widget.isFromMe && offset != 0 ? 10 : 0,
            ),
            child: SlideToReply(
              width: offset.abs(),
              isFromMe: widget.isFromMe,
            ),
          ),
        ].conditionalReverse(widget.isFromMe),
      );
    });
  }
}
