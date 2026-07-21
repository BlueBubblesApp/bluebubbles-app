import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_collage.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_gallery.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Renders the appropriate content widget based on message type
/// Extracted from MessageHolder to reduce nesting and improve readability
class MessagePartContent extends StatelessWidget {
  const MessagePartContent({
    super.key,
    required this.messagePart,
    this.galleryCurrentIndexNotifier,
  });

  final MessagePart messagePart;
  final ValueNotifier<int>? galleryCurrentIndexNotifier;

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.messageOf(context);
    final chat = ChatStateScope.chatOf(context);
    // Interactive messages (URL previews, GamePigeon, etc.)
    if (message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive) {
      return InteractiveHolder(
        message: messagePart,
      );
    }

    // Text-only messages
    if (messagePart.attachments.isEmpty && (messagePart.text != null || messagePart.subject != null)) {
      return TextBubble(
        message: messagePart,
      );
    }

    // Messages with attachments
    if (messagePart.attachments.isNotEmpty) {
      final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
      if (iOS && messagePart.isMediaGallery) {
        final fanDirection =
            message.isFromMe == true ? GalleryFanDirection.left : GalleryFanDirection.right;
        final padding = EdgeInsets.only(
            left: !chat.isGroup && SettingsSvc.settings.alwaysShowAvatars.value == false ? 20 : 10);
        // 2–3 items: vertical collage; 4+: swipeable fan stack
        if (messagePart.attachments.length <= 3) {
          return Padding(
            padding: padding,
            child: MessageImageCollage(
              attachments: messagePart.attachments,
              partIndex: messagePart.part,
              fanDirection: fanDirection,
            ),
          );
        }
        return Padding(
          padding: padding,
          child: MessageImageGallery(
            attachments: messagePart.attachments,
            partIndex: messagePart.part,
            isInReply: false,
            fanDirection: fanDirection,
            currentIndexNotifier: galleryCurrentIndexNotifier,
          ),
        );
      }
      return AttachmentHolder(
        message: messagePart,
      );
    }

    // Empty/unsupported message
    return const SizedBox.shrink();
  }
}
