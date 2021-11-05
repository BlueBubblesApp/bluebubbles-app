import 'package:bluebubbles/repository/models/message.dart';

enum Indicator { READ, DELIVERED, SENT, NONE }

Indicator shouldShow(
    Message? latestMessage, Message? myLastMessage, Message? lastReadMessage, Message? lastDeliveredMessage) {
  if (!(latestMessage?.isFromMe ?? false)) return Indicator.NONE;
  if (latestMessage?.dateRead.value != null) return Indicator.READ;
  if (latestMessage?.dateDelivered.value != null) return Indicator.DELIVERED;
  if (latestMessage?.dateCreated != null) return Indicator.SENT;

  return Indicator.NONE;
}
