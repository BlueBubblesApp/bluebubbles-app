import 'dart:io';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart' as Cupertino;
import 'package:flutter/material.dart';

import '../../repository/models/chat.dart';

class ConversationView extends StatefulWidget {
  final List<File> existingAttachments;
  final String existingText;
  ConversationView({
    Key key,
    @required this.chat,
    @required this.title,
    @required this.messageBloc,
    this.existingAttachments,
    this.existingText,
  }) : super(key: key);

  // final data;
  final Chat chat;
  final String title;
  final MessageBloc messageBloc;

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  MemoryImage contactImage;
  Chat chat;
  OverlayEntry entry;
  LayerLink layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    NotificationManager().switchChat(chat);

    fetchAvatar(null);
    ContactManager().stream.listen((List<String> addresses) async {
      fetchAvatar(addresses);
    });
  }

  void fetchAvatar(List<String> addresses) {
    loadAvatar(widget.chat, addresses).then((MemoryImage image) {
      if (image != null) {
        if (contactImage == null ||
            contactImage.bytes.length != image.bytes.length) {
          contactImage = image;
          if (this.mounted) setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    widget.messageBloc.dispose();
    NotificationManager().leaveChat();
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    SocketManager().removeChatNotification(chat);
    fetchAvatar(null);
  }

  @override
  Widget build(BuildContext context) {
    var initials = getInitials(widget.title, " ");
    Function openDetails = () async {
      Chat _chat = await chat.getParticipants();
      Navigator.of(context).push(
        Cupertino.CupertinoPageRoute(
          builder: (context) =>
              ConversationDetails(chat: _chat, messageBloc: widget.messageBloc),
        ),
      );
    };

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withAlpha(125),
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2)),
        middle: ListView(
          physics: Cupertino.NeverScrollableScrollPhysics(),
          children: <Widget>[
            Container(height: 10.0),
            GestureDetector(
              onTap: openDetails,
              child: CircleAvatar(
                radius: 20,
                child: ContactAvatarWidget(
                  contactImage: contactImage,
                  initials: initials,
                ),
              ),
            ),
            Container(height: 3.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  onTap: openDetails,
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context)
                          .textTheme
                          .headline2,
                      children: [
                        TextSpan(
                          text: getShortChatTitle(chat),
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                        TextSpan(
                          text: " >",
                          style: Theme.of(context).textTheme.subtitle1
                        )
                      ],
                    ),
                  )
                )
              ],
            ),
          ],
        ),
        trailing: Container(width: 20),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: MessageView(
                messageBloc: widget.messageBloc,
                showHandle: chat.participants.length > 1,
              ),
            ),
          ),
          BlueBubblesTextField(
            chat: chat,
            existingAttachments: widget.existingAttachments,
            existingText: widget.existingText,
            onSend: (String text) async {},
          )
        ],
      ),
    );
  }
}
