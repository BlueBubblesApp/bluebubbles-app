import 'dart:async';

import 'package:bluebubble_messages/singleton.dart';
import 'package:contacts_service/contacts_service.dart';

import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'SQL/Models/Chats.dart';
import 'SQL/Models/Messages.dart';
import 'SQL/Repositories/RepoService.dart';
import 'conversation_view.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;

  ConversationTile({Key key, this.chat}) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  String subtitle = "";
  String lastMessageTime = "";
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Future<void> didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    List<Message> messages =
        await RepositoryServiceMessage.getMessagesFromChat(widget.chat.guid);
    subtitle = messages[0].text;
    // lastMessageTime =
    DateTime date =
        new DateTime.fromMillisecondsSinceEpoch(messages[0].dateCreated * 1000);
    lastMessageTime =
        TimeOfDay(hour: date.hour, minute: date.minute).format(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () async {
          debugPrint(widget.chat.guid.toString());
          // List<Message>
          debugPrint(widget.chat.guid);
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
            widget.chat.title,
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
                child: Text("BW"),
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
