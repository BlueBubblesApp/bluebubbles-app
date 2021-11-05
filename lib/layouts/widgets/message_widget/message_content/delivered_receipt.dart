import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
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

class _DeliveredReceiptState extends State<DeliveredReceipt> with TickerProviderStateMixin {
  bool shouldShow(Message? myLastMessage, Message? lastReadMessage, Message? lastDeliveredMessage) {
    // If we have no delivered date, don't show anything
    if (widget.message.dateDelivered.value == null) return false;

    if (CurrentChat.activeChat != null) {
      lastReadMessage ??= CurrentChat.activeChat?.messageMarkers.lastReadMessage;
      lastDeliveredMessage ??= CurrentChat.activeChat?.messageMarkers.lastDeliveredMessage;
      myLastMessage ??= CurrentChat.activeChat?.messageMarkers.myLastMessage;
    }

    // If the message is the same as the last read message, we want to show it
    if (!widget.showDeliveredReceipt &&
        widget.message.dateRead.value != null &&
        lastReadMessage != null &&
        widget.message.guid == lastReadMessage.guid) {
      return true;
    }

    // If the message is the same as the last delivered message, we want to show it
    if (!widget.showDeliveredReceipt &&
        widget.message.dateDelivered.value != null &&
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
    String text = "Delivered";
    if (widget.message.dateRead.value != null) {
      text = "Read " + buildDate(widget.message.dateRead.value);
    } else if (SettingsManager().settings.showDeliveryTimestamps.value && widget.message.dateDelivered.value != null) {
      text = "Delivered " + buildDate(widget.message.dateDelivered.value);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    Widget timestampWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Obx(() {
        MessageMarkers? markers = CurrentChat.activeChat?.messageMarkers.markers.value ?? null.obs.value;
        if (shouldShow(markers?.myLastMessage, markers?.lastReadMessage, markers?.lastDeliveredMessage)) {
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
          vsync: this,
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
