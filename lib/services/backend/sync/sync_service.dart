import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

SyncService sync = Get.isRegistered<SyncService>() ? Get.find<SyncService>() : Get.put(SyncService());

class SyncService extends GetxService {
  int numberOfMessagesPerPage = 25;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;
  final RxBool isIncrementalSyncing = false.obs;

  FullSyncManager? _manager;
  FullSyncManager? get fullSyncManager => _manager;

  Future<void> startFullSync() async {
    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    settings.settings.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await settings.saveSettings();

    _manager = FullSyncManager(
        messageCount: numberOfMessagesPerPage.toInt(),
        skipEmptyChats: skipEmptyChats,
        saveLogs: saveToDownloads
    );
    await _manager!.start();
  }

  Future<void> startIncrementalSync() async {
    isIncrementalSyncing.value = true;
    try {
      int syncStart = settings.settings.lastIncrementalSync.value;
      final incrementalSyncManager = IncrementalSyncManager(syncStart, onComplete: () async {
        await cs.refreshContacts();
        isIncrementalSyncing.value = false;
      });
      await incrementalSyncManager.start();
    } catch (ex) {
      isIncrementalSyncing.value = false;
      Logger.error('Incremental sync failed! Error: $ex');
    }
  }
}