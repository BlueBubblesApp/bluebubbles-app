import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidget extends StatefulWidget {
  ImageWidget({
    Key key,
    this.file,
    this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget>
    with TickerProviderStateMixin {
  bool navigated = false;
  bool visible = true;
  Uint8List data;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _initializeBytes();
  }

  void _initializeBytes() async {
    data = CurrentChat.of(context).getImageData(widget.attachment);
    if (data == null) {
      // If it's an image, compress the image when loading it
      if (AttachmentHelper.canCompress(widget.attachment)) {
        data = await FlutterImageCompress.compressWithFile(
            widget.file.absolute.path,
            quality: SettingsManager().settings.lowMemoryMode
                ? 15
                : 25 // This is arbitrary
            );

        // All other attachments can be held in memory as bytes
      } else {
        data = await widget.file.readAsBytes();
      }
      CurrentChat.of(context).saveImageData(data, widget.attachment);
      if (this.mounted) setState(() {});
    }
    if (widget.attachment.width == 0 ||
        widget.attachment.height == 0 ||
        widget.attachment.width == null ||
        widget.attachment.height == null) {
      Size size = ImageSizeGetter.getSize(MemoryInput(data));
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
        if (!SettingsManager().settings.lowMemoryMode) return;
        if (info.visibleFraction == 0 && visible && !navigated) {
          visible = false;
          CurrentChat.of(context).clearImageData(widget.attachment);
          if (this.mounted) setState(() {});
        } else if (!visible) {
          visible = true;
          _initializeBytes();
        }
      },
      child: Stack(
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width / 2,
              maxHeight: MediaQuery.of(context).size.height / 2,
            ),
            child: Container(
              child: Hero(
                tag: widget.attachment.guid,
                child: AspectRatio(
                  aspectRatio: widget.attachment.width != null &&
                          widget.attachment.height != null
                      ? (widget.attachment.width / widget.attachment.height)
                          .toDouble()
                      : 0,
                  child: buildSwitcher(),
                ),
              ),
              color: Colors.transparent,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height / 3,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (!this.mounted) return;

                  setState(() {
                    navigated = true;
                  });
                  CurrentChat currentChat = CurrentChat.of(context);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AttachmentFullscreenViewer(
                        currentChat: currentChat,
                        allAttachments: currentChat.chatAttachments,
                        attachment: widget.attachment,
                        showInteractions: true,
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

  Widget buildSwitcher() => AnimatedSwitcher(
        duration: Duration(milliseconds: 150),
        child: data != null ? Image.memory(data) : Container(),
      );
}
