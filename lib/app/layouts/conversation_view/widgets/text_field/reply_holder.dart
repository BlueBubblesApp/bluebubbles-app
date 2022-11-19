import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyHolder extends StatefulWidget {
  const ReplyHolder({Key? key, required this.controller}) : super(key: key);

  final ConversationViewController controller;

  @override
  _ReplyHolderState createState() => _ReplyHolderState();
}

class _ReplyHolderState extends OptimizedState<ReplyHolder> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final message = widget.controller.replyToMessage?.item1;
      final part = widget.controller.replyToMessage?.item2 ?? 0;
      final reply = message?.guid == null ? message : (getActiveMwc(message!.guid!)?.parts[part] ?? message);
      if (reply != null) {
        return Container(
          color: context.theme.colorScheme.properSurface,
          child: Row(
            children: [
              if (iOS)
                IconButton(
                  constraints: BoxConstraints(maxWidth: 30),
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: context.theme.colorScheme.properOnSurface,
                    size: 17,
                  ),
                  onPressed: () {
                    widget.controller.replyToMessage = null;
                  },
                  iconSize: 17,
                ),
              if (!iOS)
                const SizedBox(width: 20),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    if (iOS)
                      const TextSpan(text: "Replying to "),
                    TextSpan(
                      text: message!.handle?.displayName ?? "You",
                      style: context.textTheme.bodyMedium!.copyWith(fontWeight: iOS ? FontWeight.bold : FontWeight.w400),
                    ),
                    if (!iOS)
                      const TextSpan(text: "\n"),
                    TextSpan(
                      text: "${iOS ? " - " : ""}${MessageHelper.getNotificationText(reply is MessagePart ? Message(
                        text: reply.text,
                        subject: reply.subject,
                        attachments: reply.attachments,
                      ).mergeWith(message) : message)}",
                      style: context.textTheme.bodyMedium!.copyWith(fontStyle: iOS ? FontStyle.italic : null).apply(fontSizeFactor: iOS ? 1 : 1.15),
                    ),
                  ]),
                  style: context.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                  maxLines: iOS ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!iOS)
                IconButton(
                  constraints: BoxConstraints(maxWidth: 30),
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  icon: Icon(
                    Icons.close,
                    color: context.theme.colorScheme.properOnSurface,
                    size: 17,
                  ),
                  onPressed: () {
                    widget.controller.replyToMessage = null;
                  },
                  iconSize: 25,
                ),
            ],
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    });
  }
}
