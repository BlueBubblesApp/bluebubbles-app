import 'dart:io';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'hex_color.dart';
import 'repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({Key key, this.fromSelf, this.message, this.followingMessage})
      : super(key: key);

  final fromSelf;
  final Message message;
  final Message followingMessage;

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

    if (widget.followingMessage != null) {
      showTail = getDifferenceInTime().inMinutes > 5 ||
          widget.followingMessage.isFromMe != widget.message.isFromMe;
    } else {
      showTail = true;
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
    return widget.followingMessage.dateCreated
        .difference(widget.message.dateCreated);
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
              bottom: (widget.followingMessage != null &&
                          getDifferenceInTime().inMinutes < 30 &&
                          getDifferenceInTime().inMinutes > 3) ||
                      (widget.followingMessage != null &&
                          widget.followingMessage.isFromMe !=
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
        Padding(
          padding: EdgeInsets.only(
              bottom: (widget.followingMessage != null &&
                          getDifferenceInTime().inMinutes < 30 &&
                          getDifferenceInTime().inMinutes > 3) ||
                      (widget.followingMessage != null &&
                          widget.followingMessage.isFromMe !=
                              widget.message.isFromMe)
                  ? 10.0
                  : 0.0),
          child: Stack(
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
        ),
        _buildTimeStamp(),
      ],
    );
  }

  Widget _buildTimeStamp() {
    if (widget.followingMessage != null &&
        getDifferenceInTime().inMinutes > 30) {
      DateTime timeOfFollowingMessage = widget.followingMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfFollowingMessage);
      String date;
      if (widget.followingMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.followingMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfFollowingMessage.month.toString()}/${timeOfFollowingMessage.day.toString()}/${timeOfFollowingMessage.year.toString()}";
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

// import 'dart:io';

// import 'package:bluebubble_messages/helpers/utils.dart';
// import 'package:bluebubble_messages/repository/models/attachment.dart';
// import 'package:bluebubble_messages/singleton.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// import 'hex_color.dart';
// import 'repository/models/message.dart';

// class MessageWidget extends StatefulWidget {
//   MessageWidget({Key key, this.fromSelf, this.message, this.olderMessage, this.newerMessage})
//       : super(key: key);

//   final fromSelf;
//   final Message message;
//   final Message olderMessage;
//   final Message newerMessage;

//   @override
//   _MessageState createState() => _MessageState();
// }

// class _MessageState extends State<MessageWidget> {
//   List<Attachment> attachments = <Attachment>[];
//   String body;
//   List images = [];

//   bool showTail = false;

//   @override
//   void initState() {
//     super.initState();

//     showTail = shouldShowTail(widget.message, widget.olderMessage, widget.newerMessage);

//     Message.getAttachments(widget.message).then((data) {
//       attachments = data;
//       body = widget.message.text.substring(
//           attachments.length); //ensure that the "obj" text doesn't appear
//       if (attachments.length > 0) {
//         for (int i = 0; i < attachments.length; i++) {
//           String appDocPath = Singleton().appDocDir.path;
//           String pathName =
//               "$appDocPath/${attachments[i].guid}/${attachments[i].transferName}";
//           if (FileSystemEntity.typeSync(pathName) !=
//               FileSystemEntityType.notFound) {
//             images.add(File(pathName));
//           } else {
//             images.add(attachments[i]);
//           }
//         }
//         setState(() {});
//       }
//     });
//   }

//   bool sameSender(Message first, Message second) {
//     return (first != null && first.id != null && second != null && second.id != null && (
//       first.isFromMe == second.isFromMe ||
//       first.handleId == second.handleId
//     ));
//   }

//   bool shouldShowTail(Message current, Message older, Message newer) {
//     if (newer == null || newer.id == null) return true;
//     if (sameSender(current, older) && getDifferenceInTime(current, older).inMinutes > 30) return true;
//     if (!sameSender(current, older)) return true;
//     return false;
//   }

//   Duration getDifferenceInTime(Message first, Message second) {
//     return first.dateCreated.difference(second.dateCreated);
//   }

//   List<Widget> _constructContent() {
//     List<Widget> content = <Widget>[];
//     for (int i = 0; i < images.length; i++) {
//       if (images[i] is File) {
//         content.add(Stack(
//           children: <Widget>[
//             Image.file(images[i]),
//             Positioned.fill(
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: () {},
//                 ),
//               ),
//             ),
//           ],
//         ));
//       } else if (images[i] is Attachment) {
//         content.add(RaisedButton(
//           onPressed: () {
//             images[i] = Singleton().getImage(images[i]);
//             setState(() {});
//           },
//           color: HexColor('26262a'),
//           child: Text(
//             "Download",
//             style: TextStyle(color: Colors.white),
//           ),
//         ));
//       } else {
//         content.add(
//           FutureBuilder(
//             builder: (BuildContext context, AsyncSnapshot snapshot) {
//               if (snapshot.connectionState == ConnectionState.done) {
//                 if (snapshot.hasData) {
//                   debugPrint("loaded image");
//                   return InkWell(
//                     onTap: () {
//                       debugPrint("tap");
//                     },
//                     child: Image.file(snapshot.data),
//                   );
//                 } else {
//                   return Text(
//                     "Error loading",
//                     style: TextStyle(color: Colors.white),
//                   );
//                 }
//               } else {
//                 return CircularProgressIndicator();
//               }
//             },
//             future: images[i],
//           ),
//         );
//       }
//     }
//     if (widget.message.text.substring(attachments.length).length > 0) {
//       content.add(
//         Text(
//           widget.message.text.substring(attachments.length),
//           style: TextStyle(
//             color: Colors.white,
//           ),
//         ),
//       );
//     }
//     return content;
//   }

//   Widget _buildSentMessage() {
//     List<Widget> tail = <Widget>[
//       Container(
//         margin: EdgeInsets.only(bottom: 1),
//         width: 20,
//         height: 15,
//         decoration: BoxDecoration(
//           color: Colors.blue,
//           borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
//         ),
//       ),
//       Container(
//         margin: EdgeInsets.only(bottom: 2),
//         height: 28,
//         width: 11,
//         decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8))),
//       ),
//     ];

//     List<Widget> stack = <Widget>[
//       Container(
//         height: 30,
//         width: 6,
//         color: Colors.black,
//       ),
//     ];
//     if (showTail) {
//       stack.insertAll(0, tail);
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: <Widget>[
//         Padding(
//           padding: EdgeInsets.only(
//               bottom: showTail ? 10.0 : 5.0),
//           child: Stack(
//             alignment: AlignmentDirectional.bottomEnd,
//             children: <Widget>[
//               Stack(
//                 alignment: AlignmentDirectional.bottomEnd,
//                 children: stack,
//               ),
//               Container(
//                 margin: EdgeInsets.symmetric(
//                   horizontal: 10,
//                 ),
//                 constraints: BoxConstraints(
//                   maxWidth: MediaQuery.of(context).size.width * 3 / 4,
//                 ),
//                 padding: EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(20),
//                   color: Colors.blue,
//                 ),
//                 // color: Colors.blue,
//                 // height: 20,
//                 child: Column(
//                   children: _constructContent(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         _buildTimeStamp(),
//       ],
//     );
//   }

//   Widget _buildReceivedMessage() {
//     List<Widget> tail = <Widget>[
//       Container(
//         margin: EdgeInsets.only(bottom: 1),
//         width: 20,
//         height: 15,
//         decoration: BoxDecoration(
//           color: HexColor('26262a'),
//           borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
//         ),
//       ),
//       Container(
//         margin: EdgeInsets.only(bottom: 2),
//         height: 28,
//         width: 11,
//         decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.only(bottomRight: Radius.circular(8))),
//       ),
//     ];

//     List<Widget> stack = <Widget>[
//       Container(
//         height: 30,
//         width: 6,
//         color: Colors.black,
//       )
//     ];
//     if (showTail) {
//       stack.insertAll(0, tail);
//     }
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: <Widget>[
//         Stack(
//           alignment: AlignmentDirectional.bottomStart,
//           children: <Widget>[
//             Stack(
//               alignment: AlignmentDirectional.bottomStart,
//               children: stack,
//             ),
//             Container(
//               margin: EdgeInsets.symmetric(
//                 horizontal: 10,
//               ),
//               constraints: BoxConstraints(
//                 maxWidth: MediaQuery.of(context).size.width * 3 / 4,
//               ),
//               padding: EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 color: HexColor('26262a'),
//               ),
//               // color: Colors.blue,
//               // height: 20,
//               child: Column(
//                 children: _constructContent(),
//               ),
//             ),
//           ],
//         ),
//         _buildTimeStamp(),
//       ],
//     );
//   }

//   Widget _buildTimeStamp() {
//     if (widget.olderMessage != null &&
//         getDifferenceInTime(widget.message, widget.olderMessage).inMinutes > 30) {
//       DateTime timeOfolderMessage = widget.olderMessage.dateCreated;
//       String time = new DateFormat.jm().format(timeOfolderMessage);
//       String date;
//       if (widget.olderMessage.dateCreated.isToday()) {
//         date = "Today";
//       } else if (widget.olderMessage.dateCreated.isYesterday()) {
//         date = "Yesterday";
//       } else {
//         date =
//             "${timeOfolderMessage.month.toString()}/${timeOfolderMessage.day.toString()}/${timeOfolderMessage.year.toString()}";
//       }
//       return Padding(
//         padding: const EdgeInsets.symmetric(vertical: 14.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Text(
//               "$date, $time",
//               style: TextStyle(
//                 color: Colors.white,
//               ),
//             )
//           ],
//         ),
//       );
//     }
//     return Container();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.fromSelf) {
//       return _buildSentMessage();
//     } else {
//       return _buildReceivedMessage();
//     }
//   }
// }
