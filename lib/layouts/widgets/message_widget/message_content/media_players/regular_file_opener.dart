import 'dart:convert';

import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

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
  final PlatformFile file;

  @override
  _RegularFileOpenerState createState() => _RegularFileOpenerState();
}

class _RegularFileOpenerState extends State<RegularFileOpener> {
  @override
  Widget build(BuildContext context) {
    IconData fileIcon = AttachmentHelper.getIcon(widget.attachment.mimeType ?? "");

    return GestureDetector(
      onTap: () async {
        if (kIsWeb || widget.file.path == null) {
          final content = base64.encode(widget.file.bytes!);
          html.AnchorElement(
              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
            ..setAttribute("download", widget.file.name)
            ..click();
        } else {
          try {
            await MethodChannelInterface().invokeMethod(
              "open_file",
              {
                "path": "/attachments/" +
                    widget.attachment.guid! +
                    "/" +
                    basename(widget.file.path!),
                "mimeType": widget.attachment.mimeType,
              },
            );
          } catch (ex) {
            showSnackbar('Error', "No handler for this file type!");
          }
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 140,
          maxWidth: 200,
        ),
        color: Theme.of(context).accentColor,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyText2,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  fileIcon,
                  color: Theme.of(context).textTheme.bodyText2!.color,
                ),
              ),
              Text(widget.attachment.mimeType!, style: Theme.of(context).textTheme.bodyText2),
            ],
          ),
        ),
      ),
    );
  }
}
