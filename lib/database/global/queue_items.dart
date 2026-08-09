import 'dart:async';

import 'package:bluebubbles/database/models.dart';

enum QueueType { sendMessage, sendReaction, sendAttachment, sendMultipart }

abstract class QueueItem {
  QueueType type;
  Completer<void>? completer;

  QueueItem({required this.type, this.completer});
}

abstract class OutgoingQueueItem extends QueueItem {
  Chat chat;
  Message message;

  OutgoingQueueItem({
    required super.type,
    super.completer,
    required this.chat,
    required this.message,
  });

  /// Whether this item is a user-initiated retry of a previously-failed send.
  /// Retries reuse the message's existing GUID/DB row rather than generating
  /// a new one — see `OutgoingMessageHandler._buildOutgoingMessages`.
  bool get isRetry;

  /// Whether notifications should be cleared for this chat when the message
  /// is added. Not applicable to attachments (always `true`, unused).
  bool get clearNotificationsIfFromMe => true;

  /// The tapback/reaction type for [QueueType.sendReaction] items, `null` otherwise.
  String? get reaction => null;
}

class OutgoingMessage extends OutgoingQueueItem {
  @override
  bool isRetry;
  @override
  bool clearNotificationsIfFromMe;

  OutgoingMessage({
    super.completer,
    required super.chat,
    required super.message,
    this.isRetry = false,
    this.clearNotificationsIfFromMe = true,
  }) : super(type: QueueType.sendMessage);
}

class OutgoingReaction extends OutgoingQueueItem {
  Message selectedMessage;
  @override
  String reaction;
  @override
  bool isRetry;
  @override
  bool clearNotificationsIfFromMe;

  OutgoingReaction({
    super.completer,
    required super.chat,
    required super.message,
    required this.selectedMessage,
    required this.reaction,
    this.isRetry = false,
    this.clearNotificationsIfFromMe = true,
  }) : super(type: QueueType.sendReaction);
}

class OutgoingAttachment extends OutgoingQueueItem {
  Attachment attachment;
  bool isAudioMessage;
  @override
  bool isRetry;

  OutgoingAttachment({
    super.completer,
    required super.chat,
    required super.message,
    required this.attachment,
    this.isAudioMessage = false,
    this.isRetry = false,
  }) : super(type: QueueType.sendAttachment);
}

class OutgoingMultipartMessage extends OutgoingQueueItem {
  @override
  bool isRetry;
  @override
  bool clearNotificationsIfFromMe;

  OutgoingMultipartMessage({
    super.completer,
    required super.chat,
    required super.message,
    this.isRetry = false,
    this.clearNotificationsIfFromMe = true,
  }) : super(type: QueueType.sendMultipart);
}
