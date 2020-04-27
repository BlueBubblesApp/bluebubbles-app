import 'dart:async';

import 'package:bluebubble_messages/singleton.dart';
import 'package:contacts_service/contacts_service.dart';

import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'SQL/Models/Chats.dart';
import 'SQL/Repositories/RepoService.dart';
import 'conversation_view.dart';

class ConversationTile extends StatefulWidget {
  final data;

  ConversationTile({Key key, this.data}) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  String title = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    debugPrint(widget.data.toString());
    if (widget.data == null || widget.data["displayName"] == "") {
      // title = widget.data["participants"]
      // .map((participant) => participant["id"] + ", ");
      String _title = "";
      for (int i = 0; i < widget.data["participants"].length; i++) {
        var participant = widget.data["participants"][i];
        // _title += (participant["id"] + ", ").toString();
        _title = _convertNumberToContact(participant["id"]) + ", ";
      }
      // debugPrint(_title.toString());
      title = _title;
      Chat chat = Chat(widget.data["guid"], title,
          widget.data["lastMessageTimestamp"], widget.data["chatIdentifier"]);
      RepositoryServiceChats.addChat(chat);
    } else {
      title = widget.data["displayName"];
    }
  }

  String _convertNumberToContact(String id) {
    if (Singleton().contacts == null) return id;
    String contactTitle = id;
    Singleton().contacts.forEach((Contact contact) {
      contact.phones.forEach((Item item) {
        String formattedNumber = item.value.replaceAll(RegExp(r'[-() ]'), '');
        if (formattedNumber == id || "+1" + formattedNumber == id) {
          contactTitle = contact.displayName;
          return contactTitle;
        }
      });
      contact.emails.forEach((Item item) {
        if (item.value == id) {
          contactTitle = contact.displayName;
          return contactTitle;
        }
      });
    });
    return contactTitle;
  }

  Future _getMessages(Map params) {
    Completer completer = new Completer();
    Singleton().socket.emit("get-chat-messages", [params]);
    Singleton().socket.on("chat-messages", (data) {
      debugPrint("got messages");
      if (completer != null) completer.complete(data["data"]);
      completer = null;
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () async {
          debugPrint(widget.data["guid"].toString());
          Map params = new Map();
          params["identifier"] = widget.data["guid"].toString();
          params["limit"] = 50;
          var data = await _getMessages(params);
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (BuildContext context) {
                return ConversationView(
                  messages: data,
                  data: widget.data,
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
            "most recent message",
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
            width: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(right: 10),
                  child: Text(
                    "4:20",
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
