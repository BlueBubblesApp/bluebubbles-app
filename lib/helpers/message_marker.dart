import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:get/get.dart';

class MessageMarkers {
  String guid;
  final Rxn<Message> myLastMessage = Rxn();
  final Rxn<Message> lastReadMessage = Rxn();
  final Rxn<Message> lastDeliveredMessage = Rxn();

  MessageMarkers(this.guid) {
    NewMessageManager().stream.listen((event) {
      // Ignore any events that don't have to do with the current chat
      if (event.chatGuid != guid) return;

      // If it's the event we want
      if (event.type == NewMessageType.UPDATE || event.type == NewMessageType.ADD) {
        updateMessageMarkers(event.event["message"] as Message);
      }
    });
  }

  updateMessageMarkers(Message msg) {
    if (!msg.isFromMe!) return;

    if (myLastMessage.value == null ||
        (myLastMessage.value?.dateCreated != null &&
            msg.dateCreated != null &&
            msg.dateCreated!.millisecondsSinceEpoch > myLastMessage.value!.dateCreated!.millisecondsSinceEpoch)) {
      myLastMessage.value = msg;
    }

    if ((lastReadMessage.value == null && msg.dateRead != null) ||
        (lastReadMessage.value?.dateRead != null &&
            msg.dateRead != null &&
            msg.dateRead!.millisecondsSinceEpoch > lastReadMessage.value!.dateRead!.millisecondsSinceEpoch)) {
      lastReadMessage.value = msg;
    }

    if ((lastDeliveredMessage.value == null && msg.dateDelivered != null) ||
        (lastDeliveredMessage.value?.dateDelivered != null &&
            msg.dateDelivered != null &&
            msg.dateDelivered!.millisecondsSinceEpoch >
                lastDeliveredMessage.value!.dateDelivered!.millisecondsSinceEpoch)) {
      lastDeliveredMessage.value = msg;
    }
  }
}
