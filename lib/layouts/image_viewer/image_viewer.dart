import 'dart:io';

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
  double left = 0;
  double top = 0;
  int duration = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          AnimatedPositioned(
            onEnd: () => duration = 0,
            left: left,
            top: top,
            duration: Duration(milliseconds: duration),
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: PhotoView(
                heroAttributes: PhotoViewHeroAttributes(
                  tag: widget.tag,
                ),
                imageProvider: FileImage(widget.file),
              ),
            ),
          ),
          GestureDetector(
            onPanUpdate: (details) {
              debugPrint(details.delta.dx.toString());
              setState(() {
                left += details.delta.dx;
                top += details.delta.dy;
              });
            },
            onPanEnd: (details) {
              if (left.abs() > MediaQuery.of(context).size.width / 7 ||
                  top.abs() > MediaQuery.of(context).size.height / 7) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  top = 0;
                  left = 0;
                  duration = 200;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
