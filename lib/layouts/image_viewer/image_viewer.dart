import 'dart:io';
import 'dart:ui';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatefulWidget {
  ImageViewer({
    Key key,
    this.tag,
    this.file,
    this.attachment,
    this.showInteractions,
  }) : super(key: key);
  final String tag;
  final File file;
  final Attachment attachment;
  final bool showInteractions;

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
    // controller.outputStateStream.listen((event) {
    //   if (AttachmentFullscreenViewer.of(context) == null) return;
    //   if (this.mounted) {
    //     AttachmentFullscreenViewerState state =
    //         AttachmentFullscreenViewer.of(context);
    //     debugPrint("Scale: ${event.scale}");
    //     if (event.scale > controller.initial.scale) {
    //       if (state.physics != NeverScrollableScrollPhysics()) {
    //         AttachmentFullscreenViewer.of(context).setState(() {
    //           AttachmentFullscreenViewer.of(context).physics =
    //               NeverScrollableScrollPhysics();
    //         });
    //       }
    //     } else {
    //       if (state.physics !=
    //           AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())) {
    //         AttachmentFullscreenViewer.of(context).setState(() {
    //           AttachmentFullscreenViewer.of(context).physics =
    //               AlwaysScrollableScrollPhysics(
    //                   parent: BouncingScrollPhysics());
    //         });
    //       }
    //     }
    //   }
    // });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget overlay = AnimatedOpacity(
      opacity: showOverlay ? 1.0 : 0.0,
      duration: Duration(milliseconds: 125),
      child: Container(
        height: 120.0,
        width: MediaQuery.of(context).size.width,
        color: Colors.black.withOpacity(0.65),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: CupertinoButton(
                onPressed: () async {
                  if (await Permission.storage.request().isGranted) {
                    await ImageGallerySaver.saveFile(widget.file.absolute.path);
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
                                  style: Theme.of(context).textTheme.bodyText1,
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
            Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: CupertinoButton(
                onPressed: () async {
                  // final Uint8List bytes = await widget.file.readAsBytes();
                  await Share.file(
                    "Shared ${widget.attachment.mimeType.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                    widget.attachment.transferName,
                    widget.file.path,
                    widget.attachment.mimeType,
                  );
                },
                child: Icon(
                  Icons.share,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (!this.mounted || !widget.showInteractions) return;

          setState(() {
            showOverlay = !showOverlay;
          });
        },
        child: Stack(
          children: <Widget>[
            PhotoView(
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 13,
              controller: controller,
              imageProvider: FileImage(widget.file),
              loadingBuilder: (BuildContext context, ImageChunkEvent ev) {
                return PhotoView(
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained * 13,
                  controller: controller,
                  imageProvider: FileImage(widget.file),
                );
              },
            ),
            overlay
          ],
        ),
      ),
    );
  }
}
