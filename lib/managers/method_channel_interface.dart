import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/navigator_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class MethodChannelInterface {
  factory MethodChannelInterface() {
    return _interface;
  }

  static final MethodChannelInterface _interface =
      MethodChannelInterface._internal();

  MethodChannelInterface._internal();

  //interface with native code
  MethodChannel platform;

  BuildContext _context;

  void init(BuildContext context, {MethodChannel channel}) {
    //this happens if it is a headless thread
    if (channel != null) {
      platform = channel;
    } else {
      platform = MethodChannel('samples.flutter.dev/fcm');
      platform.setMethodCallHandler(callHandler);
      _context = context;
    }
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
        await SettingsManager().saveSettings(SettingsManager().settings,
            connectToSocket: false, authorizeFCM: false);
        SocketManager().startSocketIO(forceNewConnection: true);
        return new Future.value("");
      case "new-message":
        Map<String, dynamic> data = jsonDecode(call.arguments);

        // If we don't have any chats, skip
        if (data["chats"].length == 0) return new Future.value("");

        // Find the chat by GUID
        Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
        if (chat == null) {
          ActionHandler.handleChat(chatData: data["chats"][0]);
        } else {
          await chat.getParticipants();
        }

        // Get the chat title and message
        String title = await getFullChatTitle(chat);
        Message message = Message.fromMap(data);

        if (!message.isFromMe &&
            (NotificationManager().chatGuid != chat.guid ||
                !LifeCycleManager().isAlive) &&
            (!message.hasAttachments || !isEmptyString(message.text)) &&
            !chat.isMuted &&
            !NotificationManager()
                .processedNotifications
                .contains(message.guid)) {
          NotificationManager().createNewNotification(
            title,
            message.text,
            chat.guid,
            Random().nextInt(9998) + 1,
            chat.id,
            message.dateCreated.millisecondsSinceEpoch,
            getContactTitle(message.handle.id, message.handle.address),
            chat.participants.length > 1,
            handle: message.handle,
          );
          NotificationManager().processedNotifications.add(message.guid);
        }

        ActionHandler.handleMessage(data,
            createAttachmentNotification: !chat.isMuted);
        return new Future.value("");
      case "updated-message":
        ActionHandler.handleUpdatedMessage(jsonDecode(call.arguments));
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
        ActionHandler.sendMessage(chat, call.arguments["text"]);
        return new Future.value("");
      case "markAsRead":
        Chat chat = await Chat.findOne({"guid": call.arguments["chat"]});
        SocketManager().removeChatNotification(chat);
        return new Future.value("");
      case "shareAttachments":
        List<File> attachments = <File>[];
        call.arguments.forEach((element) {
          attachments.add(File(element));
        });
        if (!await Permission.storage.request().isGranted) return;

        NavigatorManager().navigatorKey.currentState.pushAndRemoveUntil(
            CupertinoPageRoute(
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
            CupertinoPageRoute(
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
    if (_context == null) return;
    Chat openedChat = await Chat.findOne({"GUID": id});
    if (openedChat != null) {
      await openedChat.getParticipants();
      String title = await getFullChatTitle(openedChat);
      MessageBloc messageBloc = new MessageBloc(openedChat);
      NotificationManager().switchChat(openedChat);

      Navigator.of(_context).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (context) => ConversationView(
            chat: openedChat,
            messageBloc: messageBloc,
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
