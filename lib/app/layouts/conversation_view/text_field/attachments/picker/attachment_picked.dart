import 'dart:typed_data';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/text_field/blue_bubbles_text_field.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:universal_io/io.dart';

class AttachmentPicked extends StatefulWidget {
  AttachmentPicked({Key? key, required this.onTap, required this.data}) : super(key: key);
  final AssetEntity data;
  final Function onTap;

  @override
  State<AttachmentPicked> createState() => _AttachmentPickedState();
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
        image = await as.getVideoThumbnail(file.path, useCachedFile: false);
      } catch (ex) {
        image = fs.noVideoPreviewIcon;
      }

      if (mounted) setState(() {});
    } else if (widget.data.mimeType == "image/heic"
        || widget.data.mimeType == "image/heif"
        || widget.data.mimeType == "image/tif"
        || widget.data.mimeType == "image/tiff") {
      Attachment fakeAttachment = Attachment(
        transferName: file.path,
        mimeType: widget.data.mimeType!,
      );
      image = await as.loadAndGetProperties(fakeAttachment, actualPath: file.path, onlyFetchData: true);
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
        ss.settings.redactedMode.value && ss.settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        ss.settings.redactedMode.value && ss.settings.hideAttachmentTypes.value;
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
                          color: context.theme.colorScheme.properSurface,
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
                    color: context.theme.colorScheme.properSurface,
                  ),
                if (hideAttachments)
                  Positioned.fill(
                    child: Container(
                      color: context.theme.colorScheme.properSurface,
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
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.theme.colorScheme.primary
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Icon(
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.check_mark : Icons.check,
                        color: context.theme.colorScheme.onPrimary,
                        size: 18,
                      ),
                    ),
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
                  ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play_circle_fill : Icons.play_circle_filled,
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
