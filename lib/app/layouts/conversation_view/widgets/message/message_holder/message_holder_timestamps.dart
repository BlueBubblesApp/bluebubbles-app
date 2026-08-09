import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/message_timestamp.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Isolated widget for Samsung timestamp with reaction-aware padding
class SamsungTimestampObserver extends StatelessWidget {
  const SamsungTimestampObserver({
    super.key,
    required this.messageParts,
    required this.part,
    required this.cvController,
    required this.reactionsForPart,
  });

  final List<MessagePart> messageParts;
  final MessagePart part;
  final ConversationViewController cvController;
  final Iterable<Message> Function(int, List<Message>) reactionsForPart;

  @override
  Widget build(BuildContext context) {
    final ms = MessageStateScope.of(context);
    return Obx(() {
      // Directly observe MessageState associatedMessages for reactivity
      final isFromMe = ms.isFromMe.value;
      final associatedMessages = ms.associatedMessages;
      final reactions = associatedMessages
          .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")))
          .toList();
      return Padding(
        padding: (messageParts.length == 1 && reactions.isNotEmpty) || reactionsForPart(part.part, reactions).isNotEmpty
            ? EdgeInsets.only(left: isFromMe ? 0 : 10, right: isFromMe ? 20 : 0)
            : const EdgeInsets.only(right: 10),
        child: MessageTimestamp(controller: ms, cvController: cvController),
      );
    });
  }
}

/// Isolated widget for edit history display
/// Only rebuilds when showEdits flag changes
class EditHistoryObserver extends StatelessWidget {
  const EditHistoryObserver({
    super.key,
    required this.part,
    required this.newerMessage,
    required this.showAvatar,
    required this.alwaysShowAvatars,
    required this.avatarScale,
  });

  final MessagePart part;
  final Message? newerMessage;
  final bool showAvatar;
  final bool alwaysShowAvatars;
  final double avatarScale;

  @override
  Widget build(BuildContext context) {
    final ms = MessageStateScope.of(context);
    final message = MessageStateScope.messageOf(context);
    return Padding(
      padding: showAvatar || alwaysShowAvatars ? EdgeInsets.only(left: 35.0 * avatarScale) : EdgeInsets.zero,
      child: Obx(() => AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.bottomCenter,
            curve: ms.showEdits.value ? Curves.easeOutBack : Curves.easeOut,
            child: ms.showEdits.value
                ? Opacity(
                    opacity: 0.75,
                    child: Column(
                      crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: part.edits
                          .map((edit) => ClipPath(
                                clipper: TailClipper(
                                  isFromMe: message.isFromMe!,
                                  showTail: !part.isPkPass &&
                                      message.showTail(newerMessage) &&
                                      part.part == ms.parts.length - 1,
                                  connectLower: SettingsSvc.settings.skin.value == Skins.iOS
                                      ? false
                                      : (part.part != 0 && part.part != ms.parts.length - 1) ||
                                          (part.part == 0 && ms.parts.length > 1),
                                  connectUpper: SettingsSvc.settings.skin.value == Skins.iOS ? false : part.part != 0,
                                ),
                                child: TextBubble(
                                  message: edit,
                                ),
                              ))
                          .toList(),
                    ),
                  )
                : Container(
                    height: 0,
                    constraints:
                        BoxConstraints(maxWidth: NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 30)),
          )),
    );
  }
}
