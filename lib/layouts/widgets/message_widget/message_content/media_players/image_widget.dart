import 'dart:io';

import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidget extends StatefulWidget {
  ImageWidget({Key key, this.file, this.attachment, this.savedAttachmentData})
      : super(key: key);
  final File file;
  final Attachment attachment;
  final SavedAttachmentData savedAttachmentData;

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget>
    with TickerProviderStateMixin {
  bool navigated = false;
  bool visible = true;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _initializeBytes();
  }

  void _initializeBytes() async {
    if (!widget.savedAttachmentData.imageData
        .containsKey(widget.attachment.guid)) {
      // If it's an image, compress the image when loading it
      if (AttachmentHelper.canCompress(widget.attachment)) {
        widget.savedAttachmentData.imageData[widget.attachment.guid] =
            await FlutterImageCompress.compressWithFile(
                widget.file.absolute.path,
                quality: 25 // This is arbitrary
                );

        // All other attachments can be held in memory as bytes
      } else {
        widget.savedAttachmentData.imageData[widget.attachment.guid] =
            await widget.file.readAsBytes();
      }
      if (this.mounted) setState(() {});
    }
    if (widget.attachment.width == 0 ||
        widget.attachment.height == 0 ||
        widget.attachment.width == null ||
        widget.attachment.height == null) {
      Size size = ImageSizeGetter.getSize(MemoryInput(
          widget.savedAttachmentData.imageData[widget.attachment.guid]));
      widget.attachment.width = size.width;
      widget.attachment.height = size.height;
      if (this.mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.attachment.guid),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0 && visible && !navigated) {
          visible = false;
          if (widget.savedAttachmentData.imageData
              .containsKey(widget.attachment.guid)) {
            widget.savedAttachmentData.imageData.remove(widget.attachment.guid);
          }
        } else if (!visible) {
          visible = true;
          _initializeBytes();
        }
        if (this.mounted) setState(() {});
      },
      child: Stack(
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width / 2,
              maxHeight: MediaQuery.of(context).size.height / 2,
            ),
            child: AspectRatio(
              aspectRatio: widget.attachment.width != null &&
                      widget.attachment.height != null &&
                      widget.attachment.width > 0 &&
                      widget.attachment.height > 0
                  ? widget.attachment.width / widget.attachment.height
                  : MediaQuery.of(context).size.width / 5,
              child: widget.savedAttachmentData
                          .imageData[widget.attachment.guid] ==
                      null
                  ? Container(
                      height: 5,
                      child: Center(
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                    )
                  : Container(
                      child: Hero(
                        tag: widget.attachment.guid,
                        child: AnimatedSize(
                          vsync: this,
                          curve: Curves.easeInOut,
                          alignment: Alignment.center,
                          duration: Duration(milliseconds: 250),
                          child: Image.memory(
                            widget.savedAttachmentData
                                .imageData[widget.attachment.guid],
                          ),
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height / 3,
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  setState(() {
                    navigated = true;
                  });
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ImageViewer(
                        attachment: widget.attachment,
                        file: widget.file,
                        bytes: widget.savedAttachmentData
                            .imageData[widget.attachment.guid],
                        tag: widget.attachment.guid,
                      ),
                    ),
                  );
                  setState(() {
                    navigated = false;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
