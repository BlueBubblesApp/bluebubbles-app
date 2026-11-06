import 'package:flutter/foundation.dart';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// A validated `message-deleted` / `message-restored` event.
class RecoverableMessageEvent {
  const RecoverableMessageEvent({
    required this.chatGuid,
    required this.messageGuid,
    required this.deleted,
  });

  final String chatGuid;
  final String messageGuid;

  /// True for `message-deleted`, false for `message-restored`.
  final bool deleted;
}

/// Validates a live Recently Deleted event payload.
///
/// Returns null for anything malformed. Both GUIDs are required: acting on a
/// half-formed event would either hide the wrong message or hide nothing while
/// reporting success.
RecoverableMessageEvent? parseRecoverableMessageEvent(dynamic data, {required bool deleted}) {
  if (data is! Map) return null;

  final chatGuid = data['chatGuid'];
  final messageGuid = data['messageGuid'];
  if (chatGuid is! String || chatGuid.isEmpty) return null;
  if (messageGuid is! String || messageGuid.isEmpty) return null;

  return RecoverableMessageEvent(chatGuid: chatGuid, messageGuid: messageGuid, deleted: deleted);
}

/// What Apple reports right now, for a client that was offline when it changed.
class AppleStateSnapshot {
  const AppleStateSnapshot({this.readByChat = const {}, this.deletedMessages = const {}, this.deletedChats = const {}});

  /// Each chat's read state.
  final Map<String, bool> readByChat;

  /// Messages in Recently Deleted whose chat still has other messages.
  final Set<String> deletedMessages;

  /// Chats whose messages are all in Recently Deleted: the chat was deleted whole.
  final Set<String> deletedChats;
}

/// Parses the two catch-up responses. Malformed entries are skipped; a
/// response that is missing altogether contributes nothing.
AppleStateSnapshot parseAppleStateSnapshot({dynamic chatState, dynamic recentlyDeleted}) {
  final readByChat = <String, bool>{};
  final chats = chatState is Map ? chatState['chats'] : null;
  for (final chat in chats is List ? chats : const []) {
    if (chat is! Map) continue;
    final guid = chat['guid'];
    final read = chat['read'];
    if (guid is String && guid.isNotEmpty && read is bool) readByChat[guid] = read;
  }

  final deletedMessages = <String>{};
  final deletedChats = <String>{};
  final groups = recentlyDeleted is Map ? recentlyDeleted['chats'] : null;
  for (final group in groups is List ? groups : const []) {
    if (group is! Map) continue;
    final guid = group['guid'];
    final hasMessages = group['hasMessages'];
    final messages = group['deletedMessageGuids'];
    if (guid is! String || guid.isEmpty || hasMessages is! bool || messages is! List) continue;
    if (hasMessages) {
      deletedMessages.addAll(messages.whereType<String>().where((m) => m.isNotEmpty));
    } else {
      deletedChats.add(guid);
    }
  }

  return AppleStateSnapshot(readByChat: readByChat, deletedMessages: deletedMessages, deletedChats: deletedChats);
}

/// Brings the device in line with Apple after it was offline.
///
/// The live `chat-read-status-changed`, `message-deleted` and `chat-deleted`
/// events only reach a connected device. This fetches what Apple reports now
/// and applies it through the same paths the live events use. It only ever
/// hides and never restores: a hidden message may have been deleted by the
/// user on this device, and only the live `message-restored` event says Apple
/// put it back.
class AppleStateCatchUp {
  static Future<void> run() async {
    if (kIsWeb) return;
    try {
      final chatState = await HttpSvc.server.chatStateSnapshot();
      final recentlyDeleted = await HttpSvc.server.getRecoverableMessageSnapshot().then<dynamic>(
            (response) => response.data['data'],
            // Recently Deleted needs Ventura; older servers still catch up read state.
            onError: (_) => null,
          );
      await apply(parseAppleStateSnapshot(chatState: chatState.data['data'], recentlyDeleted: recentlyDeleted));
    } catch (error, trace) {
      // A correction pass, not a sync: an older server without the endpoint is normal.
      Logger.warn('Could not catch up with Apple', error: error, trace: trace, tag: 'AppleStateCatchUp');
    }
  }

  static Future<void> apply(AppleStateSnapshot snapshot) async {
    var changed = 0;
    for (final chat in ChatsSvc.allChats.toList()) {
      if (snapshot.deletedChats.contains(chat.guid)) {
        await ChatsSvc.softDeleteChat(chat);
        changed++;
        continue;
      }
      final read = snapshot.readByChat[chat.guid];
      if (read == null) continue;
      if ((chat.hasUnreadMessage ?? false) == read) {
        await ChatsSvc.setChatHasUnreadFromServer(chat, !read);
        changed++;
      } else if (read) {
        // Already read here, but a notification posted before the read arrived may still be up.
        await ChatInterface.clearNotificationForChat(chatId: chat.id!, chatGuid: chat.guid);
      }
    }

    for (final guid in snapshot.deletedMessages) {
      final message = Message.findOne(guid: guid);
      if (message == null || message.dateDeleted != null) continue;
      await RecoverableMessages.apply(guid, hide: true);
      changed++;
    }

    if (changed > 0) Logger.info('Caught up $changed change(s) from Apple', tag: 'AppleStateCatchUp');
  }
}

/// Applies an Apple-side single-message delete or restore to this device.
class RecoverableMessages {
  /// Prefers MessagesService so an OPEN conversation updates its message list
  /// and tile exactly as other live changes do. That service only exists while
  /// the chat's view is registered, so otherwise write the database and correct
  /// the chat tile directly: it renders from the stored latest-message pointer,
  /// not a live query.
  static Future<void> apply(String guid, {required bool hide}) async {
    if (kIsWeb) return;
    final message = Message.findOne(guid: guid);
    final chatGuid = message?.chat.target?.guid;

    final service = chatGuid == null ? null : maybeFindMessagesSvc(chatGuid);
    if (service != null) {
      if (hide) {
        await service.softDeleteMessage(message!);
      } else {
        await service.restoreMessage(message!);
      }
      return;
    }

    if (hide) {
      await Message.softDelete(guid);
    } else {
      await Message.restore(guid);
    }
    if (chatGuid == null) return;

    final chat = ChatsSvc.findChatByGuid(chatGuid);
    if (chat == null) return;
    final surviving = Chat.getMessages(chat, limit: 1);
    if (surviving.isEmpty) {
      ChatsSvc.clearChatLatestMessage(chatGuid);
    } else {
      ChatsSvc.updateChatLatestMessage(chatGuid, surviving.first, allowOlder: true);
    }
  }
}
