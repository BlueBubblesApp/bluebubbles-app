import 'dart:io';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'hex_color.dart';
import 'repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({Key key, this.fromSelf, this.message, this.previousMessage})
      : super(key: key);

  final fromSelf;
  final Message message;
  final Message previousMessage;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  String body;
  List images = [];

  bool showTail = false;

  @override
  void initState() {
    super.initState();

    if (widget.previousMessage != null) {
      // debugPrint(getDifferenceInTime().inMinutes.toString());
      showTail = getDifferenceInTime().inMinutes > 5 ||
          widget.previousMessage.isFromMe != widget.message.isFromMe ||
          widget.previousMessage.handleId != widget.message.handleId;
    } else {
      showTail = true;
    }

    if (widget.message != null && widget.message.from != null) {
      debugPrint(widget.message.from.address);
    }

    Message.getAttachments(widget.message).then((data) {
      attachments = data;
      body = widget.message.text.substring(
          attachments.length); //ensure that the "obj" text doesn't appear
      if (attachments.length > 0) {
        for (int i = 0; i < attachments.length; i++) {
          String appDocPath = Singleton().appDocDir.path;
          String pathName =
              "$appDocPath/${attachments[i].guid}/${attachments[i].transferName}";
          if (FileSystemEntity.typeSync(pathName) !=
              FileSystemEntityType.notFound) {
            images.add(File(pathName));
          } else {
            images.add(attachments[i]);
          }
        }
        setState(() {});
      }
    });
  }

  Duration getDifferenceInTime() {
    return widget.message.dateCreated
        .difference(widget.previousMessage.dateCreated);
  }

  List<Widget> _constructContent() {
    List<Widget> content = <Widget>[];
    for (int i = 0; i < images.length; i++) {
      if (images[i] is File) {
        content.add(Stack(
          children: <Widget>[
            Image.file(images[i]),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                ),
              ),
            ),
          ],
        ));
      } else if (images[i] is Attachment) {
        content.add(RaisedButton(
          onPressed: () {
            images[i] = Singleton().getImage(images[i]);
            setState(() {});
          },
          color: HexColor('26262a'),
          child: Text(
            "Download",
            style: TextStyle(color: Colors.white),
          ),
        ));
      } else {
        content.add(
          FutureBuilder(
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  debugPrint("loaded image");
                  return InkWell(
                    onTap: () {
                      debugPrint("tap");
                    },
                    child: Image.file(snapshot.data),
                  );
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
    if (widget.message.text.substring(attachments.length).length > 0) {
      content.add(
        Text(
          widget.message.text.substring(attachments.length),
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }
    return content;
  }

  Widget _buildSentMessage() {
    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Colors.black,
      ),
    ];
    if (showTail) {
      stack.insertAll(0, tail);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
              bottom: (widget.previousMessage != null &&
                          getDifferenceInTime().inMinutes < 30 &&
                          getDifferenceInTime().inMinutes > 3) ||
                      (widget.previousMessage != null &&
                          widget.previousMessage.isFromMe !=
                              widget.message.isFromMe)
                  ? 10.0
                  : 0.0),
          child: Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: <Widget>[
              Stack(
                alignment: AlignmentDirectional.bottomEnd,
                children: stack,
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
                  color: Colors.blue,
                ),
                // color: Colors.blue,
                // height: 20,
                child: Column(
                  children: _constructContent(),
                ),
              ),
            ],
          ),
        ),
        _buildTimeStamp(),
      ],
    );
  }

  Widget _buildReceivedMessage() {
    List<Widget> tail = <Widget>[
      Container(
        margin: EdgeInsets.only(bottom: 1),
        width: 20,
        height: 15,
        decoration: BoxDecoration(
          color: HexColor('26262a'),
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
        ),
      ),
      Container(
        margin: EdgeInsets.only(bottom: 2),
        height: 28,
        width: 11,
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
      ),
    ];

    List<Widget> stack = <Widget>[
      Container(
        height: 30,
        width: 6,
        color: Colors.black,
      )
    ];
    if (showTail) {
      stack.insertAll(0, tail);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          alignment: AlignmentDirectional.bottomStart,
          children: <Widget>[
            Stack(
              alignment: AlignmentDirectional.bottomStart,
              children: stack,
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
                color: HexColor('26262a'),
              ),
              // color: Colors.blue,
              // height: 20,
              child: Column(
                children: _constructContent(),
              ),
            ),
          ],
        ),
        _buildTimeStamp(),
      ],
    );
  }

  Widget _buildTimeStamp() {
    if (widget.previousMessage != null &&
        getDifferenceInTime().inMinutes > 30) {
      DateTime timeOfpreviousMessage = widget.previousMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfpreviousMessage);
      String date;
      if (widget.previousMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.previousMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfpreviousMessage.month.toString()}/${timeOfpreviousMessage.day.toString()}/${timeOfpreviousMessage.year.toString()}";
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "$date, $time",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fromSelf) {
      return _buildSentMessage();
    } else {
      return _buildReceivedMessage();
    }
  }
}
