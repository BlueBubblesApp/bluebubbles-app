import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class BackgroundIsolateInterface {
  static Future<void> initialize() {
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
  await SettingsManager().getSavedSettings(startSocketIO: false);
  _backgroundChannel.setMethodCallHandler((call) async {
    debugPrint("call " + call.method);
    if (call.method == "new-message") {
      Map<String, dynamic> data = jsonDecode(call.arguments);

      // If we don't have any chats, skip
      if (data["chats"].length == 0) return new Future.value("");

      // Find the chat by GUID
      Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
      debugPrint("found chat for new message " + chat.toMap().toString());
      if (chat == null) {
        ActionHandler.handleChat(chatData: data["chats"][0], isHeadless: true);
      }

      String title = await getFullChatTitle(chat);
      Message message = Message.fromMap(data);

      if (!message.isFromMe &&
          !chat.isMuted &&
          ((isEmptyString(message.text) && !message.hasAttachments) ||
              !isEmptyString(message.text))) {
        debugPrint("creating notification");
        createNewMessage(
          title,
          !isEmptyString(message.text)
              ? message.text
              : message.hasAttachments ? "Attachments" : "Something went wrong",
          chat.guid,
          Random().nextInt(9999),
          chat.id,
          _backgroundChannel,
          handle: message.handle,
        );
      }

      ActionHandler.handleMessage(data,
          createAttachmentNotification: !chat.isMuted, isHeadless: true);
    } else if (call.method == "updated-message") {
      ActionHandler.handleUpdatedMessage(jsonDecode(call.arguments));
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

createNewMessage(String contentTitle, String contentText, String group, int id,
    int summaryId, MethodChannel channel,
    {Handle handle}) {
  String address;

  if (handle != null) {
    //if the address is an email
    if (handle.address.contains("@")) {
      address = "mailto:${handle.address}";
      //if the address is a phone
    } else {
      address = "tel:${handle.address}";
    }
  }
  debugPrint("person " + address);
  channel.invokeMethod("new-message-notification", {
    "CHANNEL_ID": "com.bluebubbles.new_messages",
    "contentTitle": contentTitle,
    "contentText": contentText,
    "group": group,
    "notificationId": id,
    "summaryId": summaryId,
    "address": address,
  });
}
