import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubble_messages/SQL/Models/Chats.dart';
import 'package:bluebubble_messages/send_transition.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:path_provider/path_provider.dart';

import './hex_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './main.dart';
import 'SQL/Models/Messages.dart';
import 'SQL/Repositories/RepoService.dart';

class ConversationView extends StatefulWidget {
  // final data;
  final Chat chat;
  ConversationView({Key key, this.chat}) : super(key: key);

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  List<Message> messages = <Message>[];
  TextEditingController _controller;

  // final animatedListKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    _updateMessages();
    Singleton().subscribe(() {
      if (this.mounted) _updateMessages();
    });
  }

  void _updateMessages() async {
    RepositoryServiceMessage.getMessagesFromChat(widget.chat.guid).then(
      (List<Message> _messages) {
        setState(
          () {
            messages = _messages;
          },
        );
      },
    );
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
          widget.chat.title,
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
            itemCount: messages.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return SizedBox(
                  height: 80,
                );
              }
              return MessageWidget(
                key: Key(messages[index - 1].guid),
                fromSelf: messages[index - 1].isFromMe,
                message: messages[index - 1],
              );
            },
          ),
          // ImplicitlyAnimatedList<Message>(
          //   physics:
          //       AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          //   reverse: true,
          //   items: messages,
          //   areItemsTheSame: (a, b) => a.guid == b.guid,
          //   insertDuration: Duration(milliseconds: 250),
          //   itemBuilder: (BuildContext context, Animation animation,
          //       Message item, int index) {
          //     if (index == 0) {
          //       return SizedBox(
          //         height: 80,
          //       );
          //     }
          //     return SlideTransition(
          //       key: Key(messages[index - 1].guid),
          //       position: animation.drive(
          //           Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
          //               .chain(CurveTween(curve: Curves.easeInOut))),
          //       child: MessageWidget(
          //         fromSelf: messages[index - 1].isFromMe,
          //         message: messages[index - 1],
          //       ),
          //     );
          //   },
          // ),
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
                                  //     widget.chat.guid, _controller.text);
                                  Message message = Message.manual(
                                      _controller.text,
                                      widget.chat.guid,
                                      DateTime.now().microsecondsSinceEpoch,
                                      "[]");
                                  Singleton().sendMessage(message);
                                  _controller.text = "";
                                  // widget.sendMessage(params);
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

class MessageWidget extends StatefulWidget {
  final fromSelf;
  final Message message;
  MessageWidget({Key key, this.fromSelf, this.message}) : super(key: key);

  @override
  _messageState createState() => _messageState();
}

class _messageState extends State<MessageWidget> {
  String body;
  List attachments;
  List images = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    attachments = jsonDecode(widget.message.attachments);
    body = widget.message.text.substring(
        attachments.length); //ensure that the "obj" text doesn't appear
    if (attachments.length > 0) {
      debugPrint(widget.message.text);
      debugPrint(widget.message.attachments);
      for (int i = 0; i < attachments.length; i++) {
        String transferName = attachments[i]["transferName"];
        String guid = attachments[i]["guid"];
        String appDocPath = Singleton().appDocDir.path;
        String pathName = "$appDocPath/$guid/$transferName";

        if (FileSystemEntity.typeSync(pathName) !=
            FileSystemEntityType.notFound) {
          images.add(File(pathName));
        } else {
          images.add(Singleton().getImage(attachments[i], widget.message.guid));
        }
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: widget.fromSelf
          ? AlignmentDirectional.bottomEnd
          : AlignmentDirectional.bottomStart,
      children: <Widget>[
        Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(bottom: 1),
              width: 20,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius:
                    BorderRadius.only(bottomLeft: Radius.circular(12)),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 2),
              height: 28,
              width: 11,
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius:
                      BorderRadius.only(bottomLeft: Radius.circular(8))),
            ),
            Container(
              height: 30,
              width: 6,
              color: Colors.black,
            )
          ],
        ),
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: 10,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 3 / 4,
          ),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.fromSelf ? Colors.blue : HexColor('26262a'),
          ),
          // color: Colors.blue,
          // height: 20,
          child: Column(
            children: _constructContent(),
          ),
        ),
      ],
    );
  }

  List<Widget> _constructContent() {
    List<Widget> content = <Widget>[];
    for (int i = 0; i < images.length; i++) {
      if (images[i] is File) {
        content.add(Image.file(images[i]));
      } else {
        content.add(
          FutureBuilder(
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  debugPrint("loaded image");
                  return Image.file(snapshot.data);
                } else {
                  return Text(
                    "Error loading",
                    style: TextStyle(color: Colors.white),
                  );
                }
              } else {
                return CircularProgressIndicator();
              }
            },
            future: images[i],
          ),
        );
      }
    }
    if (body.length > 0) {
      content.add(
        Text(
          body,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }
    return content;
  }
}
