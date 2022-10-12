import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (settings.settings.finishedSetup.value) {
      await fcm.registerDevice();
      await sync.startIncrementalSync();
      await settings.getServerDetails(refresh: true);
      settings.checkServerUpdate(context: Get.context!);

      if ((kIsDesktop || kIsWeb) && ContactManager().contacts.isEmpty) {
        await ContactManager().loadContacts();
      }
      if (kIsWeb && ChatBloc().chats.isEmpty) {
        await ChatBloc().refreshChats(force: true);
      }
    }
  }
}