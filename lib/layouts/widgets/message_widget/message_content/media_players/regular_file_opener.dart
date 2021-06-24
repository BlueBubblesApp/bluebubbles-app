import 'dart:io';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
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
    IconData fileIcon = AttachmentHelper.getIcon(widget.attachment.mimeType);

    return Container(
      height: 140,
      width: 200,
      color: Get.theme.accentColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            basename(widget.file.path),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Get.theme.textTheme.bodyText2,
          ),
          CupertinoButton(
            child: Icon(
              fileIcon,
              color: Get.theme.textTheme.bodyText2.color,
            ),
            onPressed: () async {
              try {
                await MethodChannelInterface().invokeMethod(
                  "open_file",
                  {
                    "path": "/attachments/" + widget.attachment.guid + "/" + basename(widget.file.path),
                    "mimeType": widget.attachment.mimeType,
                  },
                );
              } catch (ex) {
                final snackBar = SnackBar(content: Text("No handler for this file type!"));
                Scaffold.of(context).showSnackBar(snackBar);
              }
            },
          ),
          Text(widget.attachment.mimeType, style: Get.theme.textTheme.bodyText2),
        ],
      ),
    );
  }
}
