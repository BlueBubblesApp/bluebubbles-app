import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class ChatSyncManager extends SyncManager {
  final tag = 'ChatSyncManager';

  int chatsSynced = 0;

  bool simulateError;

  ChatSyncManager({bool saveLogs = false, this.simulateError = false}) : super("Chat", saveLogs: saveLogs);

  flush() {
    chatsSynced = 0;
  }

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

    flush();
    addToOutput('Fetching chats from the server...');

    int? totalChats = await getChatCount();
    if (totalChats == null) {
      throw Exception("Unable to get chat count from server!");
    } else {
      addToOutput('Received $totalChats handles(s) from the server!');
    }

    if (totalChats == 0) {
      return await complete();
    }

    try {
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
      }

      // This flag can be used to test the restore functionality
      if (simulateError) {
        throw Exception('Simulated Error!');
      }

      addToOutput("Streaming chats from server...");
      await for (final chatEvent in streamChatPages(totalChats, batchSize: 100)) {
        double chatProgress = chatEvent.item1;
        List<Chat> serverChats = chatEvent.item2;

        addToOutput('Saving chunk of ${serverChats.length} chats(s)...');

        await Chat.bulkSyncChats(serverChats);
        chatsSynced += serverChats.length;
        
        addToOutput('Fetching group chat icons from the server...');
        for (Chat chat in serverChats) {
          if (!chat.isGroup) continue;

          try {
            await Chat.getIcon(chat, force: false);
          } catch (_) {
            // If we fail to get the icon, just continue
          }
        }

        if (chatProgress >= 1.0) {
          // When we've hit the last chunk, we're finished
          await complete();
          if (kIsDesktop && Platform.isWindows) {
            await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
            await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
          }
        } else if (status.value == SyncStatus.STOPPING) {
          // If we are supposed to be stopping, complete the future.
          // Also treat it as if there was an error and restore the original handles.
          // This is to prevent any incomplete work from being committed.
          if (completer != null && !completer!.isCompleted) {
            completer!.complete();
          }

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

  Future<int?> getChatCount() async {
    Response chatCountResponse = await http.chatCount();
    Map<String, dynamic> res = chatCountResponse.data;
    if (chatCountResponse.statusCode == 200) {
      return res["data"]["total"];
    }

    return null;
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
      // Fetch the handles and throw an error if we don't get back a good response.
      // Throwing an error should cancel the sync
      Response chatPage = await http.chats(
        offset: i * countPerBatch,
        limit: countPerBatch,
        withQuery: [
          "participants",
        ]
      );
      dynamic data = chatPage.data;
      if (chatPage.statusCode != 200) {
        throw ChatRequestException(
            '${data["error"]?["type"] ?? "API_ERROR"}: data["message"] ?? data["error"]["message"]}');
      }

      // Convert the returned handle dictionaries to a list of Handle Objects
      List<dynamic> chatResponse = data["data"];
      List<Chat> chats = chatResponse.map((e) => Chat.fromMap(e)).toList();
      yield Tuple2<double, List<Chat>>((i + 1) / batches, chats);
    }
  }

  @override
  Future<void> complete() async {
    addToOutput("Successfully synced $chatsSynced chats(s)!");
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
    String result = 'HandleRequestException';
    if (message is String) return '$result: $message';
    return result;
  }
}
