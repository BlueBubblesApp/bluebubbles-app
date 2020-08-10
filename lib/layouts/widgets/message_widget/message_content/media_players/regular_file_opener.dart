import 'dart:io';

import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class RegularFileOpener extends StatefulWidget {
  RegularFileOpener({
    Key key,
    this.attachment,
    this.file,
  }) : super(key: key);
  final Attachment attachment;
  final File file;

  @override
  _RegularFileOpenerState createState() => _RegularFileOpenerState();
}

class _RegularFileOpenerState extends State<RegularFileOpener> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: 400,
      child: Column(
        children: <Widget>[
          Text(
            basename(widget.file.path),
          ),
          CupertinoButton(
            child: Icon(
              Icons.open_in_new,
              color: Colors.white,
            ),
            onPressed: () {
              debugPrint(widget.file.path);
              MethodChannelInterface().invokeMethod(
                "open_file",
                {
                  "path": "/attachments/" +
                      widget.attachment.guid +
                      "/" +
                      basename(widget.file.path),
                  "mimeType": widget.attachment.mimeType,
                },
              );
            },
          ),
          Text(widget.attachment.mimeType),
        ],
      ),
    );
  }
}
