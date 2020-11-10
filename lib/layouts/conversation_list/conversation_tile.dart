import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final bool replaceOnTap;
  final List<File> existingAttachments;
  final String existingText;

  ConversationTile({
    Key key,
    this.chat,
    this.replaceOnTap,
    this.existingAttachments,
    this.existingText,
  }) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile>
    with AutomaticKeepAliveClientMixin {
  MemoryImage contactImage;
  bool isPressed = false;
  var initials;

  @override
  void initState() {
    super.initState();

    fetchAvatar();
    ContactManager().stream.listen((List<String> addresses) {
      fetchAvatar();
    });
  }

  void setNewChatTitle() async {
    String tmpTitle = await getFullChatTitle(widget.chat);
    if (tmpTitle != widget.chat.title) {
      if (this.mounted) setState(() {});
    }
    widget.chat.title = tmpTitle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAvatar();
  }

  void setContactImage(MemoryImage image) {
    if (image != null) {
      if (contactImage == null ||
          contactImage.bytes.length != image.bytes.length) {
        contactImage = image;
        if (this.mounted) setState(() {});
      }
    }
  }

  Future<void> fetchAvatar() async {
    // If our chat does not have any participants, get them
    if (widget.chat.participants == null || widget.chat.participants.isEmpty) {
      await widget.chat.getParticipants();
    }

    if (widget.chat.participants.length > 1 ||
        (widget.chat.displayName != null && widget.chat.displayName != "")) {
      initials = Icon(Icons.people, color: Colors.white, size: 30);
      if (this.mounted) setState(() {});
    } else if (widget.chat.participants.length == 1) {
      ContactManager()
          .getCachedContact(widget.chat.participants[0].address)
          .then((Contact c) {
        if (c == null && this.mounted) {
          initials = getInitials(widget.chat.participants[0].address, "");
          setState(() {});
        } else {
          loadAvatar(widget.chat, widget.chat.participants[0].address)
              .then((MemoryImage image) {
            setContactImage(image);
          });
        }
      });
    } else {
      loadAvatar(widget.chat, widget.chat.participants[0].address)
          .then((MemoryImage image) {
        setContactImage(image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (initials == null) {
      initials = getInitials(widget.chat.title, " ");
    }

    Color avatarColor;
    if (shouldBeRainbow(chat: widget.chat)) {
      if (!widget.chat.isGroup() && widget.chat.participants.length > 0) {
        avatarColor = toColor(widget.chat.participants[0].address, context);
      } else if (widget.chat.isGroup()) {
        avatarColor = toColor(widget.chat.title, context);
      }
    }

    return Slidable(
      actionPane: SlidableStrechActionPane(),
      secondaryActions: <Widget>[
        if (!widget.chat.isArchived)
          IconSlideAction(
            caption: widget.chat.isMuted ? 'Show Alerts' : 'Hide Alerts',
            color: Colors.purple[700],
            icon: widget.chat.isMuted
                ? Icons.notifications_active
                : Icons.notifications_off,
            onTap: () async {
              widget.chat.isMuted = !widget.chat.isMuted;
              await widget.chat.save(updateLocalVals: true);
              if (this.mounted) setState(() {});
            },
          ),
        if (widget.chat.isArchived)
          IconSlideAction(
            caption: "Delete",
            color: Colors.red,
            icon: Icons.delete_forever,
            onTap: () async {
              ChatBloc().deleteChat(widget.chat);
              Chat.deleteChat(widget.chat);
            },
          ),
        if (!widget.chat.hasUnreadMessage)
          IconSlideAction(
            caption: 'Mark Unread',
            color: Colors.blue,
            icon: Icons.notifications,
            onTap: () {
              widget.chat.setUnreadStatus(true);
              ChatBloc().updateChatPosition(widget.chat);
            },
          ),
        IconSlideAction(
          caption: widget.chat.isArchived ? 'UnArchive' : 'Archive',
          color: widget.chat.isArchived ? Colors.blue : Colors.red,
          icon: widget.chat.isArchived ? Icons.replay : Icons.delete,
          onTap: () {
            if (widget.chat.isArchived) {
              ChatBloc().unArchiveChat(widget.chat);
            } else {
              ChatBloc().archiveChat(widget.chat);
            }
          },
        ),
      ],
      child: Material(
        color: !isPressed
            ? Theme.of(context).backgroundColor
            : Theme.of(context).backgroundColor.lightenOrDarken(30),
        child: GestureDetector(
          onTapDown: (details) {
            if (!this.mounted) return;

            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (details) {
            MessageBloc messageBloc = new MessageBloc(widget.chat);
            if (widget.replaceOnTap != null && widget.replaceOnTap) {
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: widget.chat,
                      title: widget.chat.title,
                      messageBloc: messageBloc,
                      existingAttachments: widget.existingAttachments,
                      existingText: widget.existingText,
                    );
                  },
                ),
                (route) => route.isFirst,
              );
            } else {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: widget.chat,
                      title: widget.chat.title,
                      messageBloc: messageBloc,
                      existingAttachments: widget.existingAttachments,
                      existingText: widget.existingText,
                    );
                  },
                ),
              );
            }
            Future.delayed(Duration(milliseconds: 200), () {
              if (this.mounted)
                setState(() {
                  isPressed = false;
                });
            });
          },
          onTapCancel: () {
            if (!this.mounted) return;

            setState(() {
              isPressed = false;
            });
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 0.5))),
                  child: ListTile(
                    contentPadding: EdgeInsets.only(left: 0),
                    title: Text(
                      widget.chat.title != null ? widget.chat.title : "",
                      style: Theme.of(context).textTheme.bodyText1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: widget.chat.latestMessageText != null &&
                            !(widget.chat.latestMessageText is String)
                        ? widget.chat.latestMessageText
                        : Text(
                            widget.chat.latestMessageText != null
                                ? widget.chat.latestMessageText
                                : "",
                            style: Theme.of(context).textTheme.subtitle1.apply(
                                color: Theme.of(context)
                                    .textTheme
                                    .subtitle1
                                    .color
                                    .withOpacity(0.85)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    leading: ContactAvatarWidget(
                      color: avatarColor,
                      contactImage: contactImage,
                      initials: initials,
                    ),
                    trailing: Container(
                      padding: EdgeInsets.only(right: 3),
                      width: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 2),
                            child: Text(
                              widget.chat.getDateText(),
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle2
                                  .apply(
                                      color: Theme.of(context)
                                          .textTheme
                                          .subtitle2
                                          .color
                                          .withOpacity(0.85)),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).textTheme.subtitle1.color,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      !widget.chat.isMuted
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                color: widget.chat.hasUnreadMessage
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.8)
                                    : Colors.transparent,
                              ),
                              width: 15,
                              height: 15,
                            )
                          : SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.chat.hasUnreadMessage
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.8)
                                  : Theme.of(context).textTheme.subtitle1.color,
                              width: 15,
                              height: 15,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
