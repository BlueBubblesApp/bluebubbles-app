import 'dart:convert';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/message_content.dart';
import 'package:bluebubble_messages/main.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final OverlayEntry overlayEntry;
  final bool shouldFadeIn;
  final Widget timeStamp;
  final bool showDeliveredReceipt;
  final List<Widget> customContent;
  final bool isFromMe;
  final Widget attachments;

  final String substituteText;
  final bool limited;
  SentMessage({
    Key key,
    @required this.showTail,
    @required this.message,
    @required this.overlayEntry,
    @required this.timeStamp,
    @required this.showDeliveredReceipt,
    @required this.customContent,
    @required this.isFromMe,
    @required this.attachments,
    this.substituteText,
    this.limited,
    this.shouldFadeIn,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage>
    with AutomaticKeepAliveClientMixin {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = !widget.shouldFadeIn;
    // Future.delayed(Duration(milliseconds: 100), () {
    //   setState(() {
    //     _visible = true;
    //   });
    // });
  }

  OverlayEntry _createErrorPopup() {
    OverlayEntry entry;
    int errorCode = widget.message != null ? widget.message.error : 0;
    String errorText =
        widget.message != null ? widget.message.guid.split('-')[1] : "";

    entry = OverlayEntry(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => entry.remove(),
                child: Container(
                  color: Theme.of(context).backgroundColor.withAlpha(200),
                  child: Column(
                    children: <Widget>[
                      Spacer(
                        flex: 3,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 120,
                            width: MediaQuery.of(context).size.width * 9 / 5,
                            color: HexColor('26262a').withAlpha(200),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Column(children: <Widget>[
                                  Text("Error Code: ${errorCode.toString()}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText1),
                                  Text("Error: $errorText",
                                      style:
                                          Theme.of(context).textTheme.bodyText1)
                                ]),
                                CupertinoButton(
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Text("Retry"),
                                          Container(width: 5.0),
                                          Icon(Icons.refresh,
                                              color: Colors.white, size: 18)
                                        ]),
                                    color: Colors.black26,
                                    onPressed: () async {
                                      if (widget.message != null)
                                        ActionHandler.retryMessage(
                                            widget.message);
                                      entry.remove();
                                    })
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return entry;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: Colors.blue[600],
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Theme.of(context).backgroundColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Theme.of(context).backgroundColor,
      ),
    ];
    if (widget.showTail) {
      stack.insertAll(0, tail);
    }

    List<Widget> messageWidget = [
      Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: <Widget>[
          Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: stack,
          ),
          GestureDetector(
            onLongPress: () {
              if (widget.overlayEntry != null)
                Overlay.of(context).insert(widget.overlayEntry);
            },
            child: Container(
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
                color: !widget.isFromMe
                    ? Theme.of(context).accentColor
                    : Colors.blue,
              ),
              child: Text(widget.message.text),
            ),
          ),
        ],
      )
    ];

    if (widget.message != null && widget.message.error > 0)
      messageWidget.add(
        CupertinoButton(
          onPressed: () {
            Overlay.of(context).insert(this._createErrorPopup());
          },
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: widget.shouldFadeIn ? 200 : 0),
      child: Column(
        children: <Widget>[
          widget.attachments,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: widget.showTail ? 10.0 : 3.0,
                        right:
                            (widget.message != null && widget.message.error > 0
                                ? 10.0
                                : 0)),
                    child: Row(children: messageWidget),
                  ),
                  widget.showDeliveredReceipt
                      ? DeliveredReceipt(message: widget.message)
                      : Container(),
                ],
              ),
            ],
          ),
          widget.timeStamp,
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
