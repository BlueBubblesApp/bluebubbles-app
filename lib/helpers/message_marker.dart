import 'dart:async';

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
        this.updateMessageMarkers(event.event["message"] as Message);
      }
    });
  }

  updateMessageMarkers(Message msg) {
    if (!msg.isFromMe!) return;

    if (this.myLastMessage == null ||
        (this.myLastMessage?.dateCreated != null &&
            msg.dateCreated != null &&
            msg.dateCreated!.millisecondsSinceEpoch > this.myLastMessage!.dateCreated!.millisecondsSinceEpoch)) {
      this.myLastMessage = msg;
    }

    if ((this.lastReadMessage == null && msg.dateRead != null) ||
        (this.lastReadMessage?.dateRead != null &&
            msg.dateRead != null &&
            msg.dateRead!.millisecondsSinceEpoch > this.lastReadMessage!.dateRead!.millisecondsSinceEpoch)) {
      this.lastReadMessage = msg;
    }

    if ((this.lastDeliveredMessage == null && msg.dateDelivered != null) ||
        (this.lastDeliveredMessage?.dateDelivered != null &&
            msg.dateDelivered != null &&
            msg.dateDelivered!.millisecondsSinceEpoch >
                this.lastDeliveredMessage!.dateDelivered!.millisecondsSinceEpoch)) {
      this.lastDeliveredMessage = msg;
    }
    markers.value = this;
  }
}
