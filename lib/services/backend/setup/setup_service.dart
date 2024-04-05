import 'package:bluebubbles/helpers/network/network_tasks.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

SetupService setup = Get.isRegistered<SetupService>() ? Get.find<SetupService>() : Get.put(SetupService());

class SetupService extends GetxService {
  Future<void> startSetup(int numberOfMessagesPerPage, bool skipEmptyChats, bool saveToDownloads) async {
    sync.numberOfMessagesPerPage = numberOfMessagesPerPage;
    sync.skipEmptyChats = skipEmptyChats;
    sync.saveToDownloads = saveToDownloads;
    await sync.startFullSync();
    await finishSetup();
  }

  Future<void> finishSetup() async {
    ss.settings.finishedSetup.value = true;
    await ss.saveSettings();
    await NetworkTasks.onConnect();
  }
}