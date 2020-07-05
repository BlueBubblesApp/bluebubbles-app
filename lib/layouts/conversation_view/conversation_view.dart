import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubble_messages/layouts/widgets/animated_offset_builder.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubble_messages/layouts/widgets/send_widget.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart' as Cupertino;

import '../../helpers/hex_color.dart';

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
  Chat chat;
  OverlayEntry entry;
  LayerLink layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    NotificationManager().switchChat(chat);
    widget.chat.getParticipants().then((value) => setState(() {
          chat = value;
        }));
    // ChatBloc().chatStream.listen((event) {
    //   event.forEach((element) {
    //     if (element.guid == chat.guid) {
    //       chat = element;
    //       if (this.mounted) setState(() {});
    //     }
    //   });
    // });
  }

  @override
  void dispose() {
    widget.messageBloc.dispose();
    NotificationManager().leaveChat();

    String appDocPath = SettingsManager().appDocDir.path;

    String pathName = "$appDocPath/tempAssets";
    Directory tempAssets = Directory(pathName);
    if (tempAssets.existsSync()) {
      tempAssets.delete(recursive: true);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    SocketManager().removeChatNotification(chat);

    Chat _chat = await chat.getParticipants();
    if (_chat.participants.length == 1) {
      Contact contact = getContact(
          ContactManager().contacts, _chat.participants.first.address);
      if (contact != null && contact.avatar.length > 0) {
        contactImage = MemoryImage(contact.avatar);
        if (this.mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var initials = getInitials(widget.title, " ");
    Function openDetails = () async {
      Chat _chat = await chat.getParticipants();
      Navigator.of(context).push(
        Cupertino.CupertinoPageRoute(
          builder: (context) => ConversationDetails(
            chat: _chat,
          ),
        ),
      );
    };

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).backgroundColor.withAlpha(150),
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
                          // child: Text("${chat.title[0]}"),
                          child: (initials is Icon) ? initials : Text(initials),
                          alignment: AlignmentDirectional.center,
                        ),
                      )
                    : CircleAvatar(
                        backgroundImage: contactImage,
                      ),
              ),
            ),
            Container(height: 3.0),
            Container(
              padding: EdgeInsets.only(left: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  GestureDetector(
                    onTap: openDetails,
                    child: Text(
                      getShortChatTitle(chat),
                      style: Theme.of(context).textTheme.headline2,
                    ),
                  ),
                  Container(width: 5),
                  Text(
                    ">",
                    style: Theme.of(context).textTheme.subtitle1,
                  )
                ],
              ),
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
                layerLink: layerLink,
              ),
            ),
          ),
          BlueBubblesTextField(
            chat: chat,
            onSend: (String text) async {},
          )
        ],
      ),
    );
  }
}
