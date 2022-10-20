import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dynamic_cached_fonts/dynamic_cached_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:universal_io/io.dart';

MethodChannelService mcs = Get.isRegistered<MethodChannelService>() ? Get.find<MethodChannelService>() : Get.put(MethodChannelService());

class MethodChannelService extends GetxService {
  late final MethodChannel channel;
  bool background = false;

  // music theme
  bool isRunning = false;
  Color? previousPrimary;
  Color? previousLightBg;
  Color? previousDarkBg;

  Future<void> init({bool headless = false}) async {
    if (kIsWeb || kIsDesktop) return;

    background = headless;
    channel = MethodChannel('com.bluebubbles.messaging');
    channel.setMethodCallHandler(_callHandler);
    if (!kIsWeb && !kIsDesktop && headless) await channel.invokeMethod('MessagingBackground#initialized');
  }

  Future<dynamic> _callHandler(MethodCall call) async {
    switch (call.method) {
      case "new-server":
        // remove brackets from URL
        String address = call.arguments.toString().replaceAll("[", "").replaceAll("]", "");
        ss.settings.serverAddress.value = sanitizeServerAddress(address: address)!;
        ss.settings.save();

        if (!background) {
          Get.reload<SocketService>(force: true);
        }
        return true;
      case "new-message":
        Logger.info("Received new message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_MESSAGE_EVENT, item: {"data": data}));
        return true;
      case "updated-message":
        Logger.info("Received updated message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_UPDATE_MESSAGE, item: {"data": data}));
        return true;
      /*case "ChatOpen":
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

        // Remove the notification from that chat
        await mcs.invokeMethod("clear-chat-notifs", {"chatGuid": chat.guid});

        if (ss.settings.privateMarkChatAsRead.value && chat.autoSendReadReceipts!) {
          await http.markChatRead(chat.guid);
        }

        // In case this method is called when the app is in a background isolate
        await closeThread();

        return Future.value("");
      case "chat-read-status-changed":
        await ActionHandler.handleChatStatusChange(call.arguments["chatGuid"], !call.arguments["read"]);

        // In case this method is called when the app is in a background isolate
        await closeThread();

        return Future.value("");
      case "shareAttachments":
        if (!ss.settings.finishedSetup.value) return Future.value("");
        recentIntent = call.arguments["id"];
        List<PlatformFile> attachments = [];

        // Loop through all of the attachments sent by native code
        call.arguments["attachments"].forEach((element) async {
          // Get the file in that directory
          File file = File(element);

          // Add each file to the attachment list
          attachments.add(PlatformFile(
            name: file.path.split("/").last,
            path: file.path,
            bytes: await file.readAsBytes(),
            size: await file.length(),
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
        ns.pushAndRemoveUntil(
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
        if (!ss.settings.finishedSetup.value) return Future.value("");
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
        ns.pushAndRemoveUntil(
          Get.context!,
          ConversationView(
            existingText: text,
            isCreator: true,
          ),
              (route) => route.isFirst,
        );
        recentIntent = null;
        return Future.value("");*/
      case "media-colors":
        if (!ss.settings.colorsFromMedia.value) return false;
        final Color primary = Color(call.arguments['primary']);
        final Color lightBg = Color(call.arguments['lightBg']);
        final Color darkBg = Color(call.arguments['darkBg']);
        final double primaryPercent = call.arguments['primaryPercent'];
        final double lightBgPercent = call.arguments['lightBgPercent'];
        final double darkBgPercent = call.arguments['darkBgPercent'];
        if (Get.context != null &&
            (!isRunning || primary != previousPrimary || lightBg != previousLightBg || darkBg != previousDarkBg)) {
          ts.updateMusicTheme(Get.context!, primary, lightBg, darkBg, primaryPercent, lightBgPercent, darkBgPercent);
          isRunning = false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    if (kIsWeb || kIsDesktop) return;

    return await channel.invokeMethod(method, arguments);
  }
}