import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatSyncDialog extends StatefulWidget {
  const ChatSyncDialog({
    super.key,
    required this.chat,
    this.initialMessage,
    required this.start,
    required this.end,
  });

  final Chat chat;
  final String? initialMessage;

  /// The start of the time range to sync (inclusive, converted to milliseconds for the API).
  final DateTime start;

  /// The end of the time range to sync (inclusive, converted to milliseconds for the API).
  final DateTime end;

  @override
  State<ChatSyncDialog> createState() => _ChatSyncDialogState();
}

class _ChatSyncDialogState extends State<ChatSyncDialog> {
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

  Future<void> syncMessages() async {
    const int batchSize = 200;
    int offset = 0;
    int totalSynced = 0;
    Message? latestMessage;

    try {
      while (true) {
        final batch = (await ChatsSvc.getMessages(
          widget.chat.guid,
          after: widget.start.millisecondsSinceEpoch,
          before: widget.end.millisecondsSinceEpoch,
          offset: offset,
          limit: batchSize,
        ))
            .cast<Map<String, dynamic>>();

        if (batch.isEmpty) break;

        final result = await SyncInterface.bulkSyncData(
          chatData: widget.chat.toMap(),
          messagesData: batch,
        );

        totalSynced += result.messages.length;

        if (mounted) {
          setState(() {
            message = "Synced $totalSynced messages...";
          });
        }

        // Track the overall latest message across all batches.
        if (result.messages.isNotEmpty) {
          final batchLatest = result.messages.reduce((a, b) => (a.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(b.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0))
              ? a
              : b);
          if (latestMessage == null ||
              (batchLatest.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(latestMessage.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0))) {
            latestMessage = batchLatest;
          }
        }

        // A page smaller than batchSize means we've reached the end.
        if (batch.length < batchSize) break;
        offset += batchSize;
      }
    } catch (_) {
      onFinish(false);
      return;
    }

    final chatState = ChatsSvc.getChatState(widget.chat.guid);
    final currentLatest = chatState?.latestMessage.value?.dateCreated ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (latestMessage != null && (latestMessage.dateCreated?.isAfter(currentLatest) ?? false)) {
      ChatsSvc.updateChatLatestMessage(widget.chat.guid, latestMessage);
    }

    onFinish(true);
  }

  void onFinish([bool success = true]) {
    if (success) Navigator.of(context).pop();
    if (!success) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BBProgressDialog(
      title: errorCode != null ? "Error!" : message!,
      progress: progress,
      body: errorCode != null ? Text(errorCode!, style: context.theme.textTheme.bodyLarge) : null,
      actions: [
        BBDialogAction(text: "OK", onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
