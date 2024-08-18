import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

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
    if (kIsDesktop && Platform.isWindows) {
      await WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
    }
    addToOutput('Full sync is starting...');
    addToOutput("Reloading your contacts...");
    await ss.getServerDetails(refresh: true);
    await cs.refreshContacts();

    addToOutput('Fetching chats from the server...');

    // Get the total chats so we can properly fetch them all
    Response chatCountResponse = await http.chatCount();
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
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
      }
      await for (final chatEvent in streamChatPages(totalChats)) {
        double chatProgress = chatEvent.item1;
        List<Chat> newChats = chatEvent.item2;

        addToOutput('Saving chunk of ${newChats.length} chat(s)...');

        // 1: Asynchronously save the chats
        // This returns the IDs, so we need to fetch them next
        List<Chat> chats = await Chat.bulkSyncChats(newChats);

        int deletedChats = 0;

        // 2: For each chat, get the messages.
        // We will stream the messages by page
        for (final chat in chats) {
          if (kIsWeb || (chat.chatIdentifier ?? "").startsWith("urn:biz")) continue;
          try {
            await for (final messageEvent in streamChatMessages(chat.guid, messageCount, batchSize: messageCount)) {
              List<Message> newMessages = messageEvent.item2;
              String? displayName = chat.guid;
              if (chat.displayName != null && chat.displayName!.isNotEmpty) {
                displayName = chat.displayName;
              } else if (displayName.contains(';-;')) {
                String addr = displayName.split(';-;')[1];
                Contact? contact = cs.getContact(addr);
                if (contact != null) {
                  displayName = contact.displayName;
                } else if (!addr.contains("@")) {
                  displayName = await formatPhoneNumber(addr);
                } else {
                  displayName = addr;
                }
              }

              if (chat.participants.isEmpty) {
                addToOutput('Deleting chat: $displayName (no participants were found)');
                Chat.softDelete(chat);
                deletedChats++;
                continue;
              }
              if (newMessages.isEmpty && skipEmptyChats) {
                addToOutput('Deleting chat: $displayName (skip empty chats was selected)');
                Chat.softDelete(chat);
                deletedChats++;
                continue;
              }

              addToOutput('Saving chunk of ${newMessages.length} message(s) for chat: $displayName');

              // Asyncronously save the messages
              List<Message> insertedMessages = await Message.bulkSaveNewMessages(chat, newMessages);
              messagesSynced += insertedMessages.length;

              // Increment how many chats we've synced, then set the progress
              completedChats += 1;
              setProgress(completedChats, (totalChats ?? newChats.length) - deletedChats);
              chatsSynced += 1;
              if (kIsDesktop && Platform.isWindows) {
                await WindowsTaskbar.setProgress(completedChats, (totalChats ?? newChats.length) - deletedChats);
              }
              // If we're supposed to be stopping, break out
              if (status.value == SyncStatus.STOPPING) break;
            }
          } catch (ex, stack) {
            addToOutput('Failed to sync chat messages! Error: ${ex.toString()}', level: LogLevel.ERROR);
            Logger.debug("StackTrace: $stack", tag: tag);
            Logger.debug('Error: ${ex.toString()}', tag: tag);
          }

          // If we're supposed to be stopping, break out
          if (status.value == SyncStatus.STOPPING) break;
        }

        if (chatProgress >= 1.0) {
          // When we've hit the last chunk, we're finished
          await complete();
          if (kIsDesktop && Platform.isWindows) {
            await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
            await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
          }
        } else if (status.value == SyncStatus.STOPPING) {
          // If we are supposed to be stopping, complete the future
          if (completer != null && !completer!.isCompleted) completer!.complete();
          if (kIsDesktop && Platform.isWindows) {
            await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
            await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
          }
        }
      }
    } catch (e, s) {
      addToOutput('Failed to sync chats! Error: ${e.toString()}', level: LogLevel.ERROR);
      addToOutput(s.toString(), level: LogLevel.ERROR);
      completeWithError(e.toString());
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.error);
        await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
      }
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
      Response chatPage = await http.chats(offset: i * countPerBatch, limit: countPerBatch, sort: kIsWeb ? "lastmessage" : null);
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
      Response messagePage = await http.chatMessages(chatGuid,
          after: 0, before: endTimestamp, offset: i * countPerBatch, limit: countPerBatch, withQuery: "attachments,message.attributedBody,message.messageSummaryInfo,message.payloadData");
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
    addToOutput("Reloading your contacts...");
    // Use reset because it's after the full-sync so all the
    // handles and contacts are assumed new.
    await cs.refreshContacts();
    addToOutput("Reloading your chats...");
    Get.reload<ChatsService>(force: true);
    await chats.init(force: true);
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
