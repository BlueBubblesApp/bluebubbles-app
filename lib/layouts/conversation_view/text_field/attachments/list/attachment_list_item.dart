import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';

class AttachmentListItem extends StatefulWidget {
  AttachmentListItem({
    Key key,
    this.file,
    this.onRemove,
  }) : super(key: key);
  final File file;
  final Function() onRemove;

  @override
  _AttachmentListItemState createState() => _AttachmentListItemState();
}

class _AttachmentListItemState extends State<AttachmentListItem> {
  Uint8List preview;
  String mimeType;

  @override
  void initState() {
    super.initState();
    mimeType = mime(widget.file.path);
    loadPreview();
  }

  Future<void> loadPreview() async {
    String mimeType = mime(widget.file.path);
    if (mimeType.startsWith("video/")) {
      preview = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 100,
        quality: 25,
      );
      if (this.mounted) setState(() {});
    } else if (mimeType.startsWith("image/")) {
      preview = await FlutterImageCompress.compressWithFile(
          widget.file.absolute.path,
          quality: SettingsManager().settings.lowMemoryMode ? 5 : 10);
      if (this.mounted) setState(() {});
    }
  }

  Widget getThumbnail() {
    if (preview != null) {
      return InkWell(
        child: Image.memory(
          preview,
          height: 100,
          width: 100,
          fit: BoxFit.cover,
        ),
        onTap: () async {
          if (!this.mounted) return;

          Attachment fakeAttachment = new Attachment(
              transferName: widget.file.path, mimeType: mimeType);
          CurrentChat currentChat = CurrentChat.of(context);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AttachmentFullscreenViewer(
                allAttachments: [fakeAttachment],
                currentChat: currentChat,
                attachment: fakeAttachment,
                showInteractions: false,
              ),
            ),
          );
        },
      );
    } else {
      if (mimeType.startsWith("video/") || mimeType.startsWith("image/")) {
        // If the preview is null and the mimetype is video or image,
        // then that means that we are in the process of loading things
        return Container(
          height: 100,
          child: Center(
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
        );
      } else {
        return Container(
          height: 100,
          width: 100,
          color: Theme.of(context).accentColor,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                AttachmentHelper.getIcon(mimeType),
                color: Theme.of(context).textTheme.bodyText1.color,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    path.basename(widget.file.path),
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        children: <Widget>[
          getThumbnail(),
          if (mimeType.startsWith("video/"))
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          Align(
            alignment: Alignment.topRight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                color: Colors.black,
              ),
              width: 25,
              height: 25,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
