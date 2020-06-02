import 'dart:ui';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_view/messages_view.dart';
import 'package:bluebubble_messages/layouts/conversation_view/text_field.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/socket_manager.dart';

import '../../helpers/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'message_widget.dart';
import '../../repository/models/chat.dart';
import '../../repository/models/message.dart';

class ConversationView extends StatefulWidget {
  ConversationView({
    Key key,
    @required this.chat,
    @required this.title,
    @required this.messageBloc,
  }) : super(key: key);

  // final data;
  final Chat chat;
  final String title;
  final MessageBloc messageBloc;

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  // List<Message> _messages = <Message>[];

  // String title = "";

  // final animatedListKey = GlobalKey<AnimatedListState>();

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    SocketManager().removeChatNotification(widget.chat);
    Chat chatWithParticipants = await widget.chat.getParticipants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: CupertinoNavigationBar(
        // centerTitle: true,
//        backgroundColor: Colors.transparent,
        backgroundColor: HexColor('26262a').withOpacity(0.5),
        // elevation: 0,
        // title: Text("Title"),
        middle: Text(
          widget.title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        // leading: IconButton(
        //   icon: Icon(
        //     Icons.arrow_back_ios,
        //     color: Colors.blue,
        //   ),
        //   onPressed: () {
        //     Navigator.of(context).pop();
        //   },
        // ),
      ),
      //   ),
      // ),
      // )
      body: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: <Widget>[
          MessageView(
            messageBloc: widget.messageBloc,
          ),
          BlueBubblesTextField(
            chat: widget.chat,
          )
        ],
      ),
    );
  }
}
