import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (ss.settings.finishedSetup.value) {
      await fcm.registerDevice();
      await sync.startIncrementalSync();
      await ss.getServerDetails(refresh: true);
      ss.checkServerUpdate(context: Get.context!);

      if (kIsWeb && chats.chats.isEmpty) {
        await chats.init();
      }
      if (kIsWeb && cs.contacts.isEmpty) {
        await cs.refreshContacts();
      }
    }
  }
}