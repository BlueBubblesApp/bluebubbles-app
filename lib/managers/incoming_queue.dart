import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/queue_manager.dart';

class IncomingQueue extends QueueManager {
  factory IncomingQueue() {
    return _queue;
  }

  static final IncomingQueue _queue = IncomingQueue._internal();

  static const String handleMessageEvent = "handle-message";
  static const String handleUpdateMessage = "handle-updated-message";
  static const String handleChatStatusChange = "chat-status-change";

  IncomingQueue._internal();

  @override
  Future<void> handleQueueItem(QueueItem item) async {
    switch (item.event) {
      case handleMessageEvent:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleMessage(params["data"],
              createAttachmentNotification:
                  params.containsKey("createAttachmentNotification") ? params["createAttachmentNotification"] : false,
              isHeadless: params.containsKey("isHeadless") ? params["isHeadless"] : false);
          break;
        }
      case handleUpdateMessage:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleUpdatedMessage(params["data"],
              headless: params.containsKey("isHeadless") ? params["isHeadless"] : false);
          break;
        }
      case handleChatStatusChange:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleChatStatusChange(params["chatGuid"], params["status"]);
          break;
        }
      default:
        {
          Logger.info("Unhandled queue event: ${item.event}");
        }
    }
  }
}
