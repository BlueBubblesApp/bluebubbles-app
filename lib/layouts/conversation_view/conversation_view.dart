import 'dart:ui';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';

import '../../helpers/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../repository/models/chat.dart';

class ConversationView extends StatefulWidget {
  ConversationView(
      {Key key,
      @required this.chat,
      @required this.title,
      @required this.messageBloc})
      : super(key: key);

  // final data;
  final Chat chat;
  final String title;
  final MessageBloc messageBloc;

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  ImageProvider contactImage;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    SocketManager().removeChatNotification(widget.chat);

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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: CustomCupertinoNavBar(
        backgroundColor: HexColor('26262a').withOpacity(0.5),
        // padding: EdgeInsetsDirectional.only(top: 10.0),
        middle: Column(children: <Widget>[
          Container(height: 10.0),
          CircleAvatar(
            radius: 20,
            child: contactImage == null
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        colors: [HexColor('a0a4af'), HexColor('848894')],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      // child: Text("${widget.chat.title[0]}"),
                      child: (initials is Icon) ? initials : Text(initials),
                      alignment: AlignmentDirectional.center,
                    ),
                  )
                : CircleAvatar(
                    backgroundImage: contactImage,
                  ),
          ),
          Container(height: 2.0),
          Text(
            widget.title,
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
          )
        ]),
        trailing: GestureDetector(
          child: Icon(
            Icons.info,
            color: Colors.blue,
          ),
          onTap: () async {
            Chat chat = await widget.chat.getParticipants();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ConversationDetails(
                  chat: chat,
                ),
              ),
            );
          },
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: MessageView(
                messageBloc: widget.messageBloc,
              ),
            ),
          ),
          BlueBubblesTextField(
            chat: widget.chat,
          )
        ],
      ),
    );
  }
}
