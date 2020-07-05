import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

class DeliveredReceipt extends StatefulWidget {
  DeliveredReceipt({Key key, this.message}) : super(key: key);

  final Message message;

  @override
  _DeliveredReceiptState createState() => _DeliveredReceiptState();
}

class _DeliveredReceiptState extends State<DeliveredReceipt>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    if (widget.message.dateRead == null && widget.message.dateDelivered == null)
      return Container();

    String text = "Delivered";
    if (widget.message.dateRead != null) text = "Read";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            text,
            style: Theme.of(context).textTheme.subtitle2,
          )
        ],
      ),
    );
  }
}
