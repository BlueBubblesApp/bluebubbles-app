import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:flutter/material.dart';

class IncomingQueue extends QueueManager {
  factory IncomingQueue() {
    return _queue;
  }

  static final IncomingQueue _queue = IncomingQueue._internal();

  IncomingQueue._internal();

  @override
  Future<void> handleQueueItem(QueueItem item) async {
    switch (item.event) {
      case "handle-message":
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleMessage(params["data"],
              createAttachmentNotification:
                  params.containsKey("createAttachmentNotification")
                      ? params["createAttachmentNotification"]
                      : false,
              isHeadless: params.containsKey("isHeadless")
                  ? params["isHeadless"]
                  : false);
          break;
        }
      case "handle-updated-message":
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleUpdatedMessage(params["data"],
              headless: params.containsKey("isHeadless")
                  ? params["isHeadless"]
                  : false);
          break;
        }
      default:
        {
          debugPrint("Unhandled queue event: ${item.event}");
        }
    }
  }
}
