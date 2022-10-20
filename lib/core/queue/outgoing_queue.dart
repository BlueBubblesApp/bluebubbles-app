import 'package:bluebubbles/core/actions/action_handler.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/core/queue/queue_impl.dart';

class OutgoingQueue extends QueueManager {
  factory OutgoingQueue() {
    return _queue;
  }

  static final OutgoingQueue _queue = OutgoingQueue._internal();

  OutgoingQueue._internal();

  @override
  Future<void> handleQueueItem(QueueItem item) async {
    switch (item.event) {
      case "send-message":
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.sendMessageHelper(params["chat"], params["message"]);
          break;
        }
      case "send-attachment":
        {
          AttachmentSender sender = item.item;
          await sender.send();
          // todo wait for send to complete
          break;
        }
      case "send-reaction":
        {
          Map<String, dynamic> params = item.item;
          await ActionHandler.sendReactionHelper(params["chat"], params["message"], params["reaction"]);
          break;
        }
      default:
        {
          Logger.warn("Unhandled queue event: ${item.event}");
        }
    }
  }
}
