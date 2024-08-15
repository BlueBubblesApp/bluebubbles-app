import 'dart:async';
import 'dart:typed_data';

import 'package:animations/animations.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:universal_io/io.dart';

class PickedAttachment extends StatefulWidget {
  PickedAttachment({
    super.key,
    required this.data,
    required this.controller,
    required this.onRemove,
  });
  final PlatformFile data;
  final ConversationViewController? controller;
  final Function(PlatformFile) onRemove;

  @override
  State<PickedAttachment> createState() => _PickedAttachmentState();
}

class _PickedAttachmentState extends OptimizedState<PickedAttachment> with AutomaticKeepAliveClientMixin {
  Uint8List? image;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final file = widget.data;
    final mimeType = mime(widget.data.name) ?? "";
    if (mimeType.startsWith("video/") && Platform.isAndroid) {
      try {
        image = await as.getVideoThumbnail(file.path!, useCachedFile: false);
      } catch (ex) {
        image = fs.noVideoPreviewIcon;
      }
      setState(() {});
    } else if (mimeType == "image/heic"
        || mimeType == "image/heif"
        || mimeType == "image/tif"
        || mimeType == "image/tiff") {
      final fakeAttachment = Attachment(
        transferName: file.path,
        mimeType: mimeType,
      );
      image = await as.loadAndGetProperties(fakeAttachment, actualPath: file.path, onlyFetchData: true);
      setState(() {});
    } else if (mimeType.startsWith("image/")) {
      setState(() {
        image = file.bytes;
      });
    } else {
      setState(() {
        image = Uint8List.fromList([]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: iOS ? const EdgeInsets.all(5) : const EdgeInsets.only(top: 15, left: 7.5, right: 7.5, bottom: 15),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            constraints: BoxConstraints(maxWidth: image == null ? 0 : (image?.isEmpty ?? false) ? 100 : 200),
            clipBehavior: Clip.antiAlias,
            child: OpenContainer(
              tappable: false,
              openColor: Colors.black,
              closedColor: context.theme.colorScheme.background,
              openBuilder: (_, closeContainer) {
                final fakeAttachment = Attachment(
                  transferName: widget.data.name,
                  mimeType: mime(widget.data.name) ?? "",
                  bytes: widget.data.bytes,
                );
                return FullscreenMediaHolder(
                  attachment: fakeAttachment,
                  showInteractions: false,
                );
              },
              closedBuilder: (_, openContainer) {
                return InkWell(
                  onTap: mime(widget.data.name)?.startsWith("image") ?? false ? openContainer : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topRight,
                    children: <Widget>[
                      if (image?.isNotEmpty ?? false)
                        Image.memory(
                          image!,
                          key: ValueKey(widget.data.path),
                          gaplessPlayback: true,
                          fit: iOS ? BoxFit.fitHeight : BoxFit.cover,
                          height: iOS ? 150 : 75,
                          width: iOS ? null : 75,
                          cacheWidth: 300,
                        ),
                      if (image?.isEmpty ?? false)
                        Positioned.fill(
                          child: Container(
                            color: context.theme.colorScheme.properSurface,
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                widget.data.name,
                                maxLines: 3,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      if (image != null && iOS)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: context.theme.colorScheme.outline,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(0),
                              maximumSize: const Size(32, 32),
                              minimumSize: const Size(32, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              if (widget.controller != null) {
                                widget.controller!.pickedAttachments.removeWhere((e) => e.path == widget.data.path);
                                widget.controller!.chat.textFieldAttachments.removeWhere((e) => e == widget.data.path);
                                widget.controller!.chat.save(updateTextFieldAttachments: true);
                              } else {
                                widget.onRemove.call(widget.data);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }
            ),
          ),
          if (!iOS)
            Positioned(
              top: -7,
              right: -7,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: context.theme.colorScheme.secondary,
                  shape: CircleBorder(
                    side: BorderSide(color: context.theme.colorScheme.properSurface)
                  ),
                  padding: const EdgeInsets.all(0),
                  maximumSize: const Size(25, 25),
                  minimumSize: const Size(25, 25),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Icon(
                  Icons.close,
                  color: context.theme.colorScheme.background,
                  size: 18,
                ),
                onPressed: () {
                  if (widget.controller != null) {
                    widget.controller!.pickedAttachments.removeWhere((e) => e.path == widget.data.path);
                    widget.controller!.chat.textFieldAttachments.removeWhere((e) => e == widget.data.path);
                    widget.controller!.chat.save(updateTextFieldAttachments: true);
                  } else {
                    widget.onRemove.call(widget.data);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
