import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/services/backend/queue/queue_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

OutgoingQueue outq = Get.isRegistered<OutgoingQueue>() ? Get.find<OutgoingQueue>() : Get.put(OutgoingQueue());

class OutgoingQueue extends Queue {

  @override
  Future<dynamic> prepItem(QueueItem _) async {
    assert(_ is OutgoingItem);
    final item = _ as OutgoingItem;

    switch (item.type) {
      case QueueType.sendMessage:
        return await ah.prepMessage(item.chat, item.message, item.selected, item.reaction, clearNotificationsIfFromMe: !(item.customArgs?['notifReply'] ?? false));
      case QueueType.sendAttachment:
        return await ah.prepAttachment(item.chat, item.message);
      default:
        Logger.info("Unhandled queue event: ${describeEnum(item.type)}");
        break;
    }
  }

  @override
  Future<void> handleQueueItem(QueueItem _) async {
    assert(_ is OutgoingItem);
    final item = _ as OutgoingItem;

    switch (item.type) {
      case QueueType.sendMessage:
        await ah.sendMessage(item.chat, item.message, item.selected, item.reaction);
        break;
      case QueueType.sendAttachment:
        await ah.sendAttachment(item.chat, item.message, item.customArgs?['audio'] ?? false);
        break;
      default:
        Logger.info("Unhandled queue event: ${describeEnum(item.type)}");
        break;
    }
  }
}
