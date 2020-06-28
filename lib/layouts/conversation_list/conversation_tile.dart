import 'dart:async';

import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../helpers/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

// import 'SQL/Models/Chats.dart';
// import 'SQL/Models/Messages.dart';
// import 'SQL/Repositories/RepoService.dart';
// import 'conversation_view.dart';

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
          caption: 'Silence',
          color: Colors.purple[700],
          icon: Icons.notifications_off,
          onTap: () {
            //TODO add dnd
          },
        )
      ],
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: () {
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
                        style: TextStyle(
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle:
                        widget.subtitle != null && !(widget.subtitle is String)
                            ? widget.subtitle
                            : Text(
                                widget.subtitle != null ? widget.subtitle : "",
                                style: TextStyle(
                                  color: HexColor('36363a'),
                                ),
                                maxLines: 1,
                              ),
                    leading: CircleAvatar(
                      radius: 20,
                      child: contactImage == null
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  colors: [
                                    HexColor('a0a4af'),
                                    HexColor('848894')
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Container(
                                // child: Text("${widget.chat.title[0]}"),
                                child: (initials is Icon)
                                    ? initials
                                    : Text(initials),
                                alignment: AlignmentDirectional.center,
                              ),
                            )
                          : CircleAvatar(
                              backgroundImage: contactImage,
                            ),
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
                              style: TextStyle(
                                color: HexColor('36363a'),
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: HexColor('36363a'),
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
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          color: widget.hasNewMessage
                              ? Colors.blue[500].withOpacity(0.8)
                              : Colors.transparent,
                        ),
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
