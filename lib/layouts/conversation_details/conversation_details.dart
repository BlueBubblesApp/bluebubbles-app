import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;
  ConversationDetails({
    Key key,
    this.chat,
  }) : super(key: key);

  @override
  _ConversationDetailsState createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CupertinoNavigationBar(
        backgroundColor: HexColor('26262a').withOpacity(0.5),
        middle: Text(
          "Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: ListView.builder(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: widget.chat.participants.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == widget.chat.participants.length) {
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NewChatCreator(
                      currentChat: widget.chat,
                      isCreator: false,
                    ),
                  ),
                );
              },
              child: ListTile(
                title: Text(
                  "Add Contact",
                  style: TextStyle(
                    color: Colors.blue,
                  ),
                ),
                leading: Icon(
                  Icons.add,
                  color: Colors.blue,
                ),
              ),
            );
          }
          return ContactTile(
            contact: getContact(ContactManager().contacts,
                widget.chat.participants[index].address),
            handle: widget.chat.participants[index],
          );
        },
      ),
    );
  }
}
