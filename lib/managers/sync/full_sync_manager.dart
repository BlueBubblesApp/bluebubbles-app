import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/sync/sync_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:dio/dio.dart';
import 'package:tuple/tuple.dart';

class FullSyncManager extends SyncManager {
  final tag = 'FullSyncManager';

  late int endTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch;

  int messageCount;

  int chatsSynced = 0;

  int messagesSynced = 0;

  bool skipEmptyChats;

  FullSyncManager({int? endTimestamp, this.messageCount = 25, this.skipEmptyChats = true, bool saveLogs = false})
      : super("Full", saveLogs: saveLogs);

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    super.start();
    addToOutput('Full sync is starting...');
    addToOutput("Reloading your contacts...");
    await ContactManager().loadContacts(force: true, loadAvatars: true);

    addToOutput('Fetching chats from the server...');

    // Get the total chats so we can properly fetch them all
    Response chatCountResponse = await api.chatCount();
    Map<String, dynamic> res = chatCountResponse.data;
    int? totalChats;
    if (chatCountResponse.statusCode == 200) {
      totalChats = res["data"]["total"];
    }

    addToOutput('Received $totalChats chat(s) from the server!');

    if (totalChats == 0) {
      return await complete();
    }

    try {
      int completedChats = 0;
      await for (final chatEvent in streamChatPages(totalChats)) {
        double chatProgress = chatEvent.item1;
        List<Chat> newChats = chatEvent.item2;

        addToOutput('Saving chunk of ${newChats.length} chat(s)...');

        // 1: Asynchronously save the chats
        // This returns the IDs, so we need to fetch them next
        List<Chat> chats = await Chat.bulkSyncChats(newChats);

        // 2: For each chat, get the messages.
        // We will stream the messages by page
        for (final chat in chats) {
          if ((chat.chatIdentifier ?? "").startsWith("urn:biz")) continue;
          try {
            await for (final messageEvent in streamChatMessages(chat.guid, messageCount, batchSize: messageCount)) {
              List<Message> newMessages = messageEvent.item2;
              String? displayName = chat.guid;
              if (chat.displayName != null && chat.displayName!.isNotEmpty) {
                displayName = chat.displayName;
              } else if (displayName.contains(';-;')) {
                String addr = displayName.split(';-;')[1];
                Contact? contact = ContactManager().getContact(addr);
                if (contact != null) {
                  displayName = contact.displayName;
                } else {
                  displayName = await ContactManager().getFormattedAddress(addr);
                }
              }

              if (newMessages.isEmpty && skipEmptyChats) {
                addToOutput('Deleting chat: $displayName (skip empty chats was selected)');
                Chat.deleteChat(chat);
                continue;
              }

              addToOutput('Saving chunk of ${newMessages.length} message(s) for chat: $displayName');

              // Asyncronously save the messages
              List<Message> insertedMessages = await Message.bulkSaveNewMessages(chat, newMessages);
              messagesSynced += insertedMessages.length;

              // Increment how many chats we've synced, then set the progress
              completedChats += 1;
              setProgress(completedChats, totalChats ?? newChats.length);
              chatsSynced += 1;

              // If we're supposed to be stopping, break out
              if (status.value == SyncStatus.STOPPING) break;
            }
          } catch (ex) {
            addToOutput('Failed to sync chat messages! Error: ${ex.toString()}', level: LogLevel.ERROR);
            Logger.warn('Failed to sync messages for chat: ${chat.guid}!', tag: tag);
            Logger.debug('Error: ${ex.toString()}', tag: tag);
          }

          // If we're supposed to be stopping, break out
          if (status.value == SyncStatus.STOPPING) break;
        }

        if (chatProgress >= 1.0) {
          // When we've hit the last chunk, we're finished
          await complete();
        } else if (status.value == SyncStatus.STOPPING) {
          // If we are supposed to be stopping, complete the future
          if (completer != null && !completer!.isCompleted) completer!.complete();
        }
      }
    } catch (e) {
      addToOutput('Failed to sync chats! Error: ${e.toString()}', level: LogLevel.ERROR);
      completeWithError(e.toString());
    }

    return completer!.future;
  }

  Stream<Tuple2<double, List<Chat>>> streamChatPages(int? count, {int batchSize = 200}) async* {
    // Set some default sync values
    int batches = 1;
    int countPerBatch = batchSize;

    if (count != null) {
      batches = (count / countPerBatch).ceil();
    } else {
      // If we weren't given a total, just use 1000 with 1 batch
      countPerBatch = 1000;
    }

    for (int i = 0; i < batches; i++) {
      // Fetch the chats and throw an error if we don't get back a good response.
      // Throwing an error should cancel the sync
      Response chatPage = await api.chats(offset: i * countPerBatch, limit: countPerBatch);
      dynamic data = chatPage.data;
      if (chatPage.statusCode != 200) {
        throw ChatRequestException(
            '${data["error"]?["type"] ?? "API_ERROR"}: data["message"] ?? data["error"]["message"]}');
      }

      // Convert the returned chat dictionaries to a list of Chat Objects
      List<dynamic> chatResponse = data["data"];
      List<Chat> chats = chatResponse.map((e) => Chat.fromMap(e)).toList();
      yield Tuple2<double, List<Chat>>((i + 1) / batches, chats);
    }
  }

  Stream<Tuple2<double, List<Message>>> streamChatMessages(String chatGuid, int? count, {int batchSize = 25}) async* {
    // Set some default sync values
    int batches = 1;
    int countPerBatch = batchSize;

    if (count != null) {
      batches = (count / countPerBatch).ceil();
    } else {
      // If we weren't given a total, just use 1000 with 1 batch
      countPerBatch = 1000;
    }

    for (int i = 0; i < batches; i++) {
      // Fetch the messages and throw an error if we don't get back a good response.
      // Throwing an error should _not_ cancel the sync
      Response messagePage = await api.chatMessages(chatGuid,
          after: 0, before: endTimestamp, offset: i * countPerBatch, limit: countPerBatch, withQuery: "attachments,attributedBody");
      dynamic data = messagePage.data;
      if (messagePage.statusCode != 200) {
        throw MessageRequestException(
            '${data["error"]?["type"] ?? "API_ERROR"}: data["message"] ?? data["error"]["message"]}');
      }

      // Convert the returned chat dictionaries to a list of Chat Objects
      List<dynamic> messageResponse = data["data"];
      List<Message> messages = messageResponse.map((e) => Message.fromMap(e)).toList();
      yield Tuple2<double, List<Message>>((i + 1) / batches, messages);
    }
  }

  @override
  Future<void> complete() async {
    addToOutput("Reloading your chats...");
    await ChatBloc().refreshChats(force: true);
    await super.complete();
  }
}

class ChatRequestException implements Exception {
  const ChatRequestException([this.message]);

  final String? message;

  @override
  String toString() {
    String result = 'ChatRequestException';
    if (message is String) return '$result: $message';
    return result;
  }
}

class MessageRequestException implements Exception {
  const MessageRequestException([this.message]);

  final String? message;

  @override
  String toString() {
    String result = 'MessageRequestException';
    if (message is String) return '$result: $message';
    return result;
  }
}
