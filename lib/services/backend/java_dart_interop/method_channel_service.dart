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

  Future<void> init({bool headless = false}) async {
    if (kIsWeb || kIsDesktop) return;

    background = headless;
    channel = const MethodChannel('com.bluebubbles.messaging');
    channel.setMethodCallHandler(_callHandler);
    if (!kIsWeb && !kIsDesktop && !headless) {
      try {
        if (ss.settings.colorsFromMedia.value) {
          await mcs.invokeMethod("start-notification-listener");
        }
        if (!ls.isBubble) {
          BackgroundIsolate.initialize();
        }
        chromeOS = await mcs.invokeMethod("check-chromeos") ?? false;
      } catch (_) {}
    }
  }

  Future<bool> _callHandler(MethodCall call) async {
    switch (call.method) {
      case "NewServerUrl":
        await storeStartup.future;
        // remove brackets from URL
        String address = call.arguments["server_url"];
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
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          final payload = ServerPayload.fromJson(data!);
          final item = IncomingItem.fromMap(QueueType.newMessage, payload.data);
          if (ls.isAlive) {
            await inq.queue(item);
          } else {
            await ah.handleNewMessage(item.chat, item.message, item.tempGuid);
          }
        }
        return true;
      case "updated-message":
        await storeStartup.future;
        Logger.info("Received updated message from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          final payload = ServerPayload.fromJson(data!);
          final item = IncomingItem.fromMap(QueueType.updatedMessage, payload.data);
          if (ls.isAlive) {
            await inq.queue(item);
          } else {
            await ah.handleUpdatedMessage(item.chat, item.message, item.tempGuid);
          }
        }
        return true;
      case "group-name-change":
      case "participant-removed":
      case "participant-added":
      case "participant-left":
        await storeStartup.future;
        Logger.info("Received ${call.method} from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          final item = IncomingItem.fromMap(QueueType.updatedMessage, data!);
          await ah.handleNewOrUpdatedChat(item.chat);
        }
        return true;
      case "group-icon-changed":
        await storeStartup.future;
        Logger.info("Received group icon change from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          final guid = data!["chats"].first["guid"];
          final chat = Chat.findOne(guid: guid);
          if (chat != null) {
            await Chat.getIcon(chat);
          }
        }
        return true;
      case "scheduled-message-error":
        Logger.info("Received scheduled message error from FCM");
        Map<String, dynamic> data = call.arguments?.cast<String, Object>() ?? {};
        Chat? chat = Chat.findOne(guid: data["payload"]["chatGuid"]);
        if (chat != null) {
          await notif.createFailedToSend(chat, scheduled: true);
        }
        return true;
      case "ReplyChat":
        await storeStartup.future;
        Logger.info("Received reply to message from Kotlin");
        final data = call.arguments as Map?;
        if (data == null) return false;
        // check and make sure that we aren't sending a duplicate reply
        final recentReplyGuid = ss.prefs.getString("recent-reply")?.split("/").first;
        final recentReplyText = ss.prefs.getString("recent-reply")?.split("/").last;
        if (recentReplyGuid == data["messageGuid"] && recentReplyText == data["text"]) return false;
        await ss.prefs.setString("recent-reply", "${data["messageGuid"]}/${data["text"]}");
        Logger.info("Updated recent reply cache to ${ss.prefs.getString("recent-reply")}");
        Chat? chat = Chat.findOne(guid: data["chatGuid"]);
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
            customArgs: {'notifReply': true}
          ));
          await completer.future;
          return true;
        }
      case "MarkChatRead":
        if (ls.isAlive) return true;
        await storeStartup.future;
        Logger.info("Received markAsRead from Kotlin");
        final data = call.arguments as Map?;
        if (data != null) {
          Chat? chat = Chat.findOne(guid: data["chatGuid"]);
          if (chat != null) {
            chat.toggleHasUnread(false);
            return true;
          }
        }
        return false;
      case "chat-read-status-changed":
        if (ls.isAlive) return true;
        await storeStartup.future;
        Logger.info("Received chat status change from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          Chat? chat = Chat.findOne(guid: data!["chatGuid"]);
          if (chat == null || (data["read"] != true && data["read"] != false)) {
            return false;
          } else {
            chat.toggleHasUnread(!data["read"]!, privateMark: false);
            return true;
          }
        } else {
          return false;
        }
      case "MediaColors":
        await storeStartup.future;
        if (!ss.settings.colorsFromMedia.value) return false;
        final Color primary = Color(call.arguments['primary']);
        if (Get.context != null && (!isRunning || primary != previousPrimary)) {
          ts.updateMusicTheme(Get.context!, primary);
          isRunning = false;
        }
        return true;
      case "incoming-facetime":
        await storeStartup.future;
        Logger.info("Received legacy incoming facetime from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          await ActionHandler().handleIncomingFaceTimeCallLegacy(data!);
        }
        return true;
      case "ft-call-status-changed":
        if (ls.isAlive) return true;
        await storeStartup.future;
        Logger.info("Received facetime call status change from FCM");
        Map<String, dynamic>? data = call.arguments?.cast<String, Object>();
        if (!isNullOrEmpty(data)!) {
          await ActionHandler().handleFaceTimeStatusChange(data!);
        }
        return true;
      case "answer-facetime":
        Logger.info("Answering FaceTime call");
        await intents.answerFaceTime(call.arguments["callUuid"]);
        return true;
      default:
        return true;
    }
  }

  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    if (kIsWeb || kIsDesktop) return;
    Logger.info("Sending method $method to Kotlin");
    return await channel.invokeMethod(method, arguments);
  }
}