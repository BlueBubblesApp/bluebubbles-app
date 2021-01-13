import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bluebubbles/helpers/utils.dart';

class DeliveredReceipt extends StatefulWidget {
  DeliveredReceipt({
    Key key,
    this.message,
    this.showDeliveredReceipt,
    this.shouldAnimate,
  }) : super(key: key);
  final bool showDeliveredReceipt;
  final bool shouldAnimate;
  final Message message;

  @override
  _DeliveredReceiptState createState() => _DeliveredReceiptState();
}

class _DeliveredReceiptState extends State<DeliveredReceipt>
    with TickerProviderStateMixin {
  String _buildDate() {
    DateTime timeOfnewerMessage = widget.message.dateRead;
    String time = new DateFormat.jm().format(timeOfnewerMessage);
    String date;
    if (widget.message.dateRead.isToday()) {
      date = time;
    } else if (widget.message.dateRead.isYesterday()) {
      date = "Yesterday";
    } else {
      date =
          "${timeOfnewerMessage.month.toString()}/${timeOfnewerMessage.day.toString()}/${timeOfnewerMessage.year.toString()}";
    }
    return date;
  }

  bool shouldShow(Message myLastMessage, Message lastReadMessage) {
    // If we have no delivered date, don't show anything
    if (widget.message.dateDelivered == null) return false;

    // If we have no context, show based on what our parent thinks
    if (context == null) return widget.showDeliveredReceipt;

    // If the passed params are null, try to get it from the current chat
    if (myLastMessage == null)
      myLastMessage = CurrentChat.of(context)?.myLastMessage;
    if (lastReadMessage == null)
      lastReadMessage = CurrentChat.of(context)?.lastReadMessage;

    // This is logic so that we can have both a read receipt on an older message
    // As well as a delivered receipt on the newest message
    if (!widget.showDeliveredReceipt &&
        myLastMessage != null &&
        widget.message.dateRead != null &&
        myLastMessage.dateRead == null &&
        lastReadMessage != null &&
        lastReadMessage.guid == widget.message.guid) {
      return true;
    }

    // If all else fails, return what our parent wants
    return widget.showDeliveredReceipt;
  }

  String getText() {
    String text = "Delivered";
    if (widget.message?.dateRead != null) text = "Read " + _buildDate();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    Widget timestampWidget = Container();
    if (widget.message != null) {
      timestampWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            StreamBuilder(
                stream: CurrentChat.of(context)?.messageMarkerStream?.stream,
                initialData: {"myLastMessage": null, "lastReadMessage": null},
                builder: (context, snapshot) {
                  if (!snapshot.hasData && shouldShow(null, null)) {
                    return Text(
                      getText(),
                      style: Theme.of(context).textTheme.subtitle2,
                    );
                  } else if (snapshot.hasData &&
                      shouldShow(snapshot.data["myLastMessage"],
                          snapshot.data["lastReadMessage"])) {
                    return Text(
                      getText(),
                      style: Theme.of(context).textTheme.subtitle2,
                    );
                  } else {
                    return Container();
                  }
                })
          ],
        ),
      );
    }

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
      padding: EdgeInsets.symmetric(vertical: shouldShow(null, null) ? 4 : 0),
      child: item,
    );
  }
}
