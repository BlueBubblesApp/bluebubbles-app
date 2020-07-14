import 'dart:async';
import 'dart:io';

import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatefulWidget {
  ImageViewer({
    Key key,
    this.tag,
    this.file,
  }) : super(key: key);
  final String tag;
  final File file;

  @override
  _ImageViewerState createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  double top = 0;
  int duration = 0;
  PhotoViewController controller;
  bool showOverlay = false;

  @override
  void initState() {
    super.initState();
    controller = new PhotoViewController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {},
        child: Stack(
          children: <Widget>[
            PhotoViewGestureDetectorScope(
              child: PhotoView(
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 13,
                controller: controller,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: widget.tag,
                ),
                imageProvider: FileImage(widget.file),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 50.0, right: 10),
              child: Align(
                alignment: Alignment.topRight,
                child: CupertinoButton(
                  onPressed: () {
                    debugPrint("path " + widget.file.path);
                    MethodChannelInterface().invokeMethod(
                        "save-image-to-album", {"path": widget.file.path});
                  },
                  child: Icon(
                    Icons.file_download,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
      // ),
    );
  }
}
