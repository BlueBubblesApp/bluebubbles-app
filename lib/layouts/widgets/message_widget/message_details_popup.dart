import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:keyboard_visibility/keyboard_visibility.dart';
import 'package:sprung/sprung.dart';

class MessageDetailsPopup extends StatefulWidget {
  MessageDetailsPopup({
    Key key,
    @required this.message,
    @required this.childOffset,
    @required this.childSize,
    @required this.child,
    @required this.currentChat,
  }) : super(key: key);
  final Message message;

  final Offset childOffset;
  final Size childSize;
  final Widget child;
  final CurrentChat currentChat;

  @override
  MessageDetailsPopupState createState() => MessageDetailsPopupState();
}

class MessageDetailsPopupState extends State<MessageDetailsPopup>
    with TickerProviderStateMixin {
  List<Widget> reactionWidgets = <Widget>[];
  bool showTools = false;
  Completer fetchRequest;
  CurrentChat currentChat;

  double messageTopOffset;
  double topMinimum;
  double bottomMaximum;

  @override
  void initState() {
    super.initState();
    currentChat = widget.currentChat;
    // KeyboardVisibilityNotification().addNewListener(
    //   onHide: () {
    //     Navigator.of(context).pop();
    //   },
    // );

    messageTopOffset = widget.childOffset.dy;
    topMinimum = CupertinoNavigationBar().preferredSize.height + 20;

    fetchReactions();

    // Animate showing the copy menu, slightly delayed
    Future.delayed(Duration(milliseconds: 50), () {
      if (this.mounted)
        setState(() {
          showTools = true;
        });
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (this.mounted) {
        setState(() {
          messageTopOffset =
              widget.childOffset.dy.clamp(topMinimum + 40, double.infinity);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchReactions();
  }

  Future<void> fetchReactions() async {
    if (fetchRequest != null && !fetchRequest.isCompleted) {
      return fetchRequest.future;
    }

    // Create a new fetch request
    fetchRequest = new Completer();

    // If there are no associated messages, return now
    List<Message> reactions = widget.message.getReactions();
    if (reactions.isEmpty) return fetchRequest.complete();

    // Filter down the messages to the unique ones (one per user, newest)
    List<Message> reactionMessages =
        Reaction.getUniqueReactionMessages(reactions);

    reactionWidgets = [];
    for (Message reaction in reactionMessages) {
      await reaction.getHandle();
      reactionWidgets.add(
        ReactionDetailWidget(
          handle: reaction.handle,
          message: reaction,
        ),
      );
    }

    // If we aren't mounted, get out
    if (!this.mounted) return fetchRequest.complete();

    // Tell the component to re-render
    this.setState(() {});
    return fetchRequest.complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Material(
            //   color: Colors.transparent,
            //   child: TextField(
            //     cursorColor: Colors.transparent,
            //     decoration: InputDecoration(
            //       fillColor: Colors.transparent,
            //       border: InputBorder.none,
            //     ),
            //     autofocus: MediaQuery.of(context).viewInsets.bottom > 0,
            //   ),
            // ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: Duration(milliseconds: 250),
              top: messageTopOffset,
              left: widget.childOffset.dx,
              child: Container(
                width: widget.childSize.width,
                height: widget.childSize.height,
                child: widget.child,
              ),
            ),
            buildReactionMenu(),
            buildCopyPasteMenu(),

            // Positioned.fill(
            //   child: GestureDetector(
            //     behavior: HitTestBehavior.deferToChild,
            //     onTap: () {
            //       widget.entry.remove();
            //     },
            //     child: Container(
            //       color: Colors.black.withAlpha(200),
            //       child: Column(
            //         children: <Widget>[
            //           Container(height: 45.0),
            //           AnimatedSize(
            //             vsync: this,
            //             duration: Duration(milliseconds: 500),
            //             curve: Sprung(damped: Damped.under),
            //             alignment: Alignment.center,
            //             child: reactionWidgets.length > 0
            //                 ? ClipRRect(
            //                     borderRadius: BorderRadius.circular(20),
            //                     child: BackdropFilter(
            //                       filter:
            //                           ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            //                       child: Container(
            //                         alignment: Alignment.center,
            //                         height: 120,
            //                         width:
            //                             MediaQuery.of(context).size.width - 20,
            //                         color: Theme.of(context).accentColor,
            //                         child: Padding(
            //                           padding:
            //                               EdgeInsets.symmetric(horizontal: 0),
            //                           child: ListView.builder(
            //                             shrinkWrap: true,
            //                             physics: AlwaysScrollableScrollPhysics(
            //                               parent: CustomBouncingScrollPhysics(),
            //                             ),
            //                             scrollDirection: Axis.horizontal,
            //                             itemBuilder: (context, index) {
            //                               return reactionWidgets[index];
            //                             },
            //                             itemCount: reactionWidgets.length,
            //                           ),
            //                         ),
            //                       ),
            //                     ),
            //                   )
            //                 : Container(),
            //           ),
            //           Container(
            //             height: 10.0,
            //           ),
            //           AnimatedSize(
            //             duration: Duration(milliseconds: 500),
            //             curve: Sprung(damped: Damped.under),
            //             vsync: this,
            //             child: showTools
            //                 ? ClipRRect(
            //                     borderRadius: BorderRadius.circular(20),
            //                     child: BackdropFilter(
            //                       filter:
            //                           ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            //                       child: Container(
            //                         alignment: Alignment.center,
            //                         height: 60,
            //                         width:
            //                             MediaQuery.of(context).size.width - 20,
            //                         color: Theme.of(context).accentColor,
            //                         child: Container(
            //                           width: MediaQuery.of(context).size.width -
            //                               20,
            //                           child: Row(
            //                             mainAxisAlignment:
            //                                 MainAxisAlignment.spaceEvenly,
            //                             mainAxisSize: MainAxisSize.max,
            //                             children: <Widget>[
            //                               FlatButton(
            //                                 splashColor:
            //                                     Theme.of(context).splashColor,
            //                                 child: Row(
            //                                   mainAxisSize: MainAxisSize.min,
            //                                   children: <Widget>[
            //                                     Padding(
            //                                       padding:
            //                                           const EdgeInsets.all(8.0),
            //                                       child: Icon(
            //                                         Icons.content_paste,
            //                                         color: Theme.of(context)
            //                                             .textTheme
            //                                             .bodyText1
            //                                             .color,
            //                                       ),
            //                                     ),
            //                                     Text(
            //                                       "Copy",
            //                                       style: Theme.of(context)
            //                                           .textTheme
            //                                           .bodyText1,
            //                                     ),
            //                                   ],
            //                                 ),
            //                                 onPressed: () {
            //                                   if (!isEmptyString(
            //                                       widget.message.text))
            //                                     FlutterClipboard.copy(
            //                                         widget.message.text);
            //                                   FlutterToast flutterToast =
            //                                       FlutterToast(context);
            //                                   Widget toast = ClipRRect(
            //                                     borderRadius:
            //                                         BorderRadius.circular(25.0),
            //                                     child: BackdropFilter(
            //                                       filter: ImageFilter.blur(
            //                                           sigmaX: 15, sigmaY: 15),
            //                                       child: Container(
            //                                         padding: const EdgeInsets
            //                                                 .symmetric(
            //                                             horizontal: 24.0,
            //                                             vertical: 12.0),
            //                                         decoration: BoxDecoration(
            //                                           borderRadius:
            //                                               BorderRadius.circular(
            //                                                   25.0),
            //                                           color: Theme.of(context)
            //                                               .accentColor
            //                                               .withOpacity(0.1),
            //                                         ),
            //                                         child: Row(
            //                                           mainAxisSize:
            //                                               MainAxisSize.min,
            //                                           children: [
            //                                             Icon(
            //                                               !isEmptyString(widget
            //                                                       .message.text)
            //                                                   ? Icons.check
            //                                                   : Icons.close,
            //                                               color:
            //                                                   Theme.of(context)
            //                                                       .textTheme
            //                                                       .bodyText1
            //                                                       .color,
            //                                             ),
            //                                             SizedBox(
            //                                               width: 12.0,
            //                                             ),
            //                                             Text(
            //                                               !isEmptyString(widget
            //                                                       .message.text)
            //                                                   ? "Copied to clipboard"
            //                                                   : "Failed to copy empty message",
            //                                               style:
            //                                                   Theme.of(context)
            //                                                       .textTheme
            //                                                       .bodyText1,
            //                                             ),
            //                                           ],
            //                                         ),
            //                                       ),
            //                                     ),
            //                                   );

            //                                   flutterToast.showToast(
            //                                     child: toast,
            //                                     gravity: ToastGravity.BOTTOM,
            //                                     toastDuration:
            //                                         Duration(seconds: 2),
            //                                   );
            //                                 },
            //                               ),
            //                               FlatButton(
            //                                 splashColor:
            //                                     Theme.of(context).splashColor,
            //                                 child: Row(
            //                                   mainAxisSize: MainAxisSize.min,
            //                                   children: <Widget>[
            //                                     Padding(
            //                                       padding:
            //                                           const EdgeInsets.all(8.0),
            //                                       child: Icon(
            //                                         Icons.content_paste,
            //                                         color: Theme.of(context)
            //                                             .textTheme
            //                                             .bodyText1
            //                                             .color,
            //                                       ),
            //                                     ),
            //                                     Container(
            //                                       width: 70,
            //                                       child: Text(
            //                                         "Copy Section",
            //                                         textAlign: TextAlign.center,
            //                                         style: Theme.of(context)
            //                                             .textTheme
            //                                             .bodyText1,
            //                                       ),
            //                                     ),
            //                                   ],
            //                                 ),
            //                                 onPressed: () {
            //                                   if (isEmptyString(
            //                                       widget.message.text)) return;
            //                                   widget.entry.remove();
            //                                   showDialog(
            //                                     context: context,
            //                                     builder: (context) =>
            //                                         AlertDialog(
            //                                       backgroundColor:
            //                                           Theme.of(context)
            //                                               .accentColor,
            //                                       title: Text(
            //                                         "Copy",
            //                                         style: Theme.of(context)
            //                                             .textTheme
            //                                             .headline1,
            //                                       ),
            //                                       content: Container(
            //                                         constraints: BoxConstraints(
            //                                             maxHeight:
            //                                                 MediaQuery.of(
            //                                                             context)
            //                                                         .size
            //                                                         .height *
            //                                                     2 /
            //                                                     3),
            //                                         child:
            //                                             SingleChildScrollView(
            //                                           physics:
            //                                               AlwaysScrollableScrollPhysics(
            //                                             parent:
            //                                                 CustomBouncingScrollPhysics(),
            //                                           ),
            //                                           child: SelectableText(
            //                                             widget.message.text,
            //                                             style: Theme.of(context)
            //                                                 .textTheme
            //                                                 .bodyText1,
            //                                           ),
            //                                         ),
            //                                       ),
            //                                       actions: <Widget>[
            //                                         FlatButton(
            //                                           child: Text(
            //                                             "Done",
            //                                             style: Theme.of(context)
            //                                                 .textTheme
            //                                                 .bodyText1,
            //                                           ),
            //                                           onPressed: () {
            //                                             Navigator.of(context,
            //                                                     rootNavigator:
            //                                                         true)
            //                                                 .pop('dialog');
            //                                           },
            //                                         )
            //                                       ],
            //                                     ),
            //                                   );
            //                                 },
            //                               ),
            //                             ],
            //                           ),
            //                         ),
            //                       ),
            //                     ),
            //                   )
            //                 : Container(),
            //           ),
            //           Spacer(
            //             flex: 20,
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget buildReactionMenu() {
    Size size = MediaQuery.of(context).size;

    double reactionIconSize = ((MessageWidgetMixin.MAX_SIZE * size.width) /
        (ReactionTypes.toList().length).toDouble());
    double maxMenuWidth =
        (ReactionTypes.toList().length * reactionIconSize).toDouble();
    double menuHeight = (reactionIconSize).toDouble();

    double topPadding = -5;

    double topOffset = (widget.childOffset.dy - menuHeight).toDouble().clamp(
        topMinimum,
        size.height -
            MediaQuery.of(context).viewInsets.bottom -
            120 -
            menuHeight);
    double leftOffset = (widget.message.isFromMe
            ? size.width - maxMenuWidth - 25
            : 25 + (currentChat.chat.isGroup() ? 20 : 0))
        .toDouble();
    Color iconColor = Colors.white;
    if (Theme.of(context).accentColor.computeLuminance() >= 0.179) {
      iconColor = Colors.black.withAlpha(95);
    }
    return Positioned(
      top: topOffset + topPadding,
      left: leftOffset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(5),
            height: menuHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).accentColor.withAlpha(150),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: ReactionTypes.toList()
                  .map(
                    (e) => Container(
                      width: reactionIconSize,
                      height: reactionIconSize,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Reaction.getReactionIcon(e, iconColor),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCopyPasteMenu() {
    Size size = MediaQuery.of(context).size;

    double maxMenuWidth = size.width * 2 / 3;
    Widget menu = ClipRRect(
      borderRadius: BorderRadius.circular(25.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Theme.of(context).accentColor.withAlpha(150),
          width: maxMenuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: ListTile(
                    title: Text("Copy",
                        style: Theme.of(context).textTheme.bodyText1),
                    trailing: Icon(
                      Icons.content_copy,
                      color: Theme.of(context).textTheme.bodyText1.color,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: ListTile(
                    title: Text("Copy Selection",
                        style: Theme.of(context).textTheme.bodyText1),
                    trailing: Icon(
                      Icons.content_copy,
                      color: Theme.of(context).textTheme.bodyText1.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    double menuHeight = 100;

    double topOffset = (widget.childOffset.dy + widget.childSize.height)
        .toDouble()
        .clamp(
            topMinimum,
            size.height -
                MediaQuery.of(context).viewInsets.bottom -
                menuHeight -
                20);
    double leftOffset = (widget.message.isFromMe
            ? size.width - maxMenuWidth - 15
            : 25 + (currentChat.chat.isGroup() ? 20 : 0))
        .toDouble();
    return Positioned(
      top: topOffset,
      left: leftOffset,
      child: menu,
    );
  }
}
