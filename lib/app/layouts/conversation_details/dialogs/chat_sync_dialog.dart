import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/classes/aliases.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatSyncDialog extends StatefulWidget {
  ChatSyncDialog({
    super.key,
    required this.chatGuid,
    this.initialMessage,
    this.withOffset = false,
    this.limit = 100
  });

  final ChatGuid chatGuid;
  final String? initialMessage;
  final bool withOffset;
  final int limit;

  @override
  State<ChatSyncDialog> createState() => _ChatSyncDialogState();
}

class _ChatSyncDialogState extends OptimizedState<ChatSyncDialog> {
  String? errorCode;
  bool finished = false;
  String? message;
  double? progress;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
    syncMessages();
  }

  void syncMessages() async {
    final chat = GlobalChatService.getChat(widget.chatGuid)!.chat;

    int offset = 0;
    if (widget.withOffset) {
      offset = Message.countForChat(chat) ?? 0;
    }

    cm.getMessages(chat.guid, offset: offset, limit: widget.limit).then((dynamic messages) {
      if (mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(chat, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }
        setState(() {});
      }).then((List<Message> __) {
        onFinish(true);
      });
    }).catchError((_) {
      onFinish(false);
    });
  }

  void onFinish([bool success = true]) {
    if (success) Navigator.of(context).pop();
    if (!success) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(errorCode != null ? "Error!" : message!, style: context.theme.textTheme.titleLarge),
      content: errorCode != null
          ? Text(errorCode!, style: context.theme.textTheme.bodyLarge)
          : SizedBox(
              height: 5,
              child: Center(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.theme.colorScheme.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            ),
      backgroundColor: context.theme.colorScheme.properSurface,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ],
    );
  }
}