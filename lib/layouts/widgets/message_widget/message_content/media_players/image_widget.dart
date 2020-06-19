import 'dart:io';

import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:flutter/material.dart';

class ImageWidget extends StatefulWidget {
  ImageWidget({Key key, this.file, this.attachment}) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Image.file(widget.file),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}
