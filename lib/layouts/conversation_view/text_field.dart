import 'dart:ui';

import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BlueBubblesTextField extends StatefulWidget {
  final Chat chat;
  BlueBubblesTextField({
    Key key,
    this.chat,
  }) : super(key: key);

  @override
  _BlueBubblesTextFieldState createState() => _BlueBubblesTextFieldState();
}

class _BlueBubblesTextFieldState extends State<BlueBubblesTextField> {
  TextEditingController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
                  // decoration: BoxDecoration(
                  //   color: HexColor('141316'),
                  //   border: Border.all(
                  //     color: HexColor('302f32'),
                  //     width: 1,
                  //   ),
                  //   borderRadius: BorderRadius.circular(20),
                  // ),
                  // padding: EdgeInsets.only(
                  //   right: 0,
                  //   left: 10,
                  // ),
                  child: Stack(
                    alignment: AlignmentDirectional.centerEnd,
                    children: <Widget>[
                      CupertinoTextField(
                        // autofocus: true,
                        controller: _controller,
                        scrollPhysics: BouncingScrollPhysics(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        placeholder: "BlueBubbles",
                        padding: EdgeInsets.only(
                            left: 10, right: 40, top: 10, bottom: 10),
                        placeholderStyle: TextStyle(
                          color: Color.fromARGB(255, 100, 100, 100),
                        ),
                        autofocus: true,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: HexColor('302f32'),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(15),
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
                            SocketManager()
                                .sendMessage(widget.chat, _controller.text);
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
    );
  }
}
