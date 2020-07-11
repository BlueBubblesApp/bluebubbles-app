import 'dart:async';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../helpers/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final String title;
  final dynamic subtitle;
  final String date;
  final bool hasNewMessage;
  ConversationTile(
      {Key key,
      this.chat,
      this.title,
      this.subtitle,
      this.date,
      this.hasNewMessage})
      : super(key: key);

  // final Chat chat;

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  String lastMessageTime = "";
  List<Message> messages = <Message>[];
  ImageProvider contactImage;

  bool isPressed = false;

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    Chat chat = await widget.chat.getParticipants();
    if (chat.participants.length == 1) {
      Contact contact = getContact(
          ContactManager().contacts, chat.participants.first.address);
      if (contact != null && contact.avatar.length > 0) {
        contactImage = MemoryImage(contact.avatar);
        if (this.mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var initials = getInitials(widget.title, " ");
    return Slidable(
      actionPane: SlidableStrechActionPane(),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: widget.chat.isMuted ? 'Show Alerts' : 'Hide Alerts',
          color: Colors.purple[700],
          icon: widget.chat.isMuted
              ? Icons.notifications_active
              : Icons.notifications_off,
          onTap: () async {
            widget.chat.isMuted = !widget.chat.isMuted;
            await widget.chat.save(updateLocalVals: true);
            setState(() {});
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
        )
      ],
      child: Material(
        color: !isPressed
            ? Theme.of(context).backgroundColor
            : Theme.of(context).buttonColor,
        child: GestureDetector(
          onTapDown: (details) {
            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (details) {
            MessageBloc messageBloc = new MessageBloc(widget.chat);
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (BuildContext context) {
                  return ConversationView(
                    chat: widget.chat,
                    title: widget.title,
                    messageBloc: messageBloc,
                  );
                },
              ),
            );
            Future.delayed(Duration(milliseconds: 200), () {
              setState(() {
                isPressed = false;
              });
            });
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
          },
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 35.0),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withAlpha(40), width: 0.5))),
                  child: ListTile(
                    contentPadding: EdgeInsets.only(left: 0),
                    title: Text(widget.title,
                        style: Theme.of(context).textTheme.bodyText1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle:
                        widget.subtitle != null && !(widget.subtitle is String)
                            ? widget.subtitle
                            : Text(
                                widget.subtitle != null ? widget.subtitle : "",
                                style: Theme.of(context).textTheme.subtitle1,
                                maxLines: 1,
                              ),
                    leading: ContactAvatarWidget(
                      contactImage: contactImage,
                      initials: initials,
                    ),
                    trailing: Container(
                      width: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 5),
                            child: Text(
                              widget.date,
                              style: Theme.of(context).textTheme.subtitle2,
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
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      !widget.chat.isMuted
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                color: widget.hasNewMessage
                                    ? Colors.blue[500].withOpacity(0.8)
                                    : Colors.transparent,
                              ),
                              width: 15,
                              height: 15,
                            )
                          : SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.hasNewMessage
                                  ? Colors.blue[500].withOpacity(0.8)
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
}
