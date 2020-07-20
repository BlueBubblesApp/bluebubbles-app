import 'dart:io';

import 'package:bluebubble_messages/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ImageWidget extends StatefulWidget {
  ImageWidget({Key key, this.file, this.attachment, this.savedAttachmentData})
      : super(key: key);
  final File file;
  final Attachment attachment;
  final SavedAttachmentData savedAttachmentData;

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (!widget.savedAttachmentData.imageData
        .containsKey(widget.attachment.guid)) {
      widget.savedAttachmentData.imageData[widget.attachment.guid] =
          await widget.file.readAsBytes();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.savedAttachmentData.imageData[widget.attachment.guid] == null
            ? Container()
            : Hero(
                tag: widget.attachment.guid,
                child: Image.memory(widget
                    .savedAttachmentData.imageData[widget.attachment.guid]),
              ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint(widget.file.path);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ImageViewer(
                      file: widget.file,
                      bytes: widget.savedAttachmentData
                          .imageData[widget.attachment.guid],
                      tag: widget.attachment.guid,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
