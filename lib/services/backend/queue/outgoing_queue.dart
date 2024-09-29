import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/classes/aliases.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/backend/queue/queue_impl.dart';
import 'package:get/get.dart';

OutgoingQueue outq = Get.isRegistered<OutgoingQueue>() ? Get.find<OutgoingQueue>() : Get.put(OutgoingQueue());

class OutgoingQueue extends Queue {

  @override
  Future<dynamic> prepItem(QueueItem _) async {
    assert(_ is OutgoingItem);
    final item = _ as OutgoingItem;

    switch (item.type) {
      case QueueType.sendMultipart:
      case QueueType.sendMessage:
        return await ah.prepMessage(item.chatGuid, item.message, item.selected, item.reaction, clearNotificationsIfFromMe: !(item.customArgs?['notifReply'] ?? false));
      case QueueType.sendAttachment:
        return await ah.prepAttachment(item.chatGuid, item.message);
      default:
        Logger.info("Unhandled queue event: ${item.type.name}");
        break;
    }
  }

  Future<T> handleSend<T>(Future<T> Function() process, ChatGuid chatGuid) {
    final rChat = GlobalChatService.getChat(chatGuid)!.observables;
    var timer = Timer(const Duration(seconds: 5), () {
      rChat.setSendProgress(0.9);
    });
    var t = process();
    t.then((c) {
      timer.cancel();
      if (rChat.sendProgress.value != 0) {
        rChat.setSendProgress(1);
      }
    }).catchError((c) {
      timer.cancel();
      if (rChat.sendProgress.value != 0) {
        rChat.setSendProgress(1);
      }
    });
    return t;
  }

  @override
  Future<void> handleQueueItem(QueueItem _) async {
    assert(_ is OutgoingItem);
    final item = _ as OutgoingItem;

    switch (item.type) {
      case QueueType.sendMessage:
        await handleSend(() => ah.sendMessage(item.chatGuid, item.message, item.selected, item.reaction), item.chatGuid);
        break;
      case QueueType.sendMultipart:
        await handleSend(() => ah.sendMultipart(item.chatGuid, item.message, item.selected, item.reaction), item.chatGuid);
        break;
      case QueueType.sendAttachment:
        await handleSend(() => ah.sendAttachment(item.chatGuid, item.message, item.customArgs?['audio'] ?? false), item.chatGuid);
        break;
      default:
        Logger.info("Unhandled queue event: ${item.type.name}");
        break;
    }
  }
}