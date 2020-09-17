import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/navigator_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
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
      // platform.setMethodCallHandler(callHandler);
    } else {
      platform = MethodChannel('com.bluebubbles.messaging');
      _context = context;
    }

    platform.setMethodCallHandler(callHandler);
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
        IncomingQueue()
            .add(new QueueItem(event: "handle-message", item: {"data": data}));
        return new Future.value("");
      case "updated-message":
        IncomingQueue().add(new QueueItem(
            event: "handle-updated-message",
            item: {"data": jsonDecode(call.arguments)}));
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
        debugPrint("Received shared attachments: " +
            call.arguments.runtimeType.toString());
        List<File> attachments = <File>[];
        String appDocPath = SettingsManager().appDocDir.path;
        call.arguments.forEach((key, element) {
          debugPrint("attachment " + key.runtimeType.toString());
          Directory("$appDocPath/sharedFiles").createSync();
          String pathName = "$appDocPath/sharedFiles/$key";
          debugPrint("HERE! $pathName");
          File file = File(pathName);
          file.writeAsBytesSync(element.toList());
          attachments.add(file);
        });
        if (!await Permission.storage.request().isGranted) return;

        NavigatorManager().navigatorKey.currentState.pushAndRemoveUntil(
              CupertinoPageRoute(
                builder: (context) => NewChatCreator(
                  attachments: attachments,
                  isCreator: true,
                ),
              ),
              (route) => route.isFirst,
            );
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
              (route) => route.isFirst,
            );
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
      Future.delayed(Duration(milliseconds: 500), () {
        NotificationManager().switchChat(openedChat);
      });
    } else {
      debugPrint("could not find chat");
    }
  }
}
