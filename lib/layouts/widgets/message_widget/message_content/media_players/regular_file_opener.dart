import 'dart:io';

import 'package:bluebubbles/managers/event_dispatcher.dart';
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
    IconData fileIcon = Icons.open_in_new;
    if (widget.attachment.mimeType != null) {
      if (widget.attachment.mimeType == "application/pdf") {
        fileIcon = Icons.picture_as_pdf;
      } else if (widget.attachment.mimeType == "application/zip") {
        fileIcon = Icons.folder;
      } else if (widget.attachment.mimeType.startsWith("audio")) {
        fileIcon = Icons.music_note;
      } else if (widget.attachment.mimeType.startsWith("image")) {
        fileIcon = Icons.photo;
      } else if (widget.attachment.mimeType.startsWith("video")) {
        fileIcon = Icons.videocam;
      } else if (widget.attachment.mimeType.startsWith("text")) {
        fileIcon = Icons.notes;
      }
    }

    return Container(
      height: 140,
      width: 200,
      color: Theme.of(context).accentColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            basename(widget.file.path),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          CupertinoButton(
            child: Icon(
              fileIcon,
              color: Colors.white,
            ),
            onPressed: () async {
              try {
                await MethodChannelInterface().invokeMethod(
                  "open_file",
                  {
                    "path": "/attachments/" +
                        widget.attachment.guid +
                        "/" +
                        basename(widget.file.path),
                    "mimeType": widget.attachment.mimeType,
                  },
                );
              } catch (ex) {
                final snackBar = SnackBar(content: Text("No handler for this file type!"));
                Scaffold.of(context).showSnackBar(snackBar);
              }
            },
          ),
          Text(widget.attachment.mimeType),
        ],
      ),
    );
  }
}
