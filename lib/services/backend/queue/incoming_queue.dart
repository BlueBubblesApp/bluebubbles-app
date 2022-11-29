import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/services/backend/queue/queue_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

IncomingQueue inq = Get.isRegistered<IncomingQueue>() ? Get.find<IncomingQueue>() : Get.put(IncomingQueue());

class IncomingQueue extends Queue {

  @override
  Future<void> prepItem(QueueItem _) async {}

  @override
  Future<void> handleQueueItem(QueueItem _) async {
    assert(_ is IncomingItem);
    final item = _ as IncomingItem;

    switch (item.type) {
      case QueueType.newMessage:
        await ah.handleNewMessage(item.chat, item.message, item.tempGuid);
        break;
      case QueueType.updatedMessage:
        await ah.handleUpdatedMessage(item.chat, item.message, item.tempGuid);
        break;
      default:
        Logger.info("Unhandled queue event: ${describeEnum(item.type)}");
        break;
    }
  }
}
