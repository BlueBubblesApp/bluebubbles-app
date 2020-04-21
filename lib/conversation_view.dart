import 'dart:ui';

import 'package:bluebubbles/hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MessageData {
  String message;
  String date;
  String hasRead;
  bool sentBySelf;
  MessageData(String _message, bool _sentBySelf) {
    message = _message;
    sentBySelf = _sentBySelf;
  }
}

class ConversationView extends StatefulWidget {
  ConversationView({Key key}) : super(key: key);

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  List<MessageData> messages = <MessageData>[
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
    MessageData("sender", true),
    MessageData("receiver", false),
  ];

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
          "Title",
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true,
              physics: AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                return Row(
                  mainAxisAlignment: messages[index].sentBySelf
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 3 / 4,
                      ),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: messages[index].sentBySelf
                            ? Colors.blue
                            : HexColor('26262a'),
                      ),
                      // color: Colors.blue,
                      // height: 20,
                      child: Text(
                        messages[index].message,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Flexible(
                  child: IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.camera_alt,
                      color: HexColor('8e8e8e'),
                      size: 30,
                    ),
                  ),
                ),
                Flexible(
                  flex: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: HexColor('141316'),
                      border: Border.all(
                        color: HexColor('302f32'),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: EdgeInsets.only(
                      // top: 1,
                      // bottom: 1,
                      right: 10,
                      left: 10,
                    ),
                    child: TextField(
                      // autofocus: true,
                      scrollPhysics: BouncingScrollPhysics(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        // border: OutlineInputBorder(),
                        hintText: 'BlueBubbles',
                        hintStyle: TextStyle(
                          color: Color.fromARGB(255, 100, 100, 100),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
