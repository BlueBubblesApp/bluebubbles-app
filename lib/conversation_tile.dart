import 'dart:async';

import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/singleton.dart';

import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'conversation_view.dart';
import 'repository/models/chat.dart';

// import 'SQL/Models/Chats.dart';
// import 'SQL/Models/Messages.dart';
// import 'SQL/Repositories/RepoService.dart';
// import 'conversation_view.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  ConversationTile({
    Key key,
    this.chat,
  }) : super(key: key);

  // final Chat chat;

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  String lastMessageTime = "";
  String subtitle = "";
  String title = "title";
  List<Message> messages = <Message>[];

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    if (this.mounted) _updateMessages();
  }

  @override
  void initState() {
    super.initState();
    chatTitle(widget.chat).then((value) {
      title = value;
      setState(() {});
    });
    _updateMessages();
    Singleton().subscribe(() {
      if (this.mounted) _updateMessages();
    });
  }

  void _updateMessages() {
    Chat.getMessages(widget.chat).then((value) {
      messages = value;
      messages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
      if (messages.length > 0) {
        Message.getAttachments(messages.first).then((attachments) {
          String text = messages.first.text.substring(attachments.length);
          if (text.length == 0 && attachments.length > 0) {
            text = "${attachments.length} attachments";
          }
          subtitle = text;
        });
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    String initials;
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () async {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (BuildContext context) {
                return ConversationView(
                  chat: widget.chat,
                );
              },
            ),
          );
        },
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: HexColor('36363a'),
            ),
            maxLines: 1,
          ),
          leading: CircleAvatar(
            radius: 20,
            child: Container(
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
                child: Text(""),
                alignment: AlignmentDirectional.center,
              ),
            ),
          ),
          trailing: Container(
            width: 73,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(
                    lastMessageTime,
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
    );
  }
}
