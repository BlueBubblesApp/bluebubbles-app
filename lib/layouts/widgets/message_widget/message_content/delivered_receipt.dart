import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

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
    setState(() {
      showReceipt = widget.showDeliveredReceipt;
    });
  }

  @override
  Widget build(BuildContext context) {
    String text = "Delivered";
    if (widget.message != null && widget.message.dateRead != null)
      text = "Read";

    return AnimatedSize(
      vsync: this,
      curve: Curves.easeInOut,
      alignment: Alignment.bottomLeft,
      duration: Duration(milliseconds: 250),
      child: widget.message != null &&
              !(widget.message.dateRead == null &&
                  widget.message.dateDelivered == null) &&
              showReceipt
          ? Padding(
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
            )
          : Container(),
    );
  }
}
