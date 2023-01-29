import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/sync/sync_manager_impl.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class HandleSyncManager extends SyncManager {
  final tag = 'HandleSyncManager';

  int handlesSynced = 0;

  HandleSyncManager({bool saveLogs = false})
      : super("Handle", saveLogs: saveLogs);

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
    addToOutput('Handle sync is starting...');
    addToOutput('Fetching handles from the server...');

    // Get the total handles so we can properly fetch them all
    Response handleCountResponse = await http.handleCount();
    Map<String, dynamic> res = handleCountResponse.data;
    int? totalHandles;
    if (handleCountResponse.statusCode == 200) {
      totalHandles = res["data"]["total"];
    }

    addToOutput('Received $totalHandles handles(s) from the server!');

    if (totalHandles == 0) {
      return await complete();
    }

    addToOutput("Backing up handles...");
    List<Handle> currentHandles = Handle.find();
    final handleBackup = currentHandles.map((e) => e.toMap()).toList();

    try {
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
      }

      // First, get all the chats and cache all the handle original ROWIDs associated
      addToOutput("Loading chats...");
      final chatQuery = chatBox.query().build();
      List<Chat> chats = chatQuery.find();
      addToOutput("Loaded ${chats.length} from the database...");

      addToOutput("Caching chat participants...");
      Map<Chat, List<int>> chatHandleCache = {};
      for (Chat c in chats) {
        List<Handle> handles = c.participants;
        List<int> rowIds = handles.map((e) => e.originalROWID).whereNotNull().toList();
        chatHandleCache[c] = rowIds;
      }

      // Clearing handle database
      addToOutput("Clearing handle database...");
      handleBox.removeAll();

      addToOutput("Streaming handles from server...");
      Map<int, Handle> newHandlesMap = {};
      await for (final handleEvent in streamHandlePages(totalHandles)) {
        double handleProgress = handleEvent.item1;
        List<Handle> newHandles = handleEvent.item2;

        addToOutput('Saving chunk of ${newHandles.length} handles(s)...');

        // Generate the formatted address for each
        for (Handle h in newHandles) {
          if (!h.address.contains("@") && h.formattedAddress == null) {
            h.formattedAddress = await formatPhoneNumber(h.address);
          }

          h.contactRelation.target ??= cs.matchHandleToContact(h);
        }

        // Synchronously save the handles
        List<Handle> handles = Handle.bulkSave(newHandles, matchOnOriginalROWID: true);
        handlesSynced += handles.length;

        for (Handle h in handles) {
          if (h.originalROWID != null) {
            newHandlesMap[h.originalROWID!] = h;
          }
        }

        if (handleProgress >= 1.0) {
          // When we've finished, apply the handles to the chats
          addToOutput("Re-creating chat <-> handle relationships");
          chatHandleCache.forEach((key, value) {
            List<Handle> relations = value.map((e) => newHandlesMap[e]).whereNotNull().toList();
            key.handles.addAll(relations);
            key.handles.applyToDb();
          });

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
      addToOutput('Failed to sync handles! Error: ${e.toString()}', level: LogLevel.ERROR);
      addToOutput(s.toString(), level: LogLevel.ERROR);

      addToOutput('Restoring original handles...');
      List<Handle> originalHandles = handleBackup.map((e) => Handle.fromMap(e)).toList();
      Handle.bulkSave(originalHandles);

      completeWithError(e.toString());
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.error);
        await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
      }
    }

    return completer!.future;
  }

  Stream<Tuple2<double, List<Handle>>> streamHandlePages(int? count, {int batchSize = 200}) async* {
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
      Response handlePage = await http.handles(offset: i * countPerBatch, limit: countPerBatch);
      dynamic data = handlePage.data;
      if (handlePage.statusCode != 200) {
        throw HandleRequestException(
            '${data["error"]?["type"] ?? "API_ERROR"}: data["message"] ?? data["error"]["message"]}');
      }

      // Convert the returned handle dictionaries to a list of Handle Objects
      List<dynamic> handleResponse = data["data"];
      List<Handle> handles = handleResponse.map((e) => Handle.fromMap(e)).toList();
      yield Tuple2<double, List<Handle>>((i + 1) / batches, handles);
    }
  }

  @override
  Future<void> complete() async {
    addToOutput("Synced $handlesSynced handle(s)!");
    addToOutput("Reloading your chats...");
    Get.reload<ChatsService>(force: true);
    await chats.init(force: true);
    await super.complete();
  }
}

class HandleRequestException implements Exception {
  const HandleRequestException([this.message]);

  final String? message;

  @override
  String toString() {
    String result = 'HandleRequestException';
    if (message is String) return '$result: $message';
    return result;
  }
}
