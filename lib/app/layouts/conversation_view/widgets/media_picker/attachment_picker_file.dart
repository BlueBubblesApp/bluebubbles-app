import 'dart:typed_data';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:photo_manager/photo_manager.dart';

class AttachmentPickerFile extends StatefulWidget {
  AttachmentPickerFile({
    super.key,
    required this.onTap,
    required this.data,
    required this.controller,
  });
  final AssetEntity data;
  final Function() onTap;
  final ConversationViewController controller;

  @override
  State<AttachmentPickerFile> createState() => _AttachmentPickerFileState();
}

class _AttachmentPickerFileState extends OptimizedState<AttachmentPickerFile> with AutomaticKeepAliveClientMixin {
  Uint8List? image;
  String? path;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final file = (await widget.data.file)!;
    path = file.path;
    if (widget.data.mimeType?.startsWith("video/") ?? false) {
      try {
        image = await as.getVideoThumbnail(file.path, useCachedFile: false);
      } catch (ex) {
        image = fs.noVideoPreviewIcon;
      }
      setState(() {});
    } else if (widget.data.mimeType == "image/heic"
        || widget.data.mimeType == "image/heif"
        || widget.data.mimeType == "image/tif"
        || widget.data.mimeType == "image/tiff") {
      final fakeAttachment = Attachment(
        transferName: file.path,
        mimeType: widget.data.mimeType!,
      );
      image = await as.loadAndGetProperties(fakeAttachment, actualPath: file.path, onlyFetchData: true, isPreview: true);
      setState(() {});
    } else {
      image = await file.readAsBytes();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideAttachments = ss.settings.redactedMode.value && ss.settings.hideAttachments.value;

    super.build(context);
    return Obx(() {
      bool containsThis = widget.controller.pickedAttachments.firstWhereOrNull((e) => e.path == path) != null;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.all(containsThis ? 10 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: Stack(
            alignment: Alignment.center,
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
                      return Positioned.fill(
                        child: Container(
                          color: context.theme.colorScheme.properSurface,
                        ),
                      );
                    } else {
                      return child;
                    }
                  },
                ),
              if (image == null || hideAttachments)
                Positioned.fill(
                  child: Container(
                    color: context.theme.colorScheme.properSurface,
                    alignment: Alignment.center,
                    child: Text(
                      mime(path) ?? "",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (containsThis || widget.data.type == AssetType.video)
                Container(
                  decoration: containsThis ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.theme.colorScheme.primary
                  ) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Icon(
                      containsThis
                          ? (iOS ? CupertinoIcons.check_mark : Icons.check)
                          : (iOS ? CupertinoIcons.play_circle_fill : Icons.play_circle_filled),
                      color: context.theme.colorScheme.onPrimary,
                      size: containsThis ? 18 : 50,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  @override
  bool get wantKeepAlive => true;
}
