import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

class StickersWidget extends StatefulWidget {
  StickersWidget({
    Key key,
    @required this.messages
  }) : super(key: key);
  final List<Message> messages;

  @override
  _StickersWidgetState createState() => _StickersWidgetState();
}

class _StickersWidgetState extends State<StickersWidget> {
  bool _visible = true;
  List<Attachment> stickers = [];
  List<String> loaded = [];
  Completer request;

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
    if (!this.mounted) return;
    setState(() { _visible = !_visible; });
  }

  Future<void> loadStickers() async {
    // If we are already trying to load the stickers, don't try again
    if (request != null && !request.isCompleted) {
      return request;
    }

    request = new Completer();

    // For each message, load the sticker for it
    for (Message msg in widget.messages) {
      // If the message type isn't a sticker, skip it
      if (msg.associatedMessageType != "sticker") continue;

      // Get the associated attachments
      List<Attachment> attachments = await Message.getAttachments(msg);
      for (Attachment attachment in attachments) {
        // If we've already loaded it, don't try again
        if (loaded.contains(attachment.guid)) continue;

        loaded.add(attachment.guid);
        String pathName = AttachmentHelper.getAttachmentPath(attachment);

        // Check if the attachment exists
        if (FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound) {
          // Download the attachment and when complete, re-render the UI
          AttachmentDownloader(attachment, onComplete: () {
            // Make sure it downloaded correctly
            if (FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound) {

              // Add the attachment as a sticker, and re-render the UI
              stickers.add(attachment);
              if (this.mounted) setState(() {});
            }
          });
        } else {
          stickers.add(attachment);
        }
      }
    }
    
    // Fulfill/Complete any outstanding requests
    if (this.mounted) setState(() {});
    request.complete();
  }

  @override
  Widget build(BuildContext context) {
    if (this.stickers.length == 0) return Container();

    // Turn the attachments into Image Widgets
    List<Widget> stickers = this.stickers.map((item) {
      String pathName = AttachmentHelper.getAttachmentPath(item);
      return Image.file(new File(pathName),
          width: MediaQuery.of(context).size.width * 2 / 3,
          height: MediaQuery.of(context).size.width * 2 / 4
      );
    }).toList();

    return GestureDetector(
      onTap: toggleShow,
      child: Opacity(
        key: new Key(this.stickers.first.guid),
        opacity: _visible ? 1.0 : 0.25,
        child: Stack(
          children: stickers,
          alignment: Alignment.center
        )
      )
    );
  }
}
