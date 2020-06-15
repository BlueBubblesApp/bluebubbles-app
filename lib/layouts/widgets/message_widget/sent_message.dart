import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final OverlayEntry overlayEntry;
  final List<Widget> content;
  final Widget deliveredReceipt;
  SentMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    @required this.content,
    @required this.overlayEntry,
    @required this.deliveredReceipt,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage> {
  @override
  Widget build(BuildContext context) {
    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Colors.black,
      ),
    ];
    if (widget.showTail) {
      stack.insertAll(0, tail);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            GestureDetector(
              onLongPress: () {
                Overlay.of(context).insert(widget.overlayEntry);
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: widget.showTail ? 10.0 : 3.0),
                child: Stack(
                  alignment: AlignmentDirectional.bottomEnd,
                  children: <Widget>[
                    Stack(
                      alignment: AlignmentDirectional.bottomEnd,
                      children: stack,
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 3 / 4,
                      ),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.blue,
                      ),
                      // color: Colors.blue,
                      // height: 20,
                      child: Column(
                        children: widget.content,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            widget.deliveredReceipt
          ],
        ),
        widget.message.guid.startsWith("error")
            ? CupertinoButton(
                padding: EdgeInsets.all(0),
                onPressed: () {},
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                ),
              )
            : Container(),
      ],
    );
  }
}
