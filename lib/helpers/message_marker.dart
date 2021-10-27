import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:get/get.dart';

class MessageMarkers {
  Chat chat;
  Message? myLastMessage;
  Message? lastReadMessage;
  Message? lastDeliveredMessage;
  late final Rx<MessageMarkers> markers;

  MessageMarkers(this.chat) {
    markers = Rx<MessageMarkers>(this);
    NewMessageManager().stream.listen((event) {
      // Ignore any events that don't have to do with the current chat
      if (event.chatGuid != chat.guid) return;

      // If it's the event we want
      if (event.type == NewMessageType.UPDATE || event.type == NewMessageType.ADD) {
        updateMessageMarkers(event.event["message"] as Message);
      }
    });
  }

  updateMessageMarkers(Message msg) {
    if (!msg.isFromMe!) return;

    if (myLastMessage == null ||
        (myLastMessage?.dateCreated != null &&
            msg.dateCreated != null &&
            msg.dateCreated!.millisecondsSinceEpoch > myLastMessage!.dateCreated!.millisecondsSinceEpoch)) {
      myLastMessage = msg;
    }

    if ((lastReadMessage == null && msg.dateRead != null) ||
        (lastReadMessage?.dateRead != null &&
            msg.dateRead != null &&
            msg.dateRead!.millisecondsSinceEpoch > lastReadMessage!.dateRead!.millisecondsSinceEpoch)) {
      lastReadMessage = msg;
    }

    if ((lastDeliveredMessage == null && msg.dateDelivered != null) ||
        (lastDeliveredMessage?.dateDelivered != null &&
            msg.dateDelivered != null &&
            msg.dateDelivered!.millisecondsSinceEpoch >
                lastDeliveredMessage!.dateDelivered!.millisecondsSinceEpoch)) {
      lastDeliveredMessage = msg;
    }
    markers.value = this;
  }
}
