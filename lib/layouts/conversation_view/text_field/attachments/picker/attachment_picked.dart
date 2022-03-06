import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:universal_io/io.dart';

class AttachmentPicked extends StatefulWidget {
  AttachmentPicked({Key? key, required this.onTap, required this.data}) : super(key: key);
  final AssetEntity data;
  final Function onTap;

  @override
  _AttachmentPickedState createState() => _AttachmentPickedState();
}

class _AttachmentPickedState extends State<AttachmentPicked> with AutomaticKeepAliveClientMixin {
  Uint8List? image;
  String? path;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    path = (await widget.data.file)!.path;
    final file = File(path!);
    if (widget.data.mimeType != null && widget.data.mimeType!.startsWith("video/")) {
      try {
        image = await AttachmentHelper.getVideoThumbnail(file.path, useCachedFile: false);
      } catch (ex) {
        image = ChatManager().noVideoPreviewIcon;
      }

      if (mounted) setState(() {});
    } else if (widget.data.mimeType == "image/heic"
        || widget.data.mimeType == "image/heif"
        || widget.data.mimeType == "image/tif"
        || widget.data.mimeType == "image/tiff") {
      Attachment fakeAttachment = Attachment(transferName: file.path,
        mimeType: widget.data.mimeType!,
      );
      image = await AttachmentHelper.compressAttachment(
          fakeAttachment, file.path, qualityOverride: 100,
          getActualPath: false);
      if (mounted) setState(() {});
    } else {
      image = await file.readAsBytes();
      if (mounted) setState(() {});
    }
  }

  bool get containsThis =>
      BlueBubblesTextField.of(context)!.pickedImages.where((element) => element.path == path).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool hideAttachments =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      padding: EdgeInsets.all(containsThis ? 20 : 5),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: <Widget>[
                if (image != null)
                  Image.memory(
                    image!,
                    fit: BoxFit.cover,
                    width: 150,
                    height: 150,
                    cacheWidth: 300,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (frame == null) {
                        return Container(
                          width: 150,
                          height: 150,
                          color: Theme.of(context).colorScheme.secondary,
                        );
                      } else {
                        return child;
                      }
                    },
                  ),
                if (image == null)
                  Container(
                    width: 150,
                    height: 150,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                if (hideAttachments)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                if (hideAttachments && !hideAttachmentTypes)
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        mime(path)!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (containsThis)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                child: Center(
                  child: Icon(
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.check_mark_circled_solid : Icons.check_circle,
                    color: Colors.white,
                  ),
                ),
                color: Colors.white.withAlpha(50),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                child: widget.data.type == AssetType.video
                    ? Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.play_circle_fill : Icons.play_circle_filled,
                  color: Colors.white.withOpacity(0.5),
                  size: 50,
                )
                    : Container(),
                onTap: () async {
                  widget.onTap();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
