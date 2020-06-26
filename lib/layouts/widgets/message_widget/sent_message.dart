import 'dart:convert';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/main.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final OverlayEntry overlayEntry;
  final List<Widget> content;
  final Widget deliveredReceipt;
  final bool shouldFadeIn;

  final String substituteText;
  final bool limited;
  SentMessage({
    Key key,
    @required this.showTail,
    @required this.message,
    @required this.content,
    @required this.overlayEntry,
    @required this.deliveredReceipt,
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
                  color: Colors.black.withAlpha(200),
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
                                      style: TextStyle(color: Colors.white)),
                                  Text("Error: $errorText",
                                      style: TextStyle(color: Colors.white))
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

    double bottomPadding = isEmptyString(widget.message != null
            ? widget.message.text
            : widget.substituteText)
        ? 0
        : 8;
    double sidePadding = !isEmptyString(widget.message != null
                ? widget.message.text
                : widget.substituteText) &&
            widget.content.length > 0 &&
            widget.content[0] is Text
        ? 14
        : 0;
    double topPadding = !isEmptyString(widget.message != null
                ? widget.message.text
                : widget.substituteText) &&
            widget.content.length > 0 &&
            widget.content[0] is Text
        ? 8
        : 0;
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
              margin: EdgeInsets.symmetric(horizontal: 10),
              constraints: BoxConstraints(
                maxWidth: widget.limited != null && !widget.limited
                    ? MediaQuery.of(context).size.width * (5 / 6)
                    : MediaQuery.of(context).size.width * 3 / 4,
              ),
              padding: EdgeInsets.only(
                  top: topPadding,
                  bottom: bottomPadding,
                  left: sidePadding,
                  right: sidePadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.blue[600],
              ),
              // color: Colors.blue,
              // height: 20,
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
          )
        ],
      )
    ];

    if (widget.message != null && widget.message.error > 0)
      messageWidget.add(
        GestureDetector(
          onTap: () {
            Overlay.of(context).insert(this._createErrorPopup());
          },
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );

    // Icon(Icons.accessible_forward, color: Colors.white),
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: Duration(milliseconds: widget.shouldFadeIn ? 200 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(
                    bottom: widget.showTail ? 10.0 : 3.0,
                    right: (widget.message != null && widget.message.error > 0
                        ? 10.0
                        : 0)),
                child: Row(children: messageWidget),
              ),
              widget.deliveredReceipt
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
