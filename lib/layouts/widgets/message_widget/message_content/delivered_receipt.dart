import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bluebubbles/helpers/utils.dart';

class DeliveredReceipt extends StatefulWidget {
  DeliveredReceipt({
    Key key,
    this.message,
    this.showDeliveredReceipt,
  }) : super(key: key);
  final bool showDeliveredReceipt;
  final Message message;

  @override
  _DeliveredReceiptState createState() => _DeliveredReceiptState();
}

class _DeliveredReceiptState extends State<DeliveredReceipt>
    with SingleTickerProviderStateMixin {
  bool showReceipt = false;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await Future.delayed(Duration(milliseconds: 100));
    if (this.mounted) {
      setState(() {
        showReceipt = widget.showDeliveredReceipt;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    String text = "Delivered";
    if (widget.message != null && widget.message.dateRead != null)
      text = "Read " + _buildDate();

    return AnimatedSize(
      vsync: this,
      curve: Curves.easeInOut,
      alignment: Alignment.bottomLeft,
      duration: Duration(milliseconds: 250),
      child: widget.message != null && showReceipt && (widget.message.dateRead != null ||
                  widget.message.dateDelivered != null)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .subtitle2,
                  )
                ],
              ),
            )
          : Container(),
    );
  }
}
