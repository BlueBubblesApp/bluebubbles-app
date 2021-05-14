import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../socket_manager.dart';

class MediaFile extends StatefulWidget {
  MediaFile({
    Key key,
    @required this.child,
    @required this.attachment,
  }) : super(key: key);
  final Widget child;
  final Attachment attachment;

  @override
  _MediaFileState createState() => _MediaFileState();
}

class _MediaFileState extends State<MediaFile> {
  @override
  void initState() {
    super.initState();
    SocketManager().attachmentSenderCompleter.listen((event) {
      if (event == widget.attachment.guid && this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (SocketManager().attachmentSenders.containsKey(widget.attachment.guid)) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          widget.child,
          StreamBuilder(
            builder: (context, AsyncSnapshot<double> snapshot) {
              if (snapshot.hasError) {
                return Text(
                  "Unable to send",
                  style: Theme.of(context).textTheme.bodyText1,
                );
              }
              return CircularProgressIndicator(
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation(Colors.white),
                value: snapshot.hasData
                    ? snapshot.data
                    : SocketManager()
                        .attachmentSenders[widget.attachment.guid]
                        .progress,
              );
            },
            stream: SocketManager()
                .attachmentSenders[widget.attachment.guid]
                .stream,
          ),
        ],
      );
    } else {
      return Stack(alignment: Alignment.center, children: [
        widget.child,
        if (widget.attachment.originalROWID == null)
          Container(
            child: Theme(
              data: ThemeData(
                cupertinoOverrideTheme:
                    CupertinoThemeData(brightness: Brightness.dark),
              ),
              child: CupertinoActivityIndicator(
                radius: 10,
              ),
            ),
            height: 45,
            width: 45,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                color: Colors.black.withOpacity(0.5)),
          ),
      ]);
    }
  }
}
