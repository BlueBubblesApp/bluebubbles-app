
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/firebase/fcm_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (SettingsManager().settings.finishedSetup.value) {
      fcm.registerDevice();
      sync.startIncrementalSync();
      SettingsManager().getMacOSVersion(refresh: true);

      if ((kIsDesktop || kIsWeb) && ContactManager().contacts.isEmpty) {
        await ContactManager().loadContacts();
      }
      if (kIsWeb && ChatBloc().chats.isEmpty) {
        await ChatBloc().refreshChats(force: true);
      }
    }
  }
}