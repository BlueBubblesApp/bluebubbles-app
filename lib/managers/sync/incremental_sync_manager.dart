import 'dart:math';

import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/sync/sync_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:dio/dio.dart';
import 'package:tuple/tuple.dart';

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

class IncrementalSyncManager extends SyncManager {
  int startTimestamp;

  int endTimestamp;

  IncrementalSyncManager(this.startTimestamp, this.endTimestamp) : super("Incremental");

  @override
  Future<void> start() async {
    super.start();

    // Get the total chats so we can properly fetch them all
    Response chatCountResponse = await api.chatCount();
    Map<String, dynamic> res = chatCountResponse.data;
    int? total;
    if (chatCountResponse.statusCode == 200) {
      total = res["total"];
    }

    try {
      await for (final event in streamChatPages(total)) {
        double progress = event.item1;
        List<Chat> chats = event.item2;

        // 1: Asynchronously save the chats

        // 2: Get messages for the chat from the API

        // 3: Asyncronously save the chat's messages

        if (progress >= 1) {
          // When we've hit the last chunk, we're finished
          complete();
        } else if (status.value == SyncStatus.STOPPING) {
          // If we are supposed to be stopping, complete the future
          completer!.complete();
        } else {
          // If all else passes, increment the progress to all listeners
          this.progress.value = progress;
        }
      }
    } catch (e) {
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
      Response chatPage = await api.chats(withQuery: ['participants'], offset: i * countPerBatch, limit: countPerBatch);
      dynamic data = chatPage.data;
      if (chatPage.statusCode != 200) {
        throw ChatRequestException('${data["error"]?["type"] ?? "API_ERROR"}: data["message"] ?? data["error"]}');
      }

      // Convert the returned chat dictionaries to a list of Chat Objects
      List<Map<String, dynamic>> chatResponse = data["data"];
      List<Chat> chats = chatResponse.map((e) => Chat.fromMap(e)).toList();
      yield Tuple2<double, List<Chat>>((i + 1) / batches, chats);
    }
  }
}
