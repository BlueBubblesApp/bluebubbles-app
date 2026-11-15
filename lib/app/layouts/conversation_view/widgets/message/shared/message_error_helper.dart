import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Helper class for getting error display information
class ErrorHelper {
  /// Returns the body text to display for an error dialog.
  /// Uses the message's [errorMessage] field when available; falls back to a
  /// generic string for older/legacy entries that may not have it set.
  static String getErrorText(Message message) {
    return message.errorMessage ?? "An unknown error occurred.";
  }

  /// Returns the dialog title for the given numeric error code.
  /// Client-side errors show their [ClientMessageError.friendlyTitle].
  /// Server-side errors (including the well-known code 22) fall back to
  /// "iMessage Error (Code X)", and zero / unrecognized codes use a generic title.
  static String getErrorTitle(int errorCode) {
    final clientError = ClientMessageErrorExtension.fromCode(errorCode);
    if (clientError != null) return clientError.friendlyTitle;
    if (errorCode > 0) return "iMessage Error (Code $errorCode)";
    return "Message Failed to Send";
  }
}

/// Shared widget for displaying message/reaction error dialogs
class MessageErrorDialog extends StatelessWidget {
  const MessageErrorDialog({
    super.key,
    required this.errorCode,
    required this.errorText,
    required this.onRetry,
    required this.onRemove,
    required this.chatId,
    this.removeLabel = "Remove",
    this.title,
  });

  final int errorCode;
  final String errorText;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final int chatId;

  /// [onRemove]'s button. A failed tapback removal's just dismisses it (the tapback stays), so it reads "OK"
  final String removeLabel;

  /// In place of the error code's title, for an error that's better named by what failed
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      title: Text(title ?? ErrorHelper.getErrorTitle(errorCode), style: context.theme.textTheme.titleLarge),
      content: Text(errorText, style: context.theme.textTheme.bodyLarge),
      actions: <Widget>[
        TextButton(
          child: Text("Retry",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
          onPressed: () async {
            Navigator.of(context).pop();
            onRetry();
          },
        ),
        TextButton(
          child: Text(removeLabel,
              style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
          onPressed: () async {
            Navigator.of(context).pop();
            onRemove();
            await NotificationsSvc.clearFailedToSend(chatId);
          },
        ),
        TextButton(
          child: Text("Cancel",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
          onPressed: () async {
            Navigator.of(context).pop();
            await NotificationsSvc.clearFailedToSend(chatId);
          },
        )
      ],
    );
  }
}

/// Shared retry logic for reactions
Future<void> retryReaction({
  required Message reaction,
  required Chat chat,
  required Message selected,
}) async {
  // A sticker tapback is re-sent with its sticker, read before the failed one (and its file) goes
  final sticker = ReactionTypes.isStickerTapback(reaction.associatedMessageType)
      ? reaction.dbAttachments.firstOrNull
      : null;
  final stickerFile = sticker == null || kIsWeb ? null : File(sticker.path);
  final stickerBytes = stickerFile != null && await stickerFile.exists() ? await stickerFile.readAsBytes() : null;

  // Remove the original message and notification
  await MessagesSvc(chat.guid).deleteMessage(reaction);
  await NotificationsSvc.clearFailedToSend(chat.id!);

  // Remove from parent MessageState
  final parentState = MessagesSvc(chat.guid).getMessageStateIfExists(reaction.associatedMessageGuid!);
  if (parentState != null) {
    parentState.removeAssociatedMessageInternal(reaction);
  }

  // Re-send
  if (stickerBytes != null) {
    await OutgoingMsgHandler.queueStickerTapback(
      chat: chat,
      selected: selected,
      part: reaction.associatedMessagePart ?? 0,
      bytes: stickerBytes,
      fileName: sticker!.transferName ?? 'sticker.png',
      remove: reaction.associatedMessageType == ReactionTypes.REMOVED_STICKER,
    );
    return;
  }
  OutgoingMsgHandler.queue(
    OutgoingReaction(
      chat: chat,
      message: Message(
        associatedMessageGuid: selected.guid,
        associatedMessageType: reaction.associatedMessageType,
        associatedMessageEmoji: reaction.associatedMessageEmoji,
        associatedMessagePart: reaction.associatedMessagePart,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
      ),
      selectedMessage: selected,
      reaction: reaction.associatedMessageType!,
    ),
  );
}

/// Shared remove logic for reactions
Future<void> removeReaction({
  required Message reaction,
  required Chat chat,
}) async {
  // Delete the message from DB and service
  await MessagesSvc(chat.guid).deleteMessage(reaction);

  // Remove from parent MessageState
  final parentState = MessagesSvc(chat.guid).getMessageStateIfExists(reaction.associatedMessageGuid!);
  if (parentState != null) {
    parentState.removeAssociatedMessageInternal(reaction);
  }

  await NotificationsSvc.clearFailedToSend(chat.id!);
  // Get the "new" latest info
  List<Message> latest = await Chat.getMessagesAsync(chat, limit: 1);
  ChatsSvc.setChatLatestMessage(chat, latest.first);
  await chat.saveAsync();
}

/// Shared retry logic for regular messages
Future<void> retryMessage({
  required Message message,
  required Chat chat,
  required MessagesService service,
  required MessageState controller,
}) async {
  // Retry message through service (updates DB and MessageState)
  await service.retryFailedMessage(message, oldGuid: message.guid);

  // Force UI rebuild to show unsent color
  controller.update();
}
