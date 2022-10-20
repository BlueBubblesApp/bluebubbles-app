import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/core/actions/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/core/managers/life_cycle_manager.dart';
import 'package:bluebubbles/core/queue/incoming_queue.dart';
import 'package:bluebubbles/core/queue/queue_impl.dart';
import 'package:bluebubbles/repository/models/models.dart';
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
    channel = MethodChannel('com.bluebubbles.messaging');
    channel.setMethodCallHandler(_callHandler);
    if (!kIsWeb && !kIsDesktop && headless) await channel.invokeMethod('MessagingBackground#initialized');
    if (!kIsWeb && !kIsDesktop && !headless) {
      try {
        if (ss.settings.colorsFromMedia.value) {
          await mcs.invokeMethod("start-notif-listener");
        }
        if (!LifeCycleManager().isBubble) {
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
        ss.settings.serverAddress.value = sanitizeServerAddress(address: address)!;
        ss.settings.save();

        if (!background) {
          Get.reload<SocketService>(force: true);
        }
        return true;
      case "new-message":
        await storeStartup.future;
        Logger.info("Received new message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_MESSAGE_EVENT, item: {"data": data}));
        return true;
      case "updated-message":
        await storeStartup.future;
        Logger.info("Received updated message from FCM");
        Map<String, dynamic>? data = jsonDecode(call.arguments);
        IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_UPDATE_MESSAGE, item: {"data": data}));
        return true;
      case "reply":
        await storeStartup.future;
        Logger.info("Received reply to message from FCM");
        Map<String, dynamic> data = jsonDecode(call.arguments);
        Chat? chat = Chat.findOne(guid: data["chat"]);
        if (chat == null) {
          return false;
        } else {
          final Completer<void> completer = Completer();
          await ActionHandler.sendMessage(chat, data["text"], completer: completer);
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
          ChatBloc().toggleChatUnread(chat, !(data["read"] ?? true));
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