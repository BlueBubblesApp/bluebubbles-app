import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StickersWidget extends StatefulWidget {
  StickersWidget({Key? key, required this.messages}) : super(key: key);
  final List<Message> messages;

  @override
  _StickersWidgetState createState() => _StickersWidgetState();
}

class _StickersWidgetState extends State<StickersWidget> {
  bool _visible = true;
  List<Attachment> stickers = [];
  List<String> loaded = [];
  Completer? request;

  @override
  void initState() {
    super.initState();
    loadStickers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadStickers();
  }

  void toggleShow() {
    if (!mounted) return;
    setState(() {
      _visible = !_visible;
    });
  }

  Future<void> loadStickers() async {
    // If we are already trying to load the stickers, don't try again
    if (request != null && !request!.isCompleted) {
      return;
    }

    request = Completer();

    // For each message, load the sticker for it
    for (Message msg in widget.messages) {
      // If the message type isn't a sticker, skip it
      if (msg.associatedMessageType != "sticker") continue;

      // Get the associated attachments
      await msg.fetchAttachments();
      for (Attachment? attachment in msg.attachments!) {
        // If we've already loaded it, don't try again
        if (loaded.contains(attachment!.guid)) continue;

        loaded.add(attachment.guid!);
        String pathName = AttachmentHelper.getAttachmentPath(attachment);

        // Check if the attachment exists
        if (await FileSystemEntity.type(pathName) == FileSystemEntityType.notFound) {
          // Download the attachment and when complete, re-render the UI
          Get.put(AttachmentDownloadController(attachment: attachment, onComplete: () async {
            // Make sure it downloaded correctly
            if (await FileSystemEntity.type(pathName) == FileSystemEntityType.notFound) {
              // Add the attachment as a sticker, and re-render the UI
              stickers.add(attachment);
              if (mounted) setState(() {});
            }
          }), tag: attachment.guid);
        } else {
          stickers.add(attachment);
        }
      }
    }

    // Fulfill/Complete any outstanding requests
    if (mounted) setState(() {});
    request!.complete();
  }

  @override
  Widget build(BuildContext context) {
    if (this.stickers.isEmpty) return Container();

    // Turn the attachments into Image Widgets
    List<Widget> stickers = this.stickers.map((item) {
      String pathName = AttachmentHelper.getAttachmentPath(item);
      dynamic file = File(pathName);
      return Image.file(file, width: CustomNavigator.width(context) * 2 / 3, height: CustomNavigator.width(context) * 2 / 4);
    }).toList();

    return GestureDetector(
        onTap: toggleShow,
        child: Opacity(
            key: Key(this.stickers.first.guid!),
            opacity: _visible ? 1.0 : 0.25,
            child: Stack(children: stickers, alignment: Alignment.center)));
  }
}
