import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class BackgroundIsolateInterface {
  static void initialize() {
    CallbackHandle callbackHandle =
        PluginUtilities.getCallbackHandle(callbackHandler);
    MethodChannelInterface().invokeMethod("initialize-background-handle",
        {"handle": callbackHandle.toRawHandle()});
  }
}

callbackHandler() async {
  debugPrint("callback");
  MethodChannel _backgroundChannel = MethodChannel("background_isolate");
  WidgetsFlutterBinding.ensureInitialized();
  await DBProvider.db.initDB();
  await ContactManager().getContacts(headless: true);
  SettingsManager().init();
  MethodChannelInterface().init(null, channel: _backgroundChannel);
  // LifeCycleManager().opened();
  LifeCycleManager().close();
  // SocketManager().connectCb = () {
  //   debugPrint("connectCb");
  //   resyncChats(_backgroundChannel);
  // };
  await SettingsManager().getSavedSettings(headless: true);
  SocketManager().authFCM();
  SocketManager().startSocketIO();
  _backgroundChannel.setMethodCallHandler((call) async {
    debugPrint("call " + call.method);
    if (call.method == "new-message") {
      Map<String, dynamic> data = jsonDecode(call.arguments);

      IncomingQueue().add(new QueueItem(
          event: "handle-message", item: {"data": data, "isHeadless": true}));
    } else if (call.method == "updated-message") {
      IncomingQueue().add(new QueueItem(
          event: "handle-updated-message",
          item: {"data": jsonDecode(call.arguments)}));
    } else if (call.method == "reply") {
      debugPrint("replying with data " + call.arguments.toString());
      Chat chat = await Chat.findOne({"guid": call.arguments["chat"]});
      // SocketManager().startSocketIO(connectCB: () {
      //   debugPrint("replying with data " + call.arguments.toString());
      // });
      ActionHandler.sendMessage(chat, call.arguments["text"]);
    } else if (call.method == "markAsRead") {
      Chat chat = await Chat.findOne({"guid": call.arguments["chat"]});
      SocketManager().removeChatNotification(chat);
    }
  });
  fcmAuth(_backgroundChannel);
}

void fcmAuth(MethodChannel channel) async {
  debugPrint("authenticating auth fcm with data " +
      SettingsManager().settings.fcmAuthData.toString());
  try {
    String result = await channel.invokeMethod(
        "auth", SettingsManager().settings.fcmAuthData);
    SocketManager().token = result;
  } on PlatformException catch (e) {
    if (e.code != "failed") {
      debugPrint("error authorizing firebase: " + e.code);
      await Future.delayed(Duration(seconds: 10));
      fcmAuth(channel);
    } else {
      debugPrint("some weird ass error " + e.details);
    }
  }
}
