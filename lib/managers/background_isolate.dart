import 'dart:ui';

import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/join_tables.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/scheduled.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BackgroundIsolateInterface {
  static void initialize() {
    CallbackHandle callbackHandle =
        PluginUtilities.getCallbackHandle(callbackHandler)!;
    MethodChannelInterface().invokeMethod("initialize-background-handle",
        {"handle": callbackHandle.toRawHandle()});
  }
}

callbackHandler() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  MethodChannel _backgroundChannel = MethodChannel("com.bluebubbles.messaging");
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    store = await openStore();
    attachmentBox = store.box<Attachment>();
    chatBox = store.box<Chat>();
    fcmDataBox = store.box<FCMData>();
    handleBox = store.box<Handle>();
    messageBox = store.box<Message>();
    scheduledBox = store.box<ScheduledMessage>();
    themeEntryBox = store.box<ThemeEntry>();
    themeObjectBox = store.box<ThemeObject>();
    amJoinBox = store.box<AttachmentMessageJoin>();
    chJoinBox = store.box<ChatHandleJoin>();
    cmJoinBox = store.box<ChatMessageJoin>();
    tvJoinBox = store.box<ThemeValueJoin>();
  }
  await SettingsManager().init();
  await SettingsManager().getSavedSettings(headless: true);
  await ContactManager().getContacts(headless: true);
  MethodChannelInterface().init(customChannel: _backgroundChannel);
  await SocketManager().refreshConnection(connectToSocket: false);
}
