import 'dart:async';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class MediaGalleryCard extends StatefulWidget {
  MediaGalleryCard({Key? key, required this.attachment}) : super(key: key);
  final Attachment attachment;

  @override
  State<MediaGalleryCard> createState() => _MediaGalleryCardState();
}

class _MediaGalleryCardState extends OptimizedState<MediaGalleryCard> with AutomaticKeepAliveClientMixin {
  Uint8List? videoPreview;
  Duration? duration;
  AttachmentDownloadController? controller;
  late PlatformFile attachmentFile = PlatformFile(
    name: attachment.transferName!,
    path: kIsWeb ? null : attachment.path,
    bytes: attachment.bytes,
    size: attachment.totalBytes!,
  );

  Attachment get attachment => widget.attachment;

  @override
  void initState() {
    super.initState();

    // check active downloader otherwise check file exists
    if (attachmentDownloader.getController(attachment.guid) != null) {
      controller = attachmentDownloader.getController(attachment.guid);
      controller!.completeFuncs.add((file) {
        setState(() {
          controller = null;
          attachmentFile = file;
        });
        if (attachment.mimeType?.contains("video") ?? false) {
          getVideoPreview(file);
        }
      });
      controller!.errorFuncs.add(() {
        setState(() {
          controller = null;
        });
      });
    } else if (!kIsWeb) {
      getBytes();
    }
  }

  void downloadAttachment() {
    setState(() {
      controller = Get.put(
        AttachmentDownloadController(
          attachment: attachment,
          onComplete: (file) {
            setState(() {
              controller = null;
              attachmentFile = file;
            });
            if (attachment.mimeType?.contains("video") ?? false) {
              getVideoPreview(file);
            }
          },
          onError: () {
            setState(() {
              controller = null;
            });
            showSnackbar("Error", "Failed to download attachment!");
          },
        ),
        tag: attachment.guid,
      );
    });
  }

  Future<void> getBytes() async {
    final file = File(attachment.path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      setState(() {
        attachmentFile = PlatformFile(
          name: attachment.transferName!,
          path: attachment.path,
          bytes: bytes,
          size: attachment.totalBytes!,
        );
      });
      if (attachment.mimeType?.contains("video") ?? false) {
        getVideoPreview(attachmentFile);
      }
    }
  }

  Future<void> getVideoPreview(PlatformFile file) async {
    if (videoPreview != null || file.path == null) return;
    if (attachment.metadata?['thumbnail_status'] == 'error') {
      return;
    }

    try {
      videoPreview = await as.getVideoThumbnail(file.path!);
      dynamic _file = File(file.path!);
      final tempController = VideoPlayerController.file(_file);
      await tempController.initialize();
      duration = tempController.value.duration;
    } catch (_) {
      // If an error occurs, set the thumbnail to the cached no preview image
      videoPreview = fs.noVideoPreviewIcon;

      if (attachment.metadata?['thumbnail_status'] != 'error') {
        attachment.metadata ??= {};
        attachment.metadata!['thumbnail_status'] = 'error';
        attachment.save(null);
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool hideAttachments = ss.settings.redactedMode.value && ss.settings.hideAttachments.value;

    late Widget child;
    bool addPadding = true;

    if (hideAttachments) {
      child = Text(
        attachment.mimeType ?? "Unknown",
        textAlign: TextAlign.center,
      );
    } else if (controller != null) {
      child = SizedBox(
        height: 40,
        width: 40,
        child: Obx(() => CircleProgressBar(
          foregroundColor: context.theme.colorScheme.primary,
          backgroundColor: context.theme.colorScheme.outline,
          value: controller!.progress.value?.toDouble() ?? 0
        )),
      );
    } else if (attachmentFile.bytes == null) {
      child = InkWell(
        onTap: downloadAttachment,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              attachment.getFriendlySize(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 5),
            Icon(ss.settings.skin.value == Skins.iOS
                ? CupertinoIcons.cloud_download
                : Icons.cloud_download,
              size: 28.0,
              color: context.theme.colorScheme.properOnSurface
            ),
            const SizedBox(height: 5),
            Text(
              attachment.mimeType ?? "Unknown File Type",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (attachment.mimeType?.startsWith("image") ?? false) {
      child = ImageDisplay(attachment: attachment, image: attachmentFile.bytes!);
      addPadding = false;
    } else if ((attachment.mimeType?.startsWith("video") ?? false) && !kIsDesktop && !kIsWeb) {
      if (videoPreview != null) {
        child = ImageDisplay(attachment: attachment, image: videoPreview!, duration: duration);
        addPadding = false;
      } else {
        child = const Text(
          "Loading video preview...",
          textAlign: TextAlign.center,
        );
      }
    } else if (attachmentFile.bytes != null) {
      child = OtherFile(
        file: attachmentFile,
        attachment: attachment,
      );
    } else {
      child = const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: Container(
        alignment: Alignment.center,
        color: context.theme.colorScheme.properSurface,
        padding: addPadding ? const EdgeInsets.all(10) : null,
        child: child,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ImageDisplay extends StatelessWidget {
  const ImageDisplay({
    Key? key,
    required this.attachment,
    required this.image,
    this.duration,
  }) : super(key: key);

  final Attachment attachment;
  final Uint8List image;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      openBuilder: (_, closeContainer) {
        return FullscreenMediaHolder(
          attachment: attachment,
          showInteractions: true,
        );
      },
      closedBuilder: (_, openContainer) {
        return InkWell(
          onTap: () {
            openContainer();
          },
          child: SizedBox(
            width: ns.width(context) / max(2, ns.width(context) ~/ 200),
            height: ns.width(context) / max(2, ns.width(context) ~/ 200),
            child: Stack(
              children: [
                Image.memory(
                  image,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: ns.width(context) ~/ max(2, ns.width(context) ~/ 200) * 2,
                  width: ns.width(context) / max(2, ns.width(context) ~/ 200),
                  height: ns.width(context) / max(2, ns.width(context) ~/ 200),
                ),
                if ((attachment.mimeType?.contains("video") ?? false) && duration != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Text(duration.toString().split('.').first
                        .padLeft(8, "0").padLeft(9, "a")
                        .replaceFirst("a00:", "").replaceFirst("a", ""),
                      style: context.theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (!(attachment.message.target?.isFromMe ?? true)
                    && attachment.message.target?.handle != null
                    && ss.settings.skin.value == Skins.iOS)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ContactAvatarWidget(handle: attachment.message.target?.handle),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
