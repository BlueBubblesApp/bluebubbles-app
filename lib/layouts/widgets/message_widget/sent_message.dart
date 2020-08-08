import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:bluebubble_messages/action_handler.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/reactions.dart';
import 'package:bluebubble_messages/main.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SentMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  // final OverlayEntry overlayEntry;
  final bool shouldFadeIn;
  final Map<String, String> timeStamp;
  final bool showDeliveredReceipt;
  final List<Widget> customContent;
  final bool isFromMe;
  final Widget attachments;
  final bool showHero;
  final double offset;

  final String substituteText;
  final bool limited;
  SentMessage({
    Key key,
    @required this.showTail,
    @required this.message,
    // @required this.overlayEntry,
    @required this.timeStamp,
    @required this.showDeliveredReceipt,
    @required this.customContent,
    @required this.isFromMe,
    @required this.attachments,
    this.substituteText,
    this.limited,
    this.shouldFadeIn,
    this.showHero,
    this.offset,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage>
    with TickerProviderStateMixin {
  // bool _visible = false;

  @override
  void initState() {
    super.initState();
    // _visible = !widget.shouldFadeIn;
    // Future.delayed(Duration(milliseconds: 50), () {
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
    debugPrint(errorText);

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
                                Column(
                                  children: <Widget>[
                                    Text("Error Code: ${errorCode.toString()}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1),
                                    Text(
                                      "Error: $errorText",
                                      style:
                                          Theme.of(context).textTheme.bodyText1,
                                    )
                                  ],
                                ),
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
    Color blueColor =
        widget.message == null || widget.message.guid.startsWith("temp")
            ? darken(Colors.blue[600], 0.2)
            : Colors.blue[600];

    List<InlineSpan> textSpans = <InlineSpan>[];

    if (widget.message != null && !isEmptyString(widget.message.text)) {
      RegExp exp =
          new RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%@&]+');
      List<RegExpMatch> matches = exp.allMatches(widget.message.text).toList();

      List<int> linkIndexMatches = <int>[];
      matches.forEach((match) {
        linkIndexMatches.add(match.start);
        linkIndexMatches.add(match.end);
      });
      if (linkIndexMatches.length > 0) {
        for (int i = 0; i < linkIndexMatches.length + 1; i++) {
          if (i == 0) {
            textSpans.add(
              TextSpan(
                  text: widget.message.text.substring(0, linkIndexMatches[i])),
            );
          } else if (i == linkIndexMatches.length && i - 1 >= 0) {
            textSpans.add(
              TextSpan(
                text: widget.message.text.substring(
                    linkIndexMatches[i - 1], widget.message.text.length),
              ),
            );
          } else if (i - 1 >= 0) {
            String text = widget.message.text
                .substring(linkIndexMatches[i - 1], linkIndexMatches[i]);
            if (exp.hasMatch(text)) {
              textSpans.add(
                TextSpan(
                  text: text,
                  recognizer: new TapGestureRecognizer()
                    ..onTap = () async {
                      String url = text;
                      if (!url.startsWith("http://") &&
                          !url.startsWith("https://")) {
                        url = "http://" + url;
                      }
                      debugPrint("opening url " + url);
                      MethodChannelInterface()
                          .invokeMethod("open-link", {"link": url});
                    },
                  style: Theme.of(context).textTheme.bodyText2.apply(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                ),
              );
            } else {
              textSpans.add(
                TextSpan(
                  text: text,
                ),
              );
            }
          }
        }
      } else {
        textSpans.add(
          TextSpan(
            text: widget.message.text,
          ),
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () async {
        // Scrollable.ensureVisible(
        //   context,
        //   // alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        //   duration: Duration(milliseconds: 250),
        //   curve: Curves.easeInOut,
        // );
        List<Message> reactions = [];
        if (widget.message.hasReactions) {
          reactions = await widget.message.getReactions();
        }
        // if (widget.overlayEntry != null)
        Overlay.of(context).insert(_createMessageDetailsPopup(reactions));
      },
      child: AnimatedOpacity(
        opacity: 1.0, //_visible ? 1.0 : 0.0,
        duration: Duration(milliseconds: widget.shouldFadeIn ? 200 : 0),
        child: Column(
          children: <Widget>[
            widget.attachments != null ? widget.attachments : Container(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AnimatedPadding(
                  curve: Curves.easeInOut,
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.only(
                    bottom: widget.showTail ? 10.0 : 3.0,
                    right: (widget.message != null && widget.message.error > 0
                        ? 10.0
                        : 0),
                  ),
                  child: Stack(
                    alignment: Alignment.topLeft,
                    children: <Widget>[
                      AnimatedPadding(
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.only(
                          left: widget.message != null &&
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
                        child: widget.showHero
                            ? Hero(
                                tag: "first",
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: ActualSentMessage(
                                    blueColor: blueColor,
                                    createErrorPopup: this._createErrorPopup,
                                    customContent: widget.customContent,
                                    message: widget.message,
                                    showTail: widget.showTail,
                                    textSpans: textSpans,
                                  ),
                                ),
                              )
                            : ActualSentMessage(
                                blueColor: blueColor,
                                createErrorPopup: this._createErrorPopup,
                                customContent: widget.customContent,
                                message: widget.message,
                                showTail: widget.showTail,
                                textSpans: textSpans,
                              ),
                      ),
                      widget.message != null && !widget.message.hasAttachments
                          ? Reactions(
                              message: widget.message,
                            )
                          : Container(),
                    ],
                  ),
                ),
                AnimatedContainer(
                  width: (-widget.offset).clamp(0, 70).toDouble(),
                  duration:
                      Duration(milliseconds: widget.offset == 0 ? 150 : 0),
                  child: Text(
                    DateFormat('h:mm a')
                        .format(widget.message.dateCreated)
                        .toLowerCase(),
                    style: Theme.of(context).textTheme.subtitle1,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                )
              ],
            ),
            DeliveredReceipt(
              message: widget.message,
              showDeliveredReceipt: widget.showDeliveredReceipt,
            ),
            widget.timeStamp != null
                ? Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: RichText(
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
                                .apply(fontSizeDelta: 1.7, fontWeightDelta: 10),
                          ),
                          TextSpan(text: "${widget.timeStamp["time"]}")
                        ],
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  OverlayEntry _createMessageDetailsPopup(List<Message> reactions) {
    OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => MessageDetailsPopup(
        entry: entry,
        reactions: reactions,
        message: widget.message,
      ),
    );
    return entry;
  }
}

class ActualSentMessage extends StatefulWidget {
  ActualSentMessage({
    Key key,
    @required this.blueColor,
    @required this.showTail,
    @required this.message,
    @required this.customContent,
    @required this.textSpans,
    @required this.createErrorPopup,
    this.constrained,
  }) : super(key: key);
  final Color blueColor;
  final bool showTail;
  final Message message;
  final List<Widget> customContent;
  final List<InlineSpan> textSpans;
  final Function() createErrorPopup;
  final bool constrained;

  @override
  _ActualSentMessageState createState() => _ActualSentMessageState();
}

class _ActualSentMessageState extends State<ActualSentMessage> {
  @override
  Widget build(BuildContext context) {
    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: widget.blueColor,
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
      widget.message == null || !isEmptyString(widget.message.text)
          ? Stack(
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
                    maxWidth: widget.constrained == null
                        ? MediaQuery.of(context).size.width * 3 / 4
                        : MediaQuery.of(context).size.width * 3 / 4 + 37,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: widget.blueColor,
                  ),
                  child: widget.customContent == null
                      ? Container(
                          child: RichText(
                            text: TextSpan(
                              children: widget.textSpans,
                              style:
                                  Theme.of(context).textTheme.bodyText2.apply(
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        )
                      : widget.customContent.first,
                ),
              ],
            )
          : Container()
    ];

    if (widget.message != null && widget.message.error > 0)
      messageWidget.add(
        // ButtonTheme(
        //   minWidth: 1,
        //   height: 1,
        //   child: CupertinoButton(
        //     onPressed: () {
        //       Overlay.of(context).insert(widget.createErrorPopup());
        //     },
        //     child: Icon(Icons.error_outline, color: Colors.red),
        //   ),
        // ),
        GestureDetector(
          onTap: () {
            Overlay.of(context).insert(widget.createErrorPopup());
          },
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: messageWidget,
    );
  }
}
