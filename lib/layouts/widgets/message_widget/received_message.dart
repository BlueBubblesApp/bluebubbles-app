import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final OverlayEntry overlayEntry;
  final List<Widget> content;
  final Widget timeStamp;
  final Widget reactions;
  final bool showHandle;

  ReceivedMessage(
      {Key key,
      @required this.showTail,
      @required this.olderMessage,
      @required this.message,
      @required this.content,
      @required this.overlayEntry,
      @required this.timeStamp,
      @required this.reactions,
      @required this.showHandle})
      : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> {
  @override
  Widget build(BuildContext context) {
    String handle = "";
    if (widget.message.handle != null && widget.showHandle) {
      handle = getContactTitle(
          ContactManager().contacts, widget.message.handle.address);
    }

    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: Theme.of(context).accentColor,
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Theme.of(context).backgroundColor,
      )
    ];
    if (widget.showTail) {
      stack.insertAll(0, tail);
    }

    Widget contactItem = new Container(width: 0, height: 0);
    if (!sameSender(widget.message, widget.olderMessage)) {
      contactItem = Padding(
        padding: EdgeInsets.only(left: 25.0, top: 5.0, bottom: 3.0),
        child: Text(
          handle,
          style: Theme.of(context).textTheme.bodyText1,
        ),
      );
    }

    double bottomPadding = isEmptyString(widget.message.text) ? 0 : 8;
    double sidePadding = !isEmptyString(widget.message.text) &&
            widget.content.length > 0 &&
            widget.content[0] is Text
        ? 14
        : 0;
    double topPadding = !isEmptyString(widget.message.text) &&
            widget.content.length > 0 &&
            widget.content[0] is Text
        ? 8
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        widget.timeStamp,
        contactItem,
        widget.reactions,
        GestureDetector(
          onLongPress: () {
            debugPrint(widget.message.handleId.toString());
            Overlay.of(context).insert(widget.overlayEntry);
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.showTail ? 10.0 : 3.0),
            child: Stack(
              alignment: AlignmentDirectional.bottomStart,
              children: <Widget>[
                Stack(
                  alignment: AlignmentDirectional.bottomStart,
                  children: stack,
                ),
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 3 / 4,
                  ),
                  padding: EdgeInsets.only(
                      top: topPadding,
                      bottom: bottomPadding,
                      left: sidePadding,
                      right: sidePadding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).accentColor,
                  ),
                  child: ClipRRect(
                    borderRadius:
                        (widget.content.length > 0 && widget.content[0] is Text)
                            ? BorderRadius.circular(0)
                            : BorderRadius.circular(20),
                    child: Column(
                      children: widget.content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
