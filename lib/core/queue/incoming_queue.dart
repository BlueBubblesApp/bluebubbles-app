import 'package:bluebubbles/core/actions/action_handler.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/core/queue/queue_impl.dart';

class IncomingQueue extends QueueManager {
  factory IncomingQueue() {
    return _queue;
  }

  static final IncomingQueue _queue = IncomingQueue._internal();

  static const String HANDLE_MESSAGE_EVENT = "handle-message";
  static const String HANDLE_UPDATE_MESSAGE = "handle-updated-message";
  static const String HANDLE_CHAT_STATUS_CHANGE = "chat-status-change";

  IncomingQueue._internal();

  @override
  Future<void> handleQueueItem(QueueItem item) async {
    switch (item.event) {
      case HANDLE_MESSAGE_EVENT:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleMessage(params["data"],
              createAttachmentNotification:
                  params.containsKey("createAttachmentNotification") ? params["createAttachmentNotification"] : false,
              isHeadless: params.containsKey("isHeadless") ? params["isHeadless"] : false);
          break;
        }
      case HANDLE_UPDATE_MESSAGE:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleUpdatedMessage(params["data"],
              headless: params.containsKey("isHeadless") ? params["isHeadless"] : false);
          break;
        }
      case HANDLE_CHAT_STATUS_CHANGE:
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.handleChatStatusChange(params['data']["chatGuid"], !params['data']["read"]);
          break;
        }
      default:
        {
          Logger.info("Unhandled queue event: ${item.event}");
        }
    }
  }
}
