import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/main.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/navigator_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/queue_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MethodChannelInterface {
  factory MethodChannelInterface() {
    return _interface;
  }

  static final MethodChannelInterface _interface =
      MethodChannelInterface._internal();

  MethodChannelInterface._internal();

  //interface with native code
  final platform = const MethodChannel('samples.flutter.dev/fcm');

  BuildContext _context;

  void init(BuildContext context) {
    platform.setMethodCallHandler(callHandler);
    _context = context;
  }

  Future invokeMethod(String method, [dynamic arguments]) async {
    return platform.invokeMethod(method, arguments);
  }

  Future<dynamic> callHandler(call) async {
    switch (call.method) {
      case "new-server":
        debugPrint("New Server: " + call.arguments.toString());
        debugPrint(call.arguments.toString().length.toString());
        SettingsManager().settings.serverAddress = call.arguments
            .toString()
            .substring(1, call.arguments.toString().length - 1);
        SettingsManager().saveSettings(SettingsManager().settings,
            connectToSocket: true, authorizeFCM: false);
        return new Future.value("");
      case "new-message":
        Map<String, dynamic> data = jsonDecode(call.arguments);

        // If we don't have any chats, skip
        if (data["chats"].length == 0) return new Future.value("");

        // Find the chat by GUID
        Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
        if (chat == null) {
          debugPrint("could not find chat, returning");
          return;
        }

        // Get the chat title and message
        String title = await getFullChatTitle(chat);
        Message message = Message.fromMap(data);

        // If we've already processed the GUID, skip it
        if (SocketManager().processedGUIDS.contains(data["guid"])) {
          return;
        }

        // Save the GUID and create a notification for the message
        SocketManager().processedGUIDS.add(data["guid"]);
        if (!message.isFromMe &&
            (NotificationManager().chat != chat.guid ||
                !LifeCycleManager().isAlive)) {
          NotificationManager().createNewNotification(title, message.text,
              chat.guid, Random().nextInt(999999), chat.id);
        }

        debugPrint("Adding new/matched message to the queue");
        QueueManager().addEvent(call.method, call.arguments);
        return new Future.value("");
      case "updated-message":
        debugPrint("Adding updated message to the queue");
        QueueManager().addEvent(call.method, call.arguments);
        return new Future.value("");
      case "ChatOpen":
        debugPrint("open chat " + call.arguments.toString());
        openChat(call.arguments);
        return new Future.value("");

      case "restart-fcm":
        debugPrint("restart fcm");
        return new Future.value("");
      case "reply":
        debugPrint("replying with data " + call.arguments.toString());
        Chat chat = await Chat.findOne({"guid": call.arguments["chat"]});
        SocketManager().sendMessage(chat, call.arguments["text"]);
        return new Future.value("");
      case "shareAttachments":
        List<File> attachments = <File>[];
        call.arguments.forEach((element) {
          attachments.add(File(element));
        });

        NavigatorManager().navigatorKey.currentState.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => NewChatCreator(
                attachments: attachments,
                isCreator: true,
              ),
            ),
            (route) => route.isFirst);
        return new Future.value("");

      case "shareText":
        String text = call.arguments;
        debugPrint("got text " + text);
        NavigatorManager().navigatorKey.currentState.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => NewChatCreator(
                existingText: text,
                isCreator: true,
              ),
            ),
            (route) => route.isFirst);
        return new Future.value("");
    }
  }

  void openChat(String id) async {
    Chat openedChat = await Chat.findOne({"GUID": id});
    if (openedChat != null) {
      String title = await getFullChatTitle(openedChat);

      Navigator.of(_context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ConversationView(
            chat: openedChat,
            messageBloc: ChatBloc().tileVals[openedChat.guid]["bloc"],
            title: title,
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      debugPrint("could not find chat");
    }
  }
}
