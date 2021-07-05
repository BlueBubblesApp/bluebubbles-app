import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoAlertDialog.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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

class MessageDetailsPopupState extends State<MessageDetailsPopup> with TickerProviderStateMixin {
  List<Widget> reactionWidgets = <Widget>[];
  bool showTools = false;
  String selfReaction;
  String currentlySelectedReaction;
  Completer fetchRequest;
  CurrentChat currentChat;
  Chat dmChat;

  double messageTopOffset;
  double topMinimum;
  double height;

  @override
  void initState() {
    super.initState();
    currentChat = widget.currentChat;

    messageTopOffset = widget.childOffset.dy;
    topMinimum = CupertinoNavigationBar().preferredSize.height + (widget.message.hasReactions ? 110 : 50);

    dmChat = ChatBloc().chats.firstWhere(
          (chat) =>
              !chat.isGroup() && chat.participants.where((handle) => handle.id == widget.message.handleId).length == 1,
          orElse: () => null,
        );

    fetchReactions();

    // Animate showing the copy menu, slightly delayed
    Future.delayed(Duration(milliseconds: 400), () {
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
        setState(() {
          double totalHeight = Get.mediaQuery.size.height - Get.mediaQuery.viewInsets.bottom - detailsMenuHeight - 20;
          double offset = (widget.childOffset.dy + widget.childSize.height) - totalHeight;
          messageTopOffset = widget.childOffset.dy.clamp(topMinimum + 40, double.infinity);
          if (offset > 0) {
            messageTopOffset -= offset;
            messageTopOffset = messageTopOffset.clamp(topMinimum + 40, double.infinity);
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
    List<Message> reactionMessages = Reaction.getUniqueReactionMessages(reactions);

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
    bool isSent = !widget.message.guid.startsWith('temp') && !widget.message.guid.startsWith('error');

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
                  curve: Sprung.underDamped,
                  alignment: Alignment.center,
                  child: reactionWidgets.length > 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              alignment: Alignment.center,
                              height: 120,
                              width: Get.mediaQuery.size.width - 20,
                              color: Theme.of(context).accentColor,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: ThemeSwitcher.getScrollPhysics(),
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    if (index >= 0 && index < reactionWidgets.length) {
                                      return reactionWidgets[index];
                                    } else {
                                      return Container();
                                    }
                                  },
                                  itemCount: reactionWidgets?.length ?? 0,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(),
                ),
              ),
              // Only show the reaction menu if it's enabled and the message isn't temporary
              if (SettingsManager().settings.enablePrivateAPI && isSent) buildReactionMenu(),
              buildCopyPasteMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildReactionMenu() {
    Size size = Get.mediaQuery.size;

    double reactionIconSize = ((8.5 / 10 * size.width) / (ReactionTypes.toList().length).toDouble());
    double maxMenuWidth = (ReactionTypes.toList().length * reactionIconSize).toDouble();
    double menuHeight = (reactionIconSize).toDouble();
    double topPadding = -20;
    double topOffset = (messageTopOffset - menuHeight)
        .toDouble()
        .clamp(topMinimum, size.height - Get.mediaQuery.viewInsets.bottom - 120 - menuHeight);
    double leftOffset =
        (widget.message.isFromMe ? size.width - maxMenuWidth - 25 : 25 + (currentChat.chat.isGroup() ? 20 : 0))
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
                      padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 7.5),
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
      widget.message.attachments.where((element) => element.mimeStart != null).length > 0 &&
      widget.message.attachments.where((element) => AttachmentHelper.getContent(element) is File).length > 0;

  bool get isSent => !widget.message.guid.startsWith('temp') && !widget.message.guid.startsWith('error');

  double get detailsMenuHeight {
    return height;
  }

  set detailsMenuHeight(double value) {
    this.height = value;
  }

  Widget buildCopyPasteMenu() {
    Size size = Get.mediaQuery.size;

    double maxMenuWidth = size.width * 2 / 3;

    double maxHeight = size.height - topMinimum - widget.childSize.height;

    List<Widget> allActions = [
      if (widget.currentChat.chat.isGroup() && !widget.message.isFromMe && dmChat != null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              Navigator.pushReplacement(
                context,
                cupertino.CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: dmChat,
                    );
                  },
                ),
              );
            },
            child: ListTile(
              title: Text(
                "Open Direct Message",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                Icons.open_in_new,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
            ),
          ),
        ),
      if (widget.currentChat.chat.isGroup() && !widget.message.isFromMe && dmChat == null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion()) >= 11;
              String address = widget.message.handle.address;
              Contact contact = ContactManager().getCachedContactSync(address);
              UniqueContact uniqueContact;
              if (contact == null) {
                uniqueContact = UniqueContact(address: address, displayName: (await formatPhoneNumber(address)));
              } else {
                uniqueContact = UniqueContact(address: address, displayName: contact.displayName ?? address);
              }
              Navigator.pushReplacement(
                context,
                cupertino.CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      isCreator: true,
                      selected: [uniqueContact],
                      showSnackbar: shouldShowSnackbar,
                    );
                  },
                ),
              );
            },
            child: ListTile(
              title: Text(
                "Start Conversation",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                Icons.message,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
            ),
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion()) >= 11;
            Navigator.pushReplacement(
              context,
              cupertino.CupertinoPageRoute(
                builder: (BuildContext context) {
                  List<File> existingAttachments = [];
                  if (!widget.message.isUrlPreview()) {
                    existingAttachments =
                        widget.message.attachments.map((attachment) => File(attachment.getPath())).toList();
                  }
                  return ConversationView(
                    isCreator: true,
                    existingText: widget.message.text,
                    existingAttachments: existingAttachments,
                    showSnackbar: shouldShowSnackbar,
                  );
                },
              ),
            );
          },
          child: ListTile(
            title: Text(
              "Forward",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            trailing: Icon(
              Icons.forward,
              color: Theme.of(context).textTheme.bodyText1.color,
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            NewMessageManager().removeMessage(widget.currentChat.chat, widget.message.guid);
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
      if (!isEmptyString(widget.message.fullText))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Clipboard.setData(new ClipboardData(text: widget.message.fullText));
              showSnackbar("Copied", "Copied to clipboard!");
            },
            child: ListTile(
              title: Text("Copy", style: Theme.of(context).textTheme.bodyText1),
              trailing: Icon(
                Icons.content_copy,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
            ),
          ),
        ),
      if (!isEmptyString(widget.message.fullText))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isEmptyString(widget.message.fullText)) return;
              showDialog(
                  context: context,
                  builder: (_) {
                    Widget title = Text(
                      "Copy",
                      style: Theme.of(context).textTheme.headline1,
                    );
                    Widget content = Container(
                      constraints: BoxConstraints(
                        maxHeight: Get.mediaQuery.size.height * 2 / 3,
                      ),
                      child: SingleChildScrollView(
                        physics: ThemeSwitcher.getScrollPhysics(),
                        child: SelectableText(
                          widget.message.fullText,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                    );
                    List<Widget> actions = <Widget>[
                      TextButton(
                        child: Text(
                          "Done",
                          // style: Theme.of(context).textTheme.bodyText1,
                        ),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop('dialog');
                        },
                      ),
                    ];
                    if (SettingsManager().settings.skin == Skins.iOS) {
                      return CupertinoAlertDialog(
                        title: title,
                        backgroundColor: Theme.of(context).accentColor,
                        content: content,
                      );
                    }
                    return AlertDialog(
                      title: title,
                      backgroundColor: Theme.of(context).accentColor,
                      content: content,
                      actions: actions,
                    );
                  });
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
      if (showDownload && isSent)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              for (Attachment element in widget.message.attachments) {
                CurrentChat.of(context)?.clearImageData(element);
                await AttachmentHelper.redownloadAttachment(element);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: ListTile(
              title: Text(
                "Re-download from Server",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                Icons.refresh,
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
                  await AttachmentHelper.saveToGallery(context, content);
                }
              }
            },
            child: ListTile(
              title: Text(
                "Download to Device",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                Icons.file_download,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
            ),
          ),
        ),
      if (widget.message.hasAttachments || widget.message.text.length > 0)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.message.hasAttachments && !widget.message.isUrlPreview()) {
                for (Attachment element in widget.message.attachments) {
                  Share.file(
                    "${element.mimeType.split("/")[0].capitalizeFirst} shared from BlueBubbles: ${element.transferName}",
                    element.transferName,
                    element.getPath(),
                    element.mimeType,
                  );
                }
              } else if (widget.message.text.length > 0) {
                Share.text(
                  "Text shared from BlueBubbles",
                  widget.message.text,
                );
              }
            },
            child: ListTile(
              title: Text(
                "Share",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                Icons.share,
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
            ),
          ),
        ),
    ];

    List<Widget> detailsActions = [];
    List<Widget> moreActions = [];
    double itemHeight = 56;

    double actualHeight = 2 * itemHeight;
    int index = 0;
    while (actualHeight <= maxHeight - itemHeight && index < allActions.length) {
      actualHeight += itemHeight;
      detailsActions.add(allActions[index++]);
    }
    detailsMenuHeight = (detailsActions.length + 1) * itemHeight;
    moreActions.addAll(allActions.getRange(index, allActions.length));

    // If there is only one 'more' action then it can replace the 'more' button
    if (moreActions.length == 1) {
      detailsActions.add(moreActions.removeAt(0));
    }

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
              ...detailsActions,
              if (moreActions.length > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) {
                            Widget content = Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: moreActions,
                            );
                            if (SettingsManager().settings.skin == Skins.iOS) {
                              return CupertinoAlertDialog(
                                backgroundColor: Theme.of(context).accentColor,
                                content: content,
                              );
                            }
                            return AlertDialog(
                              backgroundColor: Theme.of(context).accentColor,
                              content: content,
                            );
                          });
                    },
                    child: ListTile(
                      title: Text("More...", style: Theme.of(context).textTheme.bodyText1),
                      trailing: Icon(
                        Icons.more_vert,
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

    double upperLimit = size.height - Get.mediaQuery.viewInsets.bottom - detailsMenuHeight;
    if (topMinimum > upperLimit) {
      topMinimum = upperLimit;
    }

    double topOffset = (messageTopOffset + widget.childSize.height).toDouble().clamp(topMinimum, upperLimit);
    double leftOffset =
        (widget.message.isFromMe ? size.width - maxMenuWidth - 15 : 15 + (currentChat.chat.isGroup() ? 35 : 0))
            .toDouble();
    return Positioned(
      top: topOffset + 5,
      left: leftOffset,
      child: menu,
    );
  }
}
