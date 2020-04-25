import 'dart:ui';

import './hex_color.dart';
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
  final List messages;
  ConversationView({Key key, this.messages}) : super(key: key);

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  List messages = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    setState(() {
      messages = widget.messages;
    });
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
      body: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: <Widget>[
          ListView.builder(
            reverse: true,
            physics:
                AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: messages.length,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return SizedBox(
                  height: 80,
                );
              }
              return Message(
                fromSelf: messages[index]["isFromMe"],
                message: messages[index],
              );
            },
          ),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 30,
                sigmaY: 30,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.all(5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Flexible(
                      child: IconButton(
                        onPressed: () {
                          debugPrint("Camera");
                        },
                        icon: Icon(
                          Icons.camera_alt,
                          color: HexColor('8e8e8e'),
                          size: 30,
                        ),
                      ),
                    ),
                    Spacer(flex: 1),
                    Flexible(
                      flex: 15,
                      child: Container(
                        // height: 40,
                        decoration: BoxDecoration(
                          color: HexColor('141316'),
                          border: Border.all(
                            color: HexColor('302f32'),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.only(
                          right: 0,
                          left: 10,
                        ),
                        child: Stack(
                          alignment: AlignmentDirectional.centerEnd,
                          children: <Widget>[
                            TextField(
                              // autofocus: true,
                              scrollPhysics: BouncingScrollPhysics(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              decoration: InputDecoration(
                                contentPadding:
                                    EdgeInsets.only(top: 5, bottom: 5),
                                border: InputBorder.none,
                                // border: OutlineInputBorder(),
                                hintText: 'BlueBubbles',
                                hintStyle: TextStyle(
                                  color: Color.fromARGB(255, 100, 100, 100),
                                ),
                              ),
                            ),
                            ButtonTheme(
                              minWidth: 40,
                              height: 40,
                              child: RaisedButton(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 0,
                                ),
                                color: Colors.blue,
                                onPressed: () {},
                                child: Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class Message extends StatelessWidget {
  final fromSelf;
  final message;
  const Message({Key key, this.fromSelf, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String body = message["text"].toString();

    return Row(
      mainAxisAlignment:
          this.fromSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: <Widget>[
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 3 / 4,
          ),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: fromSelf ? Colors.blue : HexColor('26262a'),
          ),
          // color: Colors.blue,
          // height: 20,
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
