import 'dart:io';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class RegularFileOpener extends StatefulWidget {
  RegularFileOpener({
    Key? key,
    required this.attachment,
    required this.file,
  }) : super(key: key);
  final Attachment attachment;
  final File file;

  @override
  _RegularFileOpenerState createState() => _RegularFileOpenerState();
}

class _RegularFileOpenerState extends State<RegularFileOpener> {
  @override
  Widget build(BuildContext context) {
    IconData fileIcon = AttachmentHelper.getIcon(widget.attachment!.mimeType ?? "");

    return Container(
      height: 140,
      width: 200,
      color: Theme.of(context).accentColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            basename(widget.file!.path),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyText2,
          ),
          CupertinoButton(
            child: Icon(
              fileIcon,
              color: Theme.of(context).textTheme.bodyText2!.color,
            ),
            onPressed: () async {
              try {
                await MethodChannelInterface().invokeMethod(
                  "open_file",
                  {
                    "path": "/attachments/" + widget.attachment!.guid! + "/" + basename(widget.file!.path),
                    "mimeType": widget.attachment!.mimeType,
                  },
                );
              } catch (ex) {
                showSnackbar('Error', "No handler for this file type!");
              }
            },
          ),
          Text(widget.attachment!.mimeType!, style: Theme.of(context).textTheme.bodyText2),
        ],
      ),
    );
  }
}
