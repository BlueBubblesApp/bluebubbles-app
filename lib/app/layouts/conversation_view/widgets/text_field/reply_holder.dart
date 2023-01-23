import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyHolder extends StatefulWidget {
  const ReplyHolder({Key? key, required this.controller}) : super(key: key);

  final ConversationViewController controller;

  @override
  OptimizedState createState() => _ReplyHolderState();
}

class _ReplyHolderState extends OptimizedState<ReplyHolder> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final message = widget.controller.replyToMessage?.item1;
      final part = widget.controller.replyToMessage?.item2 ?? 0;
      final reply = message?.guid == null ? message : (getActiveMwc(message!.guid!)?.parts[part] ?? message);
      final date = widget.controller.scheduledDate.value;
      if (reply != null || date != null) {
        return Container(
          color: context.theme.colorScheme.properSurface,
          padding: EdgeInsets.only(left: !iOS ? 20.0 : 0, right: iOS ? 8.0 : 0),
          child: Row(
            children: [
              if (iOS)
                IconButton(
                  constraints: kIsWeb || kIsDesktop ? null : const BoxConstraints(maxWidth: 30),
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb || kIsDesktop ? 12 : 8, vertical: kIsWeb || kIsDesktop ? 20 : 5),
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: context.theme.colorScheme.properOnSurface,
                    size: 17,
                  ),
                  onPressed: () {
                    widget.controller.replyToMessage = null;
                    widget.controller.scheduledDate.value = null;
                  },
                  iconSize: 17,
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    if (iOS && reply != null)
                      const TextSpan(text: "Replying to "),
                    if (reply != null)
                      TextSpan(
                        text: message!.handle?.displayName ?? "You",
                        style: context.textTheme.bodyMedium!.copyWith(fontWeight: iOS ? FontWeight.bold : FontWeight.w400),
                      ),
                    if (date != null)
                      TextSpan(
                        text: "Scheduling for ${buildFullDate(date)}",
                        style: context.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (!iOS)
                      const TextSpan(text: "\n"),
                    if (reply != null)
                      TextSpan(
                        text: "${iOS ? " - " : ""}${MessageHelper.getNotificationText(reply is MessagePart ? Message(
                          text: reply.text,
                          subject: reply.subject,
                          attachments: reply.attachments,
                        ).mergeWith(message!) : message!)}",
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
                  constraints: kIsWeb || kIsDesktop ? null : const BoxConstraints(maxWidth: 30),
                  padding: EdgeInsets.symmetric(horizontal: kIsWeb || kIsDesktop ? 12 : 8, vertical: kIsWeb || kIsDesktop ? 20 : 5),
                  icon: Icon(
                    Icons.close,
                    color: context.theme.colorScheme.properOnSurface,
                    size: 17,
                  ),
                  onPressed: () {
                    widget.controller.replyToMessage = null;
                    widget.controller.scheduledDate.value = null;
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
