import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';

class StickerWidget extends StatefulWidget {
  StickerWidget({
    Key key,
    @required this.attachment,
  }) : super(key: key);
  final Attachment attachment;

  @override
  _StickerWidgetState createState() => _StickerWidgetState();
}

class _StickerWidgetState extends State<StickerWidget> {
  bool _visible = true;
  bool triedDownload = false;

  void toggleShow() {
    if (!this.mounted) return;
    setState(() { _visible = !_visible; });
  }

  @override
  Widget build(BuildContext context) {
    // Make sure the attachment exists
    String pathName = AttachmentHelper.getAttachmentPath(widget.attachment);
    if (FileSystemEntity.typeSync(pathName) == FileSystemEntityType.notFound) {
      // We probably don't want to try the download again
      if (!triedDownload) {
        triedDownload = true;
        AttachmentDownloader(widget.attachment, onComplete: () {
          if (this.mounted) setState(() {});
        });
      }

      return Container();
    }

    return GestureDetector(
      onTap: toggleShow,
      child: Opacity(
        key: new Key(widget.attachment.guid),
        opacity: _visible ? 1.0 : 0.25,
        child: Image.file(new File(pathName),
          width: MediaQuery.of(context).size.width * 2 / 3,
          height: MediaQuery.of(context).size.width * 2 / 4
        )
      )
    );
  }
}
