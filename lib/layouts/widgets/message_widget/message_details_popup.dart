import 'dart:ui';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sprung/sprung.dart';

class MessageDetailsPopup extends StatefulWidget {
  MessageDetailsPopup({Key key, this.entry, this.reactions, this.message})
      : super(key: key);
  final OverlayEntry entry;
  final List<Message> reactions;
  final Message message;

  @override
  _MessageDetailsPopupState createState() => _MessageDetailsPopupState();
}

class _MessageDetailsPopupState extends State<MessageDetailsPopup>
    with TickerProviderStateMixin {
  List<Widget> reactionWidgets = <Widget>[];
  bool showTools = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 50), () {
      if (this.mounted)
        setState(() {
          showTools = true;
        });
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    for (Message reaction in widget.reactions) {
      await reaction.getHandle();
      reactionWidgets.add(
        ReactionDetailWidget(
          handle: reaction.handle,
          message: reaction,
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () {
                widget.entry.remove();
              },
              child: Container(
                color: Colors.black.withAlpha(200),
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 45.0
                    ),
                    AnimatedSize(
                      vsync: this,
                      duration: Duration(milliseconds: 500),
                      curve: Sprung(damped: Damped.under),
                      alignment: Alignment.center,
                      child: reactionWidgets.length > 0
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: 120,
                                  width: MediaQuery.of(context).size.width - 20,
                                  color: Theme.of(context).accentColor,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 0),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) {
                                        return reactionWidgets[index];
                                      },
                                      itemCount: reactionWidgets.length,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ),
                    Container(
                      height: 10.0,
                    ),
                    AnimatedSize(
                      duration: Duration(milliseconds: 500),
                      curve: Sprung(damped: Damped.under),
                      vsync: this,
                      child: showTools
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: 60,
                                  width: MediaQuery.of(context).size.width - 20,
                                  color: Theme.of(context).accentColor,
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width - 20,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        FlatButton(
                                          splashColor:
                                              Theme.of(context).splashColor,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.content_paste,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyText1
                                                      .color,
                                                ),
                                              ),
                                              Text(
                                                "Copy",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText1,
                                              ),
                                            ],
                                          ),
                                          onPressed: () {
                                            if (!isEmptyString(
                                                widget.message.text))
                                              FlutterClipboard.copy(
                                                  widget.message.text);
                                            FlutterToast flutterToast =
                                                FlutterToast(context);
                                            Widget toast = ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(25.0),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 15, sigmaY: 15),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 24.0,
                                                      vertical: 12.0),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            25.0),
                                                    color: Theme.of(context)
                                                        .accentColor
                                                        .withOpacity(0.1),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        !isEmptyString(widget
                                                                .message.text)
                                                            ? Icons.check
                                                            : Icons.close,
                                                        color: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1
                                                            .color,
                                                      ),
                                                      SizedBox(
                                                        width: 12.0,
                                                      ),
                                                      Text(
                                                        !isEmptyString(widget
                                                                .message.text)
                                                            ? "Copied to clipboard"
                                                            : "Failed to copy empty message",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );

                                            flutterToast.showToast(
                                              child: toast,
                                              gravity: ToastGravity.BOTTOM,
                                              toastDuration:
                                                  Duration(seconds: 2),
                                            );
                                          },
                                        ),
                                        FlatButton(
                                          splashColor:
                                              Theme.of(context).splashColor,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.content_paste,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyText1
                                                      .color,
                                                ),
                                              ),
                                              Container(
                                                width: 70,
                                                child: Text(
                                                  "Copy Section",
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onPressed: () {
                                            if (isEmptyString(
                                                widget.message.text)) return;
                                            widget.entry.remove();
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .accentColor,
                                                title: Text(
                                                  "Copy",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline1,
                                                ),
                                                content: Container(
                                                  constraints: BoxConstraints(
                                                      maxHeight:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              2 /
                                                              3),
                                                  child: SingleChildScrollView(
                                                    physics:
                                                        AlwaysScrollableScrollPhysics(
                                                      parent:
                                                          BouncingScrollPhysics(),
                                                    ),
                                                    child: SelectableText(
                                                      widget.message.text,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1,
                                                    ),
                                                  ),
                                                ),
                                                actions: <Widget>[
                                                  FlatButton(
                                                    child: Text(
                                                      "Done",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context,
                                                              rootNavigator:
                                                                  true)
                                                          .pop('dialog');
                                                    },
                                                  )
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ),
                    Spacer(
                      flex: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
