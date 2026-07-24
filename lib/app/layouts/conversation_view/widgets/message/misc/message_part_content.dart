import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/message_image_gallery.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        final state = MessageStateScope.of(context);
        return Padding(
            padding:
                EdgeInsets.only(left: !chat.isGroup && SettingsSvc.settings.alwaysShowAvatars.value == false ? 20 : 10),
            child: Obx(() {
              // Each attachment in the gallery may originally have been its own
              // message part (see MessageHolder._collapseImageGalleryParts), so a
              // tapback can be associated with just one image/video, not the whole
              // gallery. Map reactions back to the specific attachment they landed on.
              final reactions = state.associatedMessages
                  .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")))
                  .toList();
              final reactionsByAttachmentKey = <String, List<Message>>{};
              for (int i = 0; i < messagePart.attachments.length; i++) {
                final attachment = messagePart.attachments[i];
                final key = attachment.guid ?? attachment.transferName;
                if (key == null) continue;
                final originalPart = messagePart.partIndexForAttachment(i);
                final matches = reactions.where((r) => (r.associatedMessagePart ?? 0) == originalPart).toList();
                if (matches.isNotEmpty) reactionsByAttachmentKey[key] = matches;
              }

              return MessageImageGallery(
                attachments: messagePart.attachments,
                partIndex: messagePart.part,
                isInReply: false,
                fanDirection: message.isFromMe == true ? GalleryFanDirection.left : GalleryFanDirection.right,
                currentIndexNotifier: galleryCurrentIndexNotifier,
                reactionsByAttachmentKey: reactionsByAttachmentKey,
              );
            }));
      }
      return AttachmentHolder(
        message: messagePart,
      );
    }

    // Empty/unsupported message
    return const SizedBox.shrink();
  }
}
