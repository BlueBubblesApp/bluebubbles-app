import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:save_in_gallery/save_in_gallery.dart';

class ImageViewer extends StatefulWidget {
  ImageViewer({
    Key key,
    this.tag,
    this.file,
    this.bytes,
  }) : super(key: key);
  final String tag;
  final File file;
  final Uint8List bytes;

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
                imageProvider: MemoryImage(widget.bytes),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 50.0, right: 10),
              child: Align(
                alignment: Alignment.topRight,
                child: CupertinoButton(
                  onPressed: () async {
                    if (await Permission.storage.request().isGranted) {
                      await ImageGallerySaver.saveFile(widget.file.path);
                      FlutterToast(context).showToast(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25.0),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25.0),
                                color: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyText1
                                        .color,
                                  ),
                                  SizedBox(
                                    width: 12.0,
                                  ),
                                  Text(
                                    "Saved to gallery",
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
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
