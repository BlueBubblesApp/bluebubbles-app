import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyHolder extends StatefulWidget {
  const ReplyHolder({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => _ReplyHolderState();
}

class _ReplyHolderState extends State<ReplyHolder> with ThemeHelpers {
  void _clearReply() {
    widget.controller.replyToMessage = null;
    widget.controller.scheduledDate.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final message = widget.controller.replyToMessage?.message;
      final partIndex = widget.controller.replyToMessage?.partIndex ?? 0;
      final attachmentGuid = widget.controller.replyToMessage?.attachmentGuid;
      final chatGuid = message?.chat.target?.guid ?? ChatStateScope.maybeChatOf(context)?.guid;
      MessagePart? matched;
      if (message?.guid != null && chatGuid != null) {
        final state = maybeFindMessagesSvc(chatGuid)?.getMessageStateIfExists(message!.guid!);
        if (state != null) {
          if (attachmentGuid != null) {
            matched = state.parts.firstWhereOrNull((p) => p.attachments.any((a) => a.guid == attachmentGuid));
          }
          matched ??= state.partById(partIndex);
        }
      }
      final resolvedReply = matched ?? message;
      final reply = matched != null && attachmentGuid != null
          ? MessagePart(
              part: matched.part,
              text: matched.text,
              subject: matched.subject,
              attachments: matched.attachments.where((a) => a.guid == attachmentGuid).toList(),
              mentions: matched.mentions,
              edits: matched.edits,
              isUnsent: matched.isUnsent,
              shouldRedact: matched.shouldRedact,
            )
          : resolvedReply;
      final date = widget.controller.scheduledDate.value;

      if (reply == null && date == null) {
        return const SizedBox.shrink();
      }

      return _ReplyContent(
        message: message,
        reply: reply,
        date: date,
        onClear: _clearReply,
        onClearWithFocus: () {
          _clearReply();
          widget.controller.lastFocusedNode.requestFocus();
        },
      );
    });
  }
}

/// Extracted reply content to reduce Obx rebuild scope
class _ReplyContent extends StatelessWidget {
  const _ReplyContent({
    required this.message,
    required this.reply,
    required this.date,
    required this.onClear,
    required this.onClearWithFocus,
  });

  final Message? message;
  final dynamic reply;
  final DateTime? date;
  final VoidCallback onClear;
  final VoidCallback onClearWithFocus;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isIOS = SettingsSvc.settings.skin.value == Skins.iOS;

      return Container(
        color: context.theme.colorScheme.surfaceContainerHighest,
        padding: EdgeInsets.only(left: !isIOS ? 20.0 : 0, right: isIOS ? 8.0 : 0),
        child: Row(
          children: [
            if (isIOS)
              _CloseButton(
                icon: CupertinoIcons.xmark_circle_fill,
                onPressed: onClearWithFocus,
              ),
            Expanded(
              child: _ReplyText(
                message: message,
                reply: reply,
                date: date,
                isIOS: isIOS,
              ),
            ),
            if (!isIOS)
              _CloseButton(
                icon: Icons.close,
                iconSize: 25,
                onPressed: onClear,
              ),
          ],
        ),
      );
    });
  }
}

/// Extracted close button to isolate rebuild
class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 17,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: kIsWeb || kIsDesktop ? null : const BoxConstraints(maxWidth: 30),
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb || kIsDesktop ? 12 : 8,
        vertical: kIsWeb || kIsDesktop ? 20 : 5,
      ),
      icon: Icon(
        icon,
        color: context.theme.colorScheme.onSurfaceVariant,
        size: 17,
      ),
      onPressed: onPressed,
      iconSize: iconSize,
    );
  }
}

/// Extracted reply text to memoize expensive computation
class _ReplyText extends StatelessWidget {
  const _ReplyText({
    required this.message,
    required this.reply,
    required this.date,
    required this.isIOS,
  });

  final Message? message;
  final dynamic reply;
  final DateTime? date;
  final bool isIOS;

  String _getNotificationText() {
    final redacted = SettingsSvc.settings.redactedMode.value;
    final hideContactInfo = redacted && SettingsSvc.settings.hideContactInfo.value;
    final hideMessageContent = redacted && SettingsSvc.settings.hideMessageContent.value;

    if (reply is MessagePart) {
      // Create a fake message and append the attachments.
      // This does not add anything to the DB and is just
      // in memory for the sake of displaying the correct text
      // for a particular message part.
      final msg = Message(
        text: reply.text,
        subject: reply.subject,
        hasAttachments: reply.attachments.isNotEmpty,
      )
        ..dbAttachments.addAll(reply.attachments)
        ..mergeWith(message!);
      return msg.getNotificationText(
        hideContactInfo: hideContactInfo,
        hideMessageContent: hideMessageContent,
      );
    }
    return message!.getNotificationText(
      hideContactInfo: hideContactInfo,
      hideMessageContent: hideMessageContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final redacted = SettingsSvc.settings.redactedMode.value;
    final hideContactInfo = redacted && SettingsSvc.settings.hideContactInfo.value;
    final handle = message?.handleRelation.target;
    final handleState = handle != null ? HandleSvc.getOrCreateHandleState(handle) : null;
    final replyDisplayName = message?.isFromMe == true
        ? "Yourself"
        : hideContactInfo
            ? (handleState?.displayName.value ?? handleState?.fakeName ?? "Someone")
            : (handleState?.displayName.value ?? handle?.displayName ?? "Unknown");

    return Text.rich(
      TextSpan(children: [
        if (isIOS && reply != null) const TextSpan(text: "Replying to "),
        if (reply != null)
          TextSpan(
            children: MessageHelper.buildEmojiText(
                replyDisplayName,
                context.textTheme.bodyMedium!.copyWith(
                  fontWeight: isIOS ? FontWeight.bold : FontWeight.w400,
                )),
          ),
        if (date != null)
          TextSpan(
            text: "Scheduling for ${buildFullDate(date!)}",
            style: context.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        if (!isIOS) const TextSpan(text: "\n"),
        if (reply != null)
          TextSpan(
              children: MessageHelper.buildEmojiText(
            "${isIOS ? " - " : ""}${_getNotificationText()}",
            context.textTheme.bodyMedium!
                .copyWith(fontStyle: isIOS ? FontStyle.italic : null)
                .apply(fontSizeFactor: isIOS ? 1 : 1.15),
          )),
      ]),
      style: context.textTheme.labelLarge!.copyWith(
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: isIOS ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
