import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:flutter/material.dart';

class OutgoingQueue extends QueueManager {
  factory OutgoingQueue() {
    return _queue;
  }

  static final OutgoingQueue _queue = OutgoingQueue._internal();

  OutgoingQueue._internal();

  @override
  Future<void> handleQueueItem(QueueItem item) async {
    switch (item.event) {
      case "send-message": {
        Map<String, dynamic> params = item.item;
        await ActionHandler.sendMessageHelper(params["chat"], params["message"]);
        break;
      }
      case "send-attachment": {
        AttachmentSender sender = item.item;
        await sender.send();
        break;
      }
      default: {
        debugPrint("Unhandled queue event: ${item.event}");
      }
    }
  }
}