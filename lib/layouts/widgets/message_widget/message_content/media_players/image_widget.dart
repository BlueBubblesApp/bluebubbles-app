import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

class _ImageWidgetState extends State<ImageWidget> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool navigated = false;
  bool visible = true;
  Uint8List data;
  bool initGate = false;

  void _initializeBytes({runForcefully: false}) async {
    // initGate prevents this from running more than once
    // Especially if the compression takes a while
    if (!runForcefully && (initGate || data != null)) return;
    initGate = true;

    // Try to get the image data from the "cache"
    data = CurrentChat.of(context).getImageData(widget.attachment);
    if (data == null) {
      // If it's an image, compress the image when loading it
      if (AttachmentHelper.canCompress(widget.attachment)) {
        data = await FlutterImageCompress.compressWithFile(widget.file.absolute.path,
            quality: SettingsManager().compressionQuality);

        // All other attachments can be held in memory as bytes
      } else {
        data = await widget.file.readAsBytes();
      }

      CurrentChat.of(context)?.saveImageData(data, widget.attachment);
      if (this.mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _initializeBytes();

    return VisibilityDetector(
      key: Key(widget.attachment.guid),
      onVisibilityChanged: (info) {
        if (!SettingsManager().settings.lowMemoryMode) return;
        if (info.visibleFraction == 0 && visible && !navigated) {
          visible = false;
          CurrentChat.of(context)?.clearImageData(widget.attachment);
          if (this.mounted) setState(() {});
        } else if (!visible) {
          visible = true;
          _initializeBytes(runForcefully: true);
        }
      },
      child: Stack(
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width / 2,
              maxHeight: MediaQuery.of(context).size.height / 2,
            ),
            child: buildSwitcher(),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (!this.mounted) return;

                  navigated = true;

                  CurrentChat currentChat = CurrentChat.of(context);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AttachmentFullscreenViewer(
                        currentChat: currentChat,
                        attachment: widget.attachment,
                        showInteractions: true,
                      ),
                    ),
                  );

                  navigated = false;
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
        child: data != null
            ? Image.memory(
                data,
                //width: widget.attachment.width.toDouble(),
                //height: widget.attachment.height.toDouble(),
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;

                  return Stack(children: [
                    buildPlaceHolder(),
                    AnimatedOpacity(
                      opacity: (frame == null) ? 0 : 1,
                      child: child,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                  ]);
                },
              )
            : buildPlaceHolder(),
      );

  Widget buildPlaceHolder() {
    if (widget.attachment.hasValidSize) {
      return AspectRatio(
        aspectRatio: widget.attachment.width.toDouble() / widget.attachment.height.toDouble(),
        child: Container(
            width: widget.attachment.width.toDouble(),
            height: widget.attachment.height.toDouble(),
            color: Theme.of(context).accentColor,
            child: Center(
                child: CircularProgressIndicator(
                    valueColor: new AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)))),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(5),
        height: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Theme.of(context).accentColor,
            child: Center(
              child: Text("Invalid Image"),
            ),
          ),
        ),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}
