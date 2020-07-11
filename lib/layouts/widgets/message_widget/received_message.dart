import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/message_content.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/reactions.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  // final OverlayEntry overlayEntry;
  final Map<String, String> timeStamp;
  final bool showHandle;
  final List<Widget> customContent;
  final bool isFromMe;
  final Widget attachments;

  ReceivedMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    // @required this.overlayEntry,
    @required this.timeStamp,
    @required this.showHandle,
    @required this.customContent,
    @required this.isFromMe,
    @required this.attachments,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> {
  @override
  Widget build(BuildContext context) {
    String handle = "";
    if (widget.message.handle != null && widget.showHandle) {
      handle = getContactTitle(
          widget.message.handleId, widget.message.handle.address);
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

    List<Widget> messageWidget = [
      widget.message == null || !isEmptyString(widget.message.text)
          ? Stack(
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
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).accentColor),
                    child: Text(
                      widget.message.text,
                      style: Theme.of(context).textTheme.bodyText1,
                    )),
              ],
            )
          : Container()
    ];

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

    return GestureDetector(
      onLongPress: () {
        // Overlay.of(context).insert(widget.overlayEntry);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          contactItem,
          widget.attachments,
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(bottom: widget.showTail ? 10.0 : 3.0),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: <Widget>[
                    AnimatedPadding(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.only(
                        right: widget.message != null &&
                                widget.message.hasReactions &&
                                !widget.message.hasAttachments
                            ? 6.0
                            : 0.0,
                        top: widget.message != null &&
                                widget.message.hasReactions &&
                                !widget.message.hasAttachments
                            ? 14.0
                            : 0.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: messageWidget,
                      ),
                    ),
                    !widget.message.hasAttachments
                        ? Reactions(
                            message: widget.message,
                          )
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
          widget.timeStamp != null
              ? Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .subtitle2
                              .apply(fontSizeDelta: 1.7),
                          children: [
                            TextSpan(
                              text: "${widget.timeStamp["date"]}, ",
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle2
                                  .apply(
                                      fontSizeDelta: 1.7, fontWeightDelta: 10),
                            ),
                            TextSpan(text: "${widget.timeStamp["time"]}")
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Container()
        ],
      ),
    );
  }
}
