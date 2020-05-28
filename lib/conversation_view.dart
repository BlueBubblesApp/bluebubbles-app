import 'dart:ui';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/blocs/message_bloc.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/singleton.dart';

import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'message_widget.dart';
import 'repository/models/chat.dart';
import 'repository/models/message.dart';

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

  TextEditingController _controller;
  // String title = "";

  // final animatedListKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    // _messageBloc = new MessageBloc(widget.chat);

    _controller = TextEditingController();
    // Singleton().subscribe(_updateMessages);
    // chatTitle(widget.chat).then((value) {
    //   title = value;
    // });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    // _messageBloc.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    Singleton().removeChatNotification(widget.chat);
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
          StreamBuilder(
            stream: widget.messageBloc.stream,
            builder:
                (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
              List<Message> _messages = <Message>[];
              if (snapshot.hasData) {
                _messages = snapshot.data;
              } else {
                _messages = widget.messageBloc.messages;
              }

              return ListView.builder(
                reverse: true,
                physics: AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                itemCount: _messages.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return SizedBox(
                      height: 80,
                    );
                  }

                  Message olderMessage;
                  Message newerMessage;
                  if (index >= 0 && index <= _messages.length) {
                    olderMessage = _messages[index];
                  }
                  if (index - 2 >= 0 && index - 2 <= _messages.length) {
                    newerMessage = _messages[index - 2];
                  }

                  return MessageWidget(
                    key: Key(_messages[index - 1].guid),
                    fromSelf: _messages[index - 1].isFromMe,
                    message: _messages[index - 1],
                    olderMessage: olderMessage,
                    newerMessage: newerMessage
                  );
                },
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
                              controller: _controller,
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
                              minWidth: 30,
                              height: 30,
                              child: RaisedButton(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 0,
                                ),
                                color: Colors.blue,
                                onPressed: () {
                                  debugPrint("sending message");
                                  // Singleton().sendMessage(
                                  //     widget.chat, _controller.text);
                                  // Message message = Message.manual(
                                  //     _controller.text,
                                  //     widget.chat.guid,
                                  //     DateTime.now().millisecondsSinceEpoch,
                                  //     "[]");
                                  _controller.text = "";
                                },
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
