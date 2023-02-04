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

  Map<Chat, List<int>> chatHandleCache = {};

  Map<int, Handle> handleBackup = {};

  Map<int, Handle> newHandles = {};

  bool simulateError;

  HandleSyncManager({bool saveLogs = false, this.simulateError = false}) : super("Handle", saveLogs: saveLogs);

  flush() {
    chatHandleCache = {};
    handlesSynced = 0;
    handleBackup = {};
    newHandles = {};
  }

  @override
  Future<void> start() async {
    if (completer != null && !completer!.isCompleted) {
      return completer!.future;
    } else {
      completer = Completer<void>();
    }

    // Check if the user is on v1.5.2 or newer
    int serverVersion = (await ss.getServerDetails()).item4;
    // 100(major) + 21(minor) + 1(bug)
    bool isMin1_5_2 = serverVersion >= 207; // Server: v1.5.2
    if (!isMin1_5_2) {
      throw Exception("Please update your server to v1.5.2 or newer!");
    }

    super.start();
    if (kIsDesktop && Platform.isWindows) {
      await WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
    }

    flush();
    addToOutput('Fetching handles from the server...');

    int? totalHandles = await getHandleCount();
    if (totalHandles == null) {
      throw Exception("Unable to get handle count from server!");
    } else {
      addToOutput('Received $totalHandles handles(s) from the server!');
    }

    if (totalHandles == 0) {
      return await complete();
    }

    try {
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
      }

      // First, backup the handles so we can restore them if required later.
      backupHandles();

      // Second, fetch all the chats and cache the chat <-> handle relationships.
      // This is so we can re-apply them later during the resync or a restore.
      List<Chat> chats = await getChatsFromDb();
      cacheChatHandleRelationships(chats);

      // Clearing handle database
      addToOutput("Clearing handle database...");
      handleBox.removeAll();

      // This flag can be used to test the restore functionality
      if (simulateError) {
        throw Exception('Simulated Error!');
      }

      addToOutput("Streaming handles from server...");
      bool hasContactAccess = await cs.hasContactAccess;
      await for (final handleEvent in streamHandlePages(totalHandles)) {
        double handleProgress = handleEvent.item1;
        List<Handle> serverHandles = handleEvent.item2;

        addToOutput('Saving chunk of ${serverHandles.length} handles(s)...');

        // Generate the formatted address for each.
        // And load the matching contact, if we can.
        for (Handle h in serverHandles) {
          // restore preferences from backed up handle
          final backedUpHandle = handleBackup[h.originalROWID!];
          h.color = backedUpHandle?.color;
          h.defaultEmail = backedUpHandle?.defaultEmail;
          h.defaultPhone = backedUpHandle?.defaultPhone;
          if (!h.address.contains("@") && h.formattedAddress == null) {
            h.formattedAddress = await formatPhoneNumber(h.address);
          }

          if (hasContactAccess) {
            h.contactRelation.target ??= cs.matchHandleToContact(h);
          }
        }

        // Save the new handles to the DB
        List<Handle> handles = Handle.bulkSave(serverHandles, matchOnOriginalROWID: true);
        handlesSynced += handles.length;

        // Save the new handles to a cache
        for (Handle h in handles) {
          if (h.originalROWID != null) {
            newHandles[h.originalROWID!] = h;
          }
        }

        if (handleProgress >= 1.0) {
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
            restoreOriginalHandles();
            completer!.complete();
          }

          if (kIsDesktop && Platform.isWindows) {
            await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
            await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
          }
        }
      }
    } catch (e, s) {
      addToOutput('Failed to sync handles! Error: ${e.toString()}', level: LogLevel.ERROR);
      addToOutput(s.toString(), level: LogLevel.ERROR);
      completeWithError(e.toString());
      if (kIsDesktop && Platform.isWindows) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.error);
        await WindowsTaskbar.setFlashTaskbarAppIcon(mode: TaskbarFlashMode.timernofg);
      }
    }

    return completer!.future;
  }

  Future<int?> getHandleCount() async {
    Response handleCountResponse = await http.handleCount();
    Map<String, dynamic> res = handleCountResponse.data;
    if (handleCountResponse.statusCode == 200) {
      return res["data"]["total"];
    }

    return null;
  }

  backupHandles() {
    addToOutput("Backing up handles...");
    List<Handle> existingHandles = Handle.find();
    for (Handle h in existingHandles) {
      if (h.originalROWID != null) {
        handleBackup[h.originalROWID!] = Handle.fromMap(h.toMap());
      }
    }
  }

  Future<List<Chat>> getChatsFromDb() async {
    addToOutput("Loading chats from database...");
    final chatQuery = chatBox.query().build();
    List<Chat> chats = chatQuery.find();
    addToOutput("Loaded ${chats.length} from the database...");
    return chats;
  }

  cacheChatHandleRelationships(List<Chat> chats) {
    addToOutput("Caching chat participants...");
    for (Chat c in chats) {
      List<Handle> handles = c.participants;
      List<int> rowIds = handles.map((e) => e.originalROWID).whereNotNull().toList();
      chatHandleCache[c] = rowIds;
    }
  }

  restoreOriginalHandles() {
    // Don't try and restore if there is nothing backed up to re-create.
    // Or no relationships to recreate.
    if (handleBackup.isEmpty || chatHandleCache.isEmpty) return;

    addToOutput('Restoring original handles...');
    handleBox.removeAll();

    List<Handle> newHandles = Handle.bulkSave(handleBackup.values.toList());
    for (Handle h in newHandles) {
      if (h.originalROWID != null) {
        handleBackup[h.originalROWID!] = h;
      }
    }

    rebuildRelationships(handleBackup);
  }

  rebuildRelationships(Map<int, Handle> handleMap) {
    addToOutput("Re-creating chat <-> handle relationships");
    chatHandleCache.forEach((key, value) {
      List<Handle> relations = value.map((e) => handleMap[e]).whereNotNull().toList();
      key.handles.addAll(relations);
      key.handles.applyToDb();
    });
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
  completeWithError(String errorMessage) {
    restoreOriginalHandles();
    super.completeWithError(errorMessage);
  }

  @override
  Future<void> complete() async {
    rebuildRelationships(newHandles);
    addToOutput("Successfully synced $handlesSynced handle(s)!");
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
