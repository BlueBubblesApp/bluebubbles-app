import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidget extends StatefulWidget {
  ImageWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _ImageWidgetState createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool navigated = false;
  bool visible = true;
  Uint8List? data;
  bool initGate = false;

  void _initializeBytes({runForcefully: false}) async {
    // initGate prevents this from running more than once
    // Especially if the compression takes a while
    if (!runForcefully && (initGate || data != null)) return;
    initGate = true;

    // Try to get the image data from the "cache"
    data = CurrentChat.of(context)?.getImageData(widget.attachment);
    if (data == null) {
      // If it's an image, compress the image when loading it
      if (AttachmentHelper.canCompress(widget.attachment) &&
          widget.attachment.guid != "redacted-mode-demo-attachment" &&
          !widget.attachment.guid!.contains("theme-selector")) {
        data = await AttachmentHelper.compressAttachment(widget.attachment, widget.file.absolute.path);
        // All other attachments can be held in memory as bytes
      } else {
        if (widget.attachment.guid == "redacted-mode-demo-attachment" ||
            widget.attachment.guid!.contains("theme-selector")) {
          data = (await rootBundle.load(widget.file.path)).buffer.asUint8List();
          return;
        }
        data = await widget.file.readAsBytes();
      }

      if (data == null || CurrentChat.of(context) == null) return;
      CurrentChat.of(context)?.saveImageData(data!, widget.attachment);
      if (this.mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _initializeBytes();

    return VisibilityDetector(
      key: Key(widget.attachment.guid!),
      onVisibilityChanged: (info) {
        if (!SettingsManager().settings.lowMemoryMode.value) return;
        if (info.visibleFraction == 0 && visible && !navigated) {
          visible = false;
          CurrentChat.of(context)?.clearImageData(widget.attachment);
          if (this.mounted) setState(() {});
        } else if (!visible) {
          visible = true;
          _initializeBytes(runForcefully: true);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          child: buildSwitcher(),
          onTap: () async {
            if (!this.mounted) return;

            navigated = true;

            CurrentChat? currentChat = CurrentChat.of(context);
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
    );
  }

  Widget buildSwitcher() => AnimatedSwitcher(
        duration: Duration(milliseconds: 150),
        child: data != null
            ? Image.memory(
                data!,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  return Stack(children: [
                    buildPlaceHolder(isLoaded: frame != null || wasSynchronouslyLoaded),
                    AnimatedOpacity(
                      opacity: (frame == null &&
                              widget.attachment.guid != "redacted-mode-demo-attachment" &&
                              widget.attachment.guid!.contains("theme-selector"))
                          ? 0
                          : 1,
                      child: child,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                  ]);
                },
              )
            : buildPlaceHolder(),
      );

  Widget buildPlaceHolder({bool isLoaded = false}) {
    Widget empty = Container(height: 0, width: 0);

    // Handle the cases when the image is done loading
    // Handle the cases when the image is done loading
    if (isLoaded) {
      // If we have data and the image has a valid size, return an empty container (no placeholder)
      if (data != null && data!.length > 0 && widget.attachment.hasValidSize) {
        return empty;
      } else if (data != null && data!.length > 0) {
        // If we have data, but _not_ a valid size, return an empty image placeholder
        return buildImagePlaceholder(context, widget.attachment, empty);
      } else {
        // If we don't have data, show an invalid image placeholder
        return buildImagePlaceholder(context, widget.attachment, Center(child: Text("Invalid Image")));
      }
    }

    // If it's not loaded, we are in progress
    return buildImagePlaceholder(context, widget.attachment, Center(child: buildProgressIndicator(context)));
  }

  @override
  bool get wantKeepAlive => true;
}
