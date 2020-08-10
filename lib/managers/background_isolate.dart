import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
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

      // // If we don't have any chats, skip
      // if (data["chats"].length == 0) return new Future.value("");

      // // Find the chat by GUID
      // Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
      // if (chat == null) {
      //   ActionHandler.handleChat(chatData: data["chats"][0], isHeadless: true);
      // }

      // String title = await getFullChatTitle(chat);
      // Message message = Message.fromMap(data);

      // if (!message.isFromMe && !chat.isMuted) {
      //   debugPrint("creating notification");

      //   // createNewMessage(
      //   //   title,
      //   //   !isEmptyString(message.text)
      //   //       ? message.text
      //   //       : message.hasAttachments ? "Attachments" : "Something went wrong",
      //   //   chat.guid,
      //   //   Random().nextInt(9999),
      //   //   chat.id,
      //   //   _backgroundChannel,
      //   //   handle: message.handle,
      //   // );
      //   String text = message.text;
      //   if ((data['attachments'] as List<dynamic>).length > 0) {
      //     text = (data['attachments'] as List<dynamic>).length.toString() +
      //         " attachment" +
      //         ((data['attachments'] as List<dynamic>).length > 1 ? "s" : "");
      //   }
      //   createNewNotification(
      //       title,
      //       text,
      //       chat.guid,
      //       Random().nextInt(9998) + 1,
      //       chat.id,
      //       message.dateCreated.millisecondsSinceEpoch,
      //       getContactTitle(message.handle.id, message.handle.address),
      //       chat.participants.length > 1,
      //       handle: message.handle,
      //       contact: getContact(
      //         ContactManager().contacts,
      //         message.handle.address,
      //       ));
      // }

      ActionHandler.handleMessage(data, isHeadless: true);
    } else if (call.method == "updated-message") {
      ActionHandler.handleUpdatedMessage(jsonDecode(call.arguments));
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

// void createNewNotification(
//     String contentTitle,
//     String contentText,
//     String group,
//     int id,
//     int summaryId,
//     int timeStamp,
//     String senderName,
//     bool groupConversation,
//     {Handle handle,
//     Contact contact}) {
//   String address = handle.address;

//   Uint8List contactIcon;
//   if (contact != null) {
//     if (contact.avatar.length > 0) contactIcon = contact.avatar;
//   }
//   debugPrint("contactIcon " + contactIcon.toString());
//   MethodChannelInterface().platform.invokeMethod("new-message-notification", {
//     "CHANNEL_ID": "com.bluebubbles..new_messages",
//     "contentTitle": contentTitle,
//     "contentText": contentText,
//     "group": group,
//     "notificationId": id,
//     "summaryId": summaryId,
//     "address": address,
//     "timeStamp": timeStamp,
//     "name": senderName,
//     "groupConversation": groupConversation,
//     "contactIcon": contactIcon,
//   });
// }
