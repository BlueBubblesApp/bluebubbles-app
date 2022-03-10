import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/text_field_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/testing_mode.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/alarm_manager.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/navigator_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:universal_io/io.dart';

/// [MethodChannelInterface] is a manager used to talk to native code via a flutter MethodChannel
///
/// This class is a singleton
class MethodChannelInterface {
  factory MethodChannelInterface() {
    return _interface;
  }

  static final MethodChannelInterface _interface = MethodChannelInterface._internal();

  MethodChannelInterface._internal();

  /// [platform] is the actual channel which can be used to talk to native code
  late MethodChannel platform;

  /// [headless] identifies if this MethodChannelInterface is used when the app is fully closed, in hich case some actions cannot be done
  bool headless = false;

  bool isRunning = false;
  Color? previousPrimary;
  Color? previousLightBg;
  Color? previousDarkBg;

  /// Initialize all of the platform channels
  ///
  /// @param [customChannel] an optional custom platform channel to use by the methodchannelinterface
  void init({MethodChannel? customChannel}) {
    // If a [customChannel] is set, then we should use that
    if (customChannel != null) {
      headless = true;
      platform = customChannel;
      // Otherwise, we set the [platform] as the default
    } else {
      platform = MethodChannel('com.bluebubbles.messaging');
    }

    // We set the handler for all of the method calls from the platform to be the [callHandler]
    platform.setMethodCallHandler(_callHandler);
    if (!kIsWeb && !kIsDesktop) platform.invokeMethod<void>('MessagingBackground#initialized');
  }

  /// Helper method to invoke a method in the native code
  ///
  /// @param [method] is the tag to be recognized in native code
  /// @param [arguments] is an optional parameter which can be used to send other data along with the method call
  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    if (kIsWeb || kIsDesktop) return;
    return platform.invokeMethod(method, arguments);
  }

  /// The handler used to handle all methods sent from native code to the dart vm
  ///
  /// @param [call] is the actual [MethodCall] sent from native code. It has data such as the method name and the arguments.
  Future<dynamic> _callHandler(MethodCall call) async {
    // call.method is the name of the call from native code
    switch (call.method) {
      case "new-server":
        if (!SettingsManager().settings.finishedSetup.value) return Future.value("");

        // The arguments for a new server are formatted with the new server address inside square brackets
        // As such: [https://alksdjfoaehg.ngrok.io]
        String address = call.arguments.toString();

        // We remove the brackets from the formatting
        address = getServerAddress(address: address.substring(1, address.length - 1))!;

        // And then tell the socket to set the new server address
        await SocketManager().newServer(address);

        return Future.value("");
      case "new-message":
        Logger.info("Received new message from FCM");
        // Retreive the data for this message as a json
        Map<String, dynamic>? data = jsonDecode(call.arguments);

        // send data to the UI thread if it is active, otherwise handle in the isolate
        final SendPort? send = IsolateNameServer.lookupPortByName('bg_isolate');
        if (send != null) {
          Logger.info("Handling through SendPort");
          data!['action'] = 'new-message';
          send.send(data);
        } else {
          Logger.info("Handling through IncomingQueue");
          // Add it to the queue with the data as the item
          IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_MESSAGE_EVENT, item: {"data": data}));
        }

        return Future.value("");
      case "updated-message":
        // Retreive the data for this message as a json
        Map<String, dynamic>? data = jsonDecode(call.arguments);

        // send data to the UI thread if it is active, otherwise handle in the isolate
        final SendPort? send = IsolateNameServer.lookupPortByName('bg_isolate');
        if (send != null) {
          data!['action'] = 'new-message';
          send.send(data);
        } else {
          // Add it to the queue with the data as the item
          IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_UPDATE_MESSAGE, item: {"data": data}));
        }

        return Future.value("");
      case "ChatOpen":
        recentIntent = call.arguments["guid"];
        Logger.info("Opening Chat with GUID: ${call.arguments['guid']}, bubble: ${call.arguments['bubble']}");
        LifeCycleManager().isBubble = call.arguments['bubble'] == "true";
        await openChat(call.arguments['guid']);
        recentIntent = null;
        return Future.value("");
      case "socket-error-open":
        Get.toNamed("/settings/server-management-panel");
        return Future.value("");
      case "reply":
        if (call.arguments["chat"] == "google-play-test-chat") {
          TestingModeController controller = Get.find<TestingModeController>();
          controller.mostRecentReply.value = call.arguments["text"];
          // If `reply` is called when the app is in a background isolate, then we need to close it once we are done
          await closeThread();

          return Future.value("");
        }
        // Find the chat to reply to
        Chat? chat = Chat.findOne(guid: call.arguments["chat"]);

        // If no chat is found, then we can't do anything
        if (chat == null) {
          // If `reply` is called when the app is in a background isolate, then we need to close it once we are done
          await closeThread();

          return Future.value("");
        }

        Completer<void> completer = Completer();
        // Send the message to that chat
        await ActionHandler.sendMessage(chat, call.arguments["text"], completer: completer);

        await closeThread();

        return Future.value("");
      case "markAsRead":
        // Find the chat to mark as read
        Chat? chat = Chat.findOne(guid: call.arguments["chat"]);

        // If no chat is found, then we can't do anything
        if (chat == null) {
          // If `markAsRead` is called when the app is in a background isolate, then we need to close it once we are done
          await closeThread();

          return Future.value("");
        }

        // Remove the notificaiton from that chat
        SocketManager().removeChatNotification(chat);

        if (SettingsManager().settings.privateMarkChatAsRead.value && chat.autoSendReadReceipts!) {
          await SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat.guid}, (data) {});
        }

        // In case this method is called when the app is in a background isolate
        await closeThread();

        return Future.value("");
      case "shareAttachments":
        if (!SettingsManager().settings.finishedSetup.value) return Future.value("");
        recentIntent = call.arguments["id"];
        List<PlatformFile> attachments = [];

        // Loop through all of the attachments sent by native code
        call.arguments["attachments"].forEach((element) {
          // Get the file in that directory
          File file = File(element);

          // Add each file to the attachment list
          attachments.add(PlatformFile(
            name: file.path.split("/").last,
            path: file.path,
            bytes: file.readAsBytesSync(),
            size: file.lengthSync(),
          ));
        });

        // Get the handle if it is a direct shortcut
        String? guid = call.arguments["id"];

        // If it is a direct shortcut, try and find the chat and navigate to it
        if (guid != null) {
          List<Chat?> chats = ChatBloc().chats.where((element) => element.guid == guid).toList();

          // If we did find a chat matching the criteria
          if (chats.isNotEmpty) {
            // Get the most recent of our results
            chats.sort(Chat.sort);
            Chat chat = chats.first!;

            // Open the chat
            openChat(chat.guid, existingAttachments: attachments);

            // Nothing else to do
            return Future.value("");
          }
        }

        // Go to the new chat creator with all of these attachments to select a chat in case it wasn't a direct share
        CustomNavigator.pushAndRemoveUntil(
              Get.context!,
              ConversationView(
                existingAttachments: attachments,
                isCreator: true,
                // onTapGoToChat: true,
              ),
              (route) => route.isFirst,
            );
        recentIntent = null;
        return Future.value("");

      case "shareText":
        if (!SettingsManager().settings.finishedSetup.value) return Future.value("");
        recentIntent = call.arguments["id"];
        // Get the text that was shared to the app
        String? text = call.arguments["text"];

        // Get the handle if it is a direct shortcut
        String? guid = call.arguments["id"];

        // If it is a direct shortcut, try and find the chat and navigate to it
        if (guid != null) {
          List<Chat?> chats = ChatBloc().chats.where((element) => element.guid == guid).toList();

          // If we did find a chat matching the criteria
          if (chats.isNotEmpty) {
            // Get the most recent of our results
            chats.sort(Chat.sort);
            Chat chat = chats.first!;

            // Open the chat
            openChat(chat.guid, existingText: text);

            // Nothing else to do
            return Future.value("");
          }
        }
        // Navigate to the new chat creator with the specified text
        CustomNavigator.pushAndRemoveUntil(
              Get.context!,
              ConversationView(
                existingText: text,
                isCreator: true,
              ),
              (route) => route.isFirst,
            );
        recentIntent = null;
        return Future.value("");
      case "alarm-wake":
        AlarmManager().onReceiveAlarm(call.arguments["id"]);
        return Future.value("");
      case "media-colors":
        if (!SettingsManager().settings.colorsFromMedia.value) return Future.value("");
        final Color primary = Color(call.arguments['primary']);
        final Color lightBg = Color(call.arguments['lightBg']);
        final Color darkBg = Color(call.arguments['darkBg']);
        final double primaryPercent = call.arguments['primaryPercent'];
        final double lightBgPercent = call.arguments['lightBgPercent'];
        final double darkBgPercent = call.arguments['darkBgPercent'];
        if (Get.context != null &&
            (!isRunning || primary != previousPrimary || lightBg != previousLightBg || darkBg != previousDarkBg)) {
          previousPrimary = primary;
          previousLightBg = lightBg;
          previousDarkBg = darkBg;
          isRunning = true;
          print("primary color is $primary");
          print("light bg color is $lightBg");
          print("dark bg color is $darkBg");
          var darkTheme = ThemeObject.getThemes().firstWhere((e) => e.name == "Music Theme (Dark)");
          var lightTheme = ThemeObject.getThemes().firstWhere((e) => e.name == "Music Theme (Light)");
          darkTheme.fetchData();
          var darkPrimaryEntry = darkTheme.entries.firstWhere((element) => element.name == "PrimaryColor");
          var darkBgEntry = darkTheme.entries.firstWhere((element) => element.name == "BackgroundColor");
          darkPrimaryEntry.color = primary;
          darkBgEntry.color = darkBg;
          lightTheme.fetchData();
          var lightPrimaryEntry = lightTheme.entries.firstWhere((element) => element.name == "PrimaryColor");
          var lightBgEntry = lightTheme.entries.firstWhere((element) => element.name == "BackgroundColor");
          lightPrimaryEntry.color = primary;
          lightBgEntry.color = lightBg;
          if (ThemeObject.inDarkMode(Get.context!)) {
            if (primaryPercent != 0.5 && darkBgPercent != 0.5) {
              double difference = min((primaryPercent / (primaryPercent + darkBgPercent)), 1 - (primaryPercent / (primaryPercent + darkBgPercent)));
              Tween color1 = Tween<double>(begin: 0, end: difference);
              Tween color2 = Tween<double>(begin: 1 - difference, end: 1);
              ConversationViewMixin.gradientTween.value = MultiTween<String>()
                ..add("color1", color1)
                ..add("color2", color2);
            } else {
              ConversationViewMixin.gradientTween.value = MultiTween<String>()
                ..add("color1", Tween<double>(begin: 0.0, end: 0.2))
                ..add("color2", Tween<double>(begin: 0.8, end: 1.0));
            }
          } else {
            if (primaryPercent != 0.5 && lightBgPercent != 0.5) {
              double difference = min((primaryPercent / (primaryPercent + lightBgPercent)), 1 - (primaryPercent / (primaryPercent + lightBgPercent)));
              Tween color1 = Tween<double>(begin: 0.0, end: difference);
              Tween color2 = Tween<double>(begin: 1.0 - difference, end: 1.0);
              ConversationViewMixin.gradientTween.value = MultiTween<String>()
                ..add("color1", color1)
                ..add("color2", color2);
            } else {
              ConversationViewMixin.gradientTween.value = MultiTween<String>()
                ..add("color1", Tween<double>(begin: 0.0, end: 0.2))
                ..add("color2", Tween<double>(begin: 0.8, end: 1.0));
            }
          }
          SettingsManager().saveSelectedTheme(Get.context!, selectedLightTheme: lightTheme, selectedDarkTheme: darkTheme);
          isRunning = false;
        }
        return Future.value("");
      case "remove-sendPort":
        IsolateNameServer.removePortNameMapping('bg_isolate');
        await prefs.remove('objectbox-reference');
        print("Removed sendPort and objectbox reference because Activity was destroyed");
        store.close();
        return Future.value("");
      default:
        return Future.value("");
    }
  }

  /// [closeThread] closes the background isolate when the app is fully closed
  Future<void> closeThread() async {
    // Only do this if we are indeed running in the background
    if (headless) {
      Logger.info("Closing the background isolate...", tag: "MCI-CloseThread");
      await prefs.remove('objectbox-reference');
      store.close();
      // Tells the native code to close the isolate
      invokeMethod("close-background-isolate");
    }
  }

  Future<void> openChat(String id, {List<PlatformFile> existingAttachments = const [], String? existingText}) async {
    // If the ID is -1, it means the notification grouping header was tapped
    if (id == "-1") {
      NavigatorManager().navigatorKey.currentState!.popUntil((route) => route.isFirst);
      return;
    }

    // If the currently active chat is the same as the tapped notification, we
    // clear notifications for it and update the text field data
    if (ChatManager().activeChat?.chat.guid == id) {
      ChatManager().setActiveChat(ChatManager().activeChat!.chat);
  
      // Get the current text field and update the attachments/text
      TextFieldData? data = TextFieldBloc().getTextField(id);
      if (data != null) {
        if (existingAttachments.isNotEmpty) {
          data.attachments.addAll(existingAttachments);
          final ids = data.attachments.map((e) => e.path).toSet();
          data.attachments.retainWhere((element) => ids.remove(element.path));
          EventDispatcher().emit("text-field-update-attachments", null);
        }

        if (existingText != null) {
          data.controller.text = existingText;
          EventDispatcher().emit("text-field-update-text", null);
        }
      }

      return;
    }

    // If the chat is not active, we should find the respective chat in the 
    // database and then switch to that chat
    Chat? openedChat = Chat.findOne(guid: id);
    if (openedChat != null) {
      // Get all of the participants of the chat so that it looks right when it is opened
      openedChat.getParticipants();

      // Make sure that the title is set
      openedChat.getTitle();

      // if (!ChatController.isActive(openedChat.guid))
      // Actually navigate to the chat page
      CustomNavigator.pushAndRemoveUntil(
          Get.context!,
          ConversationView(
            chat: openedChat,
            existingAttachments: existingAttachments,
            existingText: existingText,
          ),
          (route) => route.isFirst,
        );

      // We have a delay, because the first [switchChat] does not work.
      // Because we are pushing AND removing until it is the first route,
      // the [dispose] methods of the previous conversation views will be called and thus will override the switch chat we just called
      // Thus we need to add a delay here to wait for the animation to finish
      await Future.delayed(Duration(milliseconds: 1000));

      // We already cleared the notifications, so we don't need to
      ChatManager().setActiveChat(openedChat, clearNotifications: true);
    } else {
      Logger.warn("Failed to find chat", tag: "MCI-OpenChat");
    }
  }
}
