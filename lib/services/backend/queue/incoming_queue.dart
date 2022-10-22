import 'package:bluebubbles/core/actions/action_handler.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/services/backend/queue/queue_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

IncomingQueue inq = Get.isRegistered<IncomingQueue>() ? Get.find<IncomingQueue>() : Get.put(IncomingQueue());

class IncomingQueue extends Queue {

  @override
  Future<void> handleQueueItem(QueueItem _) async {
    assert(_ is IncomingItem);
    final item = _ as IncomingItem;

    switch (item.type) {
      case QueueType.newMessage:
        await ActionHandler.handleMessage(item.message, isHeadless: !ls.isAlive);
        break;
      case QueueType.updatedMessage:
        await ActionHandler.handleUpdatedMessage(item.message, headless: !ls.isAlive);
        break;
      default:
        Logger.info("Unhandled queue event: ${describeEnum(item.type)}");
        break;
    }
  }
}