import 'package:bluebubbles/repository/models/platform_file.dart';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as path;

class AttachmentListItem extends StatefulWidget {
  AttachmentListItem({
    Key? key,
    required this.file,
    required this.onRemove,
  }) : super(key: key);
  final PlatformFile file;
  final Function() onRemove;

  @override
  _AttachmentListItemState createState() => _AttachmentListItemState();
}

class _AttachmentListItemState extends State<AttachmentListItem> {
  Uint8List? preview;
  String? mimeType;

  @override
  void initState() {
    super.initState();
    mimeType = mime(widget.file.name);
    loadPreview();
  }

  Future<void> loadPreview() async {
    String? mimeType = mime(widget.file.name);
    if (mimeType != null && mimeType.startsWith("video/") && widget.file.path != null) {
      preview = await AttachmentHelper.getVideoThumbnail(widget.file.path!);
      if (this.mounted) setState(() {});
    } else if (mimeType == null || mimeType.startsWith("image/")) {
      // Compress the file, using a dummy attachment object
      preview = widget.file.bytes;
      if (this.mounted) setState(() {});
    }
  }

  Widget getThumbnail() {
    if (preview != null) {
      final bool hideAttachments =
          SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
      final bool hideAttachmentTypes =
          SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;

      final mimeType = mime(widget.file.name);

      return Stack(children: <Widget>[
        InkWell(
          child: Image.memory(
            preview!,
            height: 100,
            width: 100,
            fit: BoxFit.cover,
          ),
          onTap: () async {
            if (mimeType == null) return;
            if (!this.mounted) return;

            Attachment fakeAttachment = new Attachment(transferName: widget.file.name, mimeType: mimeType, bytes: widget.file.bytes);
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  attachment: fakeAttachment,
                  showInteractions: false,
                ),
              ),
            );
          },
        ),
        if (hideAttachments)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).accentColor,
            ),
          ),
        if (hideAttachments && !hideAttachmentTypes)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                mimeType!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]);
    } else {
      if (mimeType == null || mimeType!.startsWith("video/") || mimeType!.startsWith("image/")) {
        // If the preview is null and the mimetype is video or image,
        // then that means that we are in the process of loading things
        return Container(
          height: 100,
          child: Center(
            child: buildProgressIndicator(context),
          ),
        );
      } else {
        String name = path.basename(widget.file.name);
        if (mimeType == "text/x-vcard") {
          name = "Contact: ${name.split(".")[0]}";
        }

        return Container(
          height: 100,
          width: 100,
          color: Theme.of(context).accentColor,
          padding: EdgeInsets.only(top: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AttachmentHelper.getIcon(mimeType ?? ""),
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeDelta: -2),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: <Widget>[
          getThumbnail(),
          if (mimeType != null && mimeType!.startsWith("video/"))
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          GestureDetector(
            onTap: widget.onRemove,
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  color: Colors.black,
                ),
                width: 25,
                height: 25,
                child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.xmark : Icons.close,
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
