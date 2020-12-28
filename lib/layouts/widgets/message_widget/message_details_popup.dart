import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  String selfReaction;
  String currentlySelectedReaction;
  Completer fetchRequest;
  CurrentChat currentChat;

  double messageTopOffset;
  double topMinimum;

  @override
  void initState() {
    super.initState();
    currentChat = widget.currentChat;

    messageTopOffset = widget.childOffset.dy;
    topMinimum = CupertinoNavigationBar().preferredSize.height +
        (widget.message.hasReactions ? 110 : 50);

    fetchReactions();

    // Animate showing the copy menu, slightly delayed
    Future.delayed(Duration(milliseconds: 50), () {
      if (this.mounted)
        setState(() {
          showTools = true;
        });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchReactions();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (this.mounted) {
        double menuHeight = 150;
        if (showDownload) {
          menuHeight += 70;
        }
        setState(() {
          double totalHeight = MediaQuery.of(context).size.height -
              MediaQuery.of(context).viewInsets.bottom -
              menuHeight -
              20;
          double offset =
              (widget.childOffset.dy + widget.childSize.height) - totalHeight;
          messageTopOffset =
              widget.childOffset.dy.clamp(topMinimum + 40, double.infinity);
          if (offset > 0) {
            messageTopOffset -= offset;
            messageTopOffset =
                messageTopOffset.clamp(topMinimum + 40, double.infinity);
          }
        });
      }
    });
  }

  Future<void> fetchReactions() async {
    if (fetchRequest != null && !fetchRequest.isCompleted) {
      return fetchRequest.future;
    }

    // Create a new fetch request
    fetchRequest = new Completer();

    // If there are no associated messages, return now
    List<Message> reactions = widget.message.getReactions();
    if (reactions.isEmpty) {
      return fetchRequest.complete();
    }

    // Filter down the messages to the unique ones (one per user, newest)
    List<Message> reactionMessages =
        Reaction.getUniqueReactionMessages(reactions);

    reactionWidgets = [];
    for (Message reaction in reactionMessages) {
      await reaction.getHandle();
      if (reaction.isFromMe) {
        selfReaction = reaction.associatedMessageType;
        currentlySelectedReaction = selfReaction;
      }
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

  void sendReaction(String type) {
    debugPrint("Sending reaction type: " + type);
    ActionHandler.sendReaction(widget.currentChat.chat, widget.message, type);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: oledDarkTheme.accentColor.withOpacity(0.3),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOut,
                top: messageTopOffset,
                left: widget.childOffset.dx,
                child: Container(
                  width: widget.childSize.width,
                  height: widget.childSize.height,
                  child: widget.child,
                ),
              ),
              Positioned(
                top: 40,
                left: 10,
                child: AnimatedSize(
                  vsync: this,
                  duration: Duration(milliseconds: 500),
                  curve: Sprung(damped: Damped.under),
                  alignment: Alignment.center,
                  child: reactionWidgets.length > 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              alignment: Alignment.center,
                              height: 120,
                              width: MediaQuery.of(context).size.width - 20,
                              color: Theme.of(context).accentColor,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: ThemeSwitcher.getScrollPhysics(),
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
              ),
              buildReactionMenu(),
              buildCopyPasteMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildReactionMenu() {
    Size size = MediaQuery.of(context).size;

    double reactionIconSize =
        ((8.5 / 10 * size.width) / (ReactionTypes.toList().length).toDouble());
    double maxMenuWidth =
        (ReactionTypes.toList().length * reactionIconSize).toDouble();
    double menuHeight = (reactionIconSize).toDouble();

    double topPadding = -20;

    double topOffset = (messageTopOffset - menuHeight).toDouble().clamp(
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
        borderRadius: BorderRadius.circular(40.0),
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
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 7.5, horizontal: 7.5),
                      child: Container(
                        width: reactionIconSize - 15,
                        height: reactionIconSize - 15,
                        decoration: BoxDecoration(
                          color: currentlySelectedReaction == e
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).accentColor.withAlpha(150),
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            sendReaction(selfReaction == e ? "-$e" : e);
                          },
                          onTapDown: (TapDownDetails details) {
                            if (currentlySelectedReaction == e) {
                              currentlySelectedReaction = null;
                            } else {
                              currentlySelectedReaction = e;
                            }
                            if (this.mounted) setState(() {});
                          },
                          onTapUp: (details) {},
                          onTapCancel: () {
                            currentlySelectedReaction = selfReaction;
                            if (this.mounted) setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Reaction.getReactionIcon(e, iconColor),
                          ),
                        ),
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

  bool get showDownload =>
      widget.message.hasAttachments &&
      widget.message.attachments
              .where((element) => element.mimeStart != null)
              .length >
          0 &&
      widget.message.attachments
              .where((element) => AttachmentHelper.getContent(element) is File)
              .length >
          0;

  Widget buildCopyPasteMenu() {
    Size size = MediaQuery.of(context).size;

    double maxMenuWidth = size.width * 2 / 3;
    Widget menu = ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
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
                  onTap: () {
                    if (!isEmptyString(widget.message.fullText))
                      FlutterClipboard.copy(widget.message.fullText);
                    FlutterToast flutterToast = FlutterToast(context);
                    Widget toast = ClipRRect(
                      borderRadius: BorderRadius.circular(25.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25.0),
                            color:
                                Theme.of(context).accentColor.withOpacity(0.1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                !isEmptyString(widget.message.fullText)
                                    ? Icons.check
                                    : Icons.close,
                                color:
                                    Theme.of(context).textTheme.bodyText1.color,
                              ),
                              SizedBox(
                                width: 12.0,
                              ),
                              Text(
                                !isEmptyString(widget.message.fullText)
                                    ? "Copied to clipboard"
                                    : "Failed to copy empty message",
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    flutterToast.showToast(
                      child: toast,
                      gravity: ToastGravity.BOTTOM,
                      toastDuration: Duration(seconds: 2),
                    );
                  },
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
                  onTap: () {
                    if (isEmptyString(widget.message.fullText)) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).accentColor,
                        title: Text(
                          "Copy",
                          style: Theme.of(context).textTheme.headline1,
                        ),
                        content: Container(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 2 / 3,
                          ),
                          child: SingleChildScrollView(
                            physics: ThemeSwitcher.getScrollPhysics(),
                            child: SelectableText(
                              widget.message.fullText,
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: Text(
                              "Done",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true)
                                  .pop('dialog');
                            },
                          )
                        ],
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(
                      "Copy Selection",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
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
                  onTap: () async {
                    NewMessageManager().removeMessage(
                        widget.currentChat.chat, widget.message.guid);
                    await Message.softDelete({"guid": widget.message.guid});
                    Navigator.of(context).pop();
                  },
                  child: ListTile(
                    title: Text(
                      "Delete",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    trailing: Icon(
                      Icons.delete,
                      color: Theme.of(context).textTheme.bodyText1.color,
                    ),
                  ),
                ),
              ),
              if (showDownload)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      for (Attachment element in widget.message.attachments) {
                        dynamic content = AttachmentHelper.getContent(element);
                        if (content is File) {
                          await AttachmentHelper.saveToGallery(
                              context, content);
                        }
                      }
                    },
                    child: ListTile(
                      title: Text(
                        "Download",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      trailing: Icon(
                        Icons.file_download,
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

    double menuHeight = 150;
    if (showDownload) {
      menuHeight += 70;
    }

    double topOffset = (messageTopOffset + widget.childSize.height)
        .toDouble()
        .clamp(
            topMinimum,
            size.height -
                MediaQuery.of(context).viewInsets.bottom -
                menuHeight -
                20);
    double leftOffset = (widget.message.isFromMe
            ? size.width - maxMenuWidth - 15
            : 15 + (currentChat.chat.isGroup() ? 35 : 0))
        .toDouble();
    return Positioned(
      top: topOffset + 5,
      left: leftOffset,
      child: menu,
    );
  }
}
