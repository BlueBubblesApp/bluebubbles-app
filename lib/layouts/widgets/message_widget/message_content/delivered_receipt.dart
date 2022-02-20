import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliveredReceipt extends StatefulWidget {
  DeliveredReceipt({
    Key? key,
    required this.message,
    required this.showDeliveredReceipt,
    required this.shouldAnimate,
  }) : super(key: key);
  final bool showDeliveredReceipt;
  final bool shouldAnimate;
  final Message message;

  @override
  _DeliveredReceiptState createState() => _DeliveredReceiptState();
}

class _DeliveredReceiptState extends State<DeliveredReceipt> {
  bool shouldShow(Message? myLastMessage, Message? lastReadMessage, Message? lastDeliveredMessage) {
    if (ChatManager().activeChat != null) {
      lastReadMessage ??= ChatManager().activeChat?.messageMarkers.lastReadMessage.value;
      lastDeliveredMessage ??= ChatManager().activeChat?.messageMarkers.lastDeliveredMessage.value;
      myLastMessage ??= ChatManager().activeChat?.messageMarkers.myLastMessage.value;
    }

    // If the message is the same as the last read message, we want to show it
    if (!widget.showDeliveredReceipt &&
        widget.message.dateRead != null &&
        lastReadMessage != null &&
        widget.message.guid == lastReadMessage.guid) {
      return true;
    }

    // If the message is the same as the last delivered message, we want to show it
    if (!widget.showDeliveredReceipt &&
        widget.message.dateDelivered != null &&
        lastDeliveredMessage != null &&
        widget.message.guid == lastDeliveredMessage.guid) {
      return true;
    }

    // This is logic so that we can have both a read receipt on an older message
    // As well as a delivered receipt on the newest message
    // if (!widget.showDeliveredReceipt! &&
    //     myLastMessage != null &&
    //     widget.message!.dateRead != null &&
    //     myLastMessage.dateRead == null &&
    //     lastReadMessage != null &&
    //     lastReadMessage.guid == widget.message!.guid &&
    //     lastDeliveredMessage != null &&
    //     lastDeliveredMessage.guid == widget.message!.guid) {
    //   return true;
    // }

    // If all else fails, return what our parent wants
    return widget.showDeliveredReceipt;
  }

  String getText() {
    String text = "Sent";
    if (!(widget.message.isFromMe ?? false)) {
      text = "Received " + buildDate(widget.message.dateCreated);
    } else if (widget.message.dateRead != null) {
      text = "Read " + buildDate(widget.message.dateRead);
    } else if (widget.message.dateDelivered != null) {
      text = "Delivered"
          + (SettingsManager().settings.showDeliveryTimestamps.value
              ? " ${buildDate(widget.message.dateDelivered)}" : "");
    } else if (SettingsManager().settings.showDeliveryTimestamps.value && widget.message.dateCreated != null) {
      text = "Sent " + buildDate(widget.message.dateCreated);
    }

    return text;
  }

  MessageMarkers? markers = ChatManager().activeChat?.messageMarkers;

  @override
  Widget build(BuildContext context) {
    Widget timestampWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Obx(() {
        if (shouldShow(markers?.myLastMessage.value, markers?.lastReadMessage.value, markers?.lastDeliveredMessage.value)) {
          return Text(
            getText(),
            style: Theme.of(context).textTheme.subtitle2,
          );
        } else {
          return Container();
        }
      }),
    );

    Widget item;
    if (widget.shouldAnimate) {
      item = AnimatedSize(
          curve: Curves.easeInOut,
          alignment: Alignment.bottomLeft,
          duration: Duration(milliseconds: 250),
          child: timestampWidget);
    } else {
      item = timestampWidget;
    }

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 4),
      child: item,
    );
  }
}
