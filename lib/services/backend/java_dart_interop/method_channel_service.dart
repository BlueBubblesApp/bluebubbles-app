import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
    channel = const MethodChannel('com.bluebubbles.messaging');
    channel.setMethodCallHandler(_callHandler);
    if (!kIsWeb && !kIsDesktop && headless) {
      try {
        await channel.invokeMethod('MessagingBackground#initialized');
      } catch (_) {}
    }
    if (!kIsWeb && !kIsDesktop && !headless) {
      try {
        if (ss.settings.colorsFromMedia.value) {
          await mcs.invokeMethod("start-notif-listener");
        }
        if (!ls.isBubble) {
          BackgroundIsolate.initialize();
        }
      } catch (_) {}
    }
  }

  Future<dynamic> _callHandler(MethodCall call) async {
    switch (call.method) {
      case "new-server":
        await storeStartup.future;
        // remove brackets from URL
        String address = call.arguments.toString().replaceAll("[", "").replaceAll("]", "");
        String sanitized = sanitizeServerAddress(address: address)!;
        if (sanitized != ss.settings.serverAddress.value) {
          ss.settings.serverAddress.value = sanitizeServerAddress(address: address)!;
          ss.settings.save();

          if (!background) {
            socket.restartSocket();
          }
        }
        return true;
      case "new-message":
        await storeStartup.future;
        Logger.info("Received new message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        if (!isNullOrEmpty(data)!) {
          inq.queue(IncomingItem.fromMap(QueueType.newMessage, data!));
        }
        return true;
      case "updated-message":
        await storeStartup.future;
        Logger.info("Received updated message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        if (!isNullOrEmpty(data)!) {
          inq.queue(IncomingItem.fromMap(QueueType.updatedMessage, data!));
        }
        return true;
      case "reply":
        await storeStartup.future;
        Logger.info("Received reply to message from FCM");
        final data = call.arguments as Map?;
        if (data == null) return;
        Chat? chat = Chat.findOne(guid: data["chat"]);
        if (chat == null) {
          return false;
        } else {
          final Completer<void> completer = Completer();
          outq.queue(OutgoingItem(
            type: QueueType.sendMessage,
            completer: completer,
            chat: chat,
            message: Message(
              text: data['text'],
              dateCreated: DateTime.now(),
              hasAttachments: false,
              isFromMe: true,
              handleId: 0,
            ),
          ));
          await completer.future;
          return true;
        }
      case "markAsRead":
      case "chat-read-status-changed":
        await storeStartup.future;
        Logger.info("Received chat status change from FCM");
        Map<String, dynamic> data = jsonDecode(call.arguments);
        Chat? chat = Chat.findOne(guid: data["chatGuid"]);
        if (chat == null) {
          return false;
        } else {
          chat.toggleHasUnread(!(data["read"] ?? true));
          return true;
        }
      case "media-colors":
        await storeStartup.future;
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