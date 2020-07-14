import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
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
  LifeCycleManager().opened();
  // SocketManager().connectCb = () {
  //   debugPrint("connectCb");
  //   resyncChats(_backgroundChannel);
  // };
  await SettingsManager().getSavedSettings(headless: true);
  SocketManager().authFCM();
  resyncChats(_backgroundChannel);
  // SocketManager().startSocketIO();
  _backgroundChannel.setMethodCallHandler((call) async {
    debugPrint("call " + call.method);
    if (call.method == "new-message") {
      Map<String, dynamic> data = jsonDecode(call.arguments);

      // If we don't have any chats, skip
      if (data["chats"].length == 0) return new Future.value("");

      // Find the chat by GUID
      Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
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

void resyncChats(MethodChannel channel) async {
  debugPrint("starting resync");
  SocketManager().sendMessage("get-chats", {}, (data) {
    receivedChats(data, () {
      // SocketManager().closeSocket();
      debugPrint("finished getting chats");
      LifeCycleManager().close();
    }, channel);
  });
  // List<Chat> chats = await ChatBloc().getChats();
}

void receivedChats(data, Function completeCB, MethodChannel channel) async {
  debugPrint("got chats");
  List chats = data["data"];
  getChatMessagesRecursive(chats, 0, completeCB, channel);
}

void getChatMessagesRecursive(
    List chats, int index, Function completeCB, MethodChannel channel) async {
  Chat chat = Chat.fromMap(chats[index]);
  await chat.save();
  List<Message> messages = await Chat.getMessages(chat, limit: 1, offset: 0);

  Map<String, dynamic> params = Map();
  params["identifier"] = chat.guid;
  params["withBlurhash"] = true;
  params["where"] = [
    {"statement": "message.service = 'iMessage'", "args": null}
  ];
  if (messages.length != 0) {
    params["after"] = messages.first.dateCreated.millisecondsSinceEpoch + 10;
    params["limit"] = 500;
    debugPrint("after is " + params["after"].toString());
  } else {
    params["limit"] = 25;
  }
  SocketManager().sendMessage("get-chat-messages", params, (data) {
    receivedMessagesForChat(chat, data, channel);
    if (index + 1 < chats.length) {
      getChatMessagesRecursive(chats, index + 1, completeCB, channel);
    } else {
      completeCB();
    }
  });
}

void receivedMessagesForChat(
    Chat chat, Map<String, dynamic> data, MethodChannel channel) async {
  List messages = data["data"];

  MessageHelper.bulkAddMessages(chat, messages);
  // for (var _message in messages) {
  //   Message message = Message.fromMap(_message);
  //   String title = await getFullChatTitle(chat);

  //   if (!message.isFromMe && !chat.isMuted) {
  //     createNewMessage(
  //       title,
  //       !isEmptyString(message.text)
  //           ? message.text
  //           : message.hasAttachments ? "Attachments" : "Something went wrong",
  //       chat.guid,
  //       Random().nextInt(9999),
  //       chat.id,
  //       channel,
  //       handle: message.handle,
  //     );
  //   }
  // }
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
  // debugPrint("person " + address);
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
