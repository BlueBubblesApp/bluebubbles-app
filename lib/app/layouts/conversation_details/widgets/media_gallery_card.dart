import 'dart:async';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:bluebubbles/app/components/image_blur_canvas.dart';
import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/conversation_fullscreen_holder.dart';
import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:bluebubbles/models/models.dart' show AttachmentUploadProgress;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class MediaGalleryCard extends StatefulWidget {
  const MediaGalleryCard({
    super.key,
    required this.attachment,
    this.showSenderAvatar = true,
    this.chat,
    this.galleryAttachments,
  });
  final Attachment attachment;
  final bool showSenderAvatar;
  final Chat? chat;

  /// Limits fullscreen paging to this list instead of all chat images.
  final List<Attachment>? galleryAttachments;

  @override
  State<MediaGalleryCard> createState() => _MediaGalleryCardState();
}

class _MediaGalleryCardState extends State<MediaGalleryCard> with AutomaticKeepAliveClientMixin, ThemeHelpers {
  // Path to the generated thumbnail file on disk -- never held as decoded bytes in memory.
  String? videoPreviewPath;
  bool videoPreviewFailed = false;
  Duration? duration;
  bool _pressed = false;
  late dynamic content;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Attachment get attachment => widget.attachment;

  @override
  void initState() {
    super.initState();
    updateContent();
  }

  @override
  void didUpdateWidget(MediaGalleryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the attachment GUID changed (e.g., temp -> real GUID after send), update content
    if (oldWidget.attachment.guid != widget.attachment.guid) {
      updateContent();
    }
  }

  void updateContent() {
    // Use the attachment service to get the content properly
    content = AttachmentsSvc.getContent(attachment, autoDownload: false, onComplete: onComplete);

    // If getContent returned a controller, listen to it
    if (content is AttachmentDownloadController) {
      (content as AttachmentDownloadController).completeFuncs.add(onComplete);
      (content as AttachmentDownloadController).errorFuncs.add(() {
        if (mounted) {
          setState(() {});
        }
      });
    }

    // If content is a PlatformFile with a path, generate video preview if needed
    if (content is PlatformFile && (content as PlatformFile).path != null) {
      if (attachment.mimeType?.contains("video") ?? false) {
        getVideoPreview(content as PlatformFile);
      }
    }
  }

  void onComplete(PlatformFile file) {
    if (mounted) {
      setState(() {
        content = file;
      });
      if (attachment.mimeType?.contains("video") ?? false) {
        getVideoPreview(file);
      }
    }
  }

  void downloadAttachment() {
    setState(() {
      content = AttachmentDownloader.startDownload(attachment, onComplete: onComplete);
      if (content is AttachmentDownloadController) {
        (content as AttachmentDownloadController).errorFuncs.add(() {
          if (mounted) {
            setState(() {});
          }
          showSnackbar("Error", "Failed to download attachment!");
        });
      }
    });
  }

  Future<void> getVideoPreview(PlatformFile file) async {
    if (videoPreviewPath != null || videoPreviewFailed || file.path == null) return;

    VideoPlayerController? tempController;
    try {
      videoPreviewPath = await AttachmentsSvc.getVideoThumbnail(file.path!);
      if (!mounted) return;
      dynamic _file = File(file.path!);
      tempController = VideoPlayerController.file(_file);
      await tempController.initialize();
      if (!mounted) return;
      duration = tempController.value.duration;
    } catch (ex) {
      videoPreviewFailed = true;
    } finally {
      await tempController?.dispose();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      final bool hideAttachments =
          SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideAttachments.value;

      late Widget child;
      bool addPadding = true;

      if (hideAttachments) {
        child = Text(
          attachment.mimeType ?? "Unknown",
          textAlign: TextAlign.center,
        );
      } else if (content is AttachmentWithProgress) {
        // Attachment being sent - show image with progress overlay
        final attachmentWithProgress = content as AttachmentWithProgress;
        final file = attachmentWithProgress.file;
        final progress = attachmentWithProgress.progress;

        addPadding = false;
        child = Stack(
          fit: StackFit.expand,
          children: [
            // Background image with lower opacity
            Opacity(
              opacity: 0.3,
              child: file.path != null
                  ? (attachment.mimeType?.startsWith("image") ?? false)
                      ? ImageDisplay(
                          attachment: attachment,
                          file: file,
                          chat: widget.chat,
                          galleryAttachments: widget.galleryAttachments,
                        )
                      : (attachment.mimeType?.startsWith("video") ?? false) && videoPreviewPath != null
                          ? ImageDisplay(
                              attachment: attachment,
                              imagePath: videoPreviewPath,
                              chat: widget.chat,
                              galleryAttachments: widget.galleryAttachments,
                            )
                          : const SizedBox.shrink()
                  : const SizedBox.shrink(),
            ),
            // Progress overlay
            Container(
              color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Center(
                child: Obx(() {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: CircleProgressBar(
                          foregroundColor: context.theme.colorScheme.primary,
                          backgroundColor: context.theme.colorScheme.outline,
                          value: progress.progress.value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        progress.progress.value < 1
                            ? "${(progress.progress.value * 100).toStringAsFixed(0)}%"
                            : "Waiting for iMessage...",
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: context.theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      } else if (content is AttachmentDownloadController) {
        child = SizedBox(
          height: 40,
          width: 40,
          child: Obx(() {
            final controller = content as AttachmentDownloadController;
            return controller.state.value == AttachmentDownloadState.processing
                ? (iOS ? const CupertinoActivityIndicator(radius: 14) : const CircularProgressIndicator())
                : CircleProgressBar(
                    foregroundColor: context.theme.colorScheme.primary,
                    backgroundColor: context.theme.colorScheme.outline,
                    value: controller.progress.value?.toDouble() ?? 0,
                  );
          }),
        );
      } else if (content is AttachmentUploadProgress) {
        // Fallback: Progress without file preview (shouldn't normally happen but handle it)
        final progress = content as AttachmentUploadProgress;
        child = Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                width: 40,
                child: CircleProgressBar(
                  foregroundColor: context.theme.colorScheme.primary,
                  backgroundColor: context.theme.colorScheme.outline,
                  value: progress.progress.value,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                progress.progress.value < 1
                    ? "${(progress.progress.value * 100).toStringAsFixed(0)}%"
                    : "Waiting for iMessage...",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          );
        });
      } else if (content is Attachment) {
        // Attachment not downloaded yet
        addPadding = false;
        final mimeType = attachment.mimeType ?? '';
        final friendlyType = mimeTypeToFriendlyName(mimeType);
        final totalBytes = attachment.totalBytes ?? 0;
        final friendlySize = totalBytes > 0 ? (totalBytes.toDouble()).getFriendlySize(decimals: 0) : null;

        Widget _badge(String label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            );

        child = InkWell(
          onTap: downloadAttachment,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Centered content
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    getAttachmentIcon(mimeType),
                    size: 52,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  if (friendlySize != null)
                    Text(
                      friendlySize,
                      style: context.theme.textTheme.bodySmall!.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SettingsSvc.settings.skin.value == Skins.iOS
                            ? CupertinoIcons.cloud_download
                            : Icons.cloud_download,
                        size: 13,
                        color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to download',
                        style: context.theme.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Mime-type badge — top-left
              Positioned(
                top: 8,
                left: 8,
                child: _badge(friendlyType),
              ),
            ],
          ),
        );
      } else if (content is PlatformFile) {
        final file = content as PlatformFile;
        if (attachment.mimeType?.startsWith("image") ?? false) {
          child = ImageDisplay(
            attachment: attachment,
            file: file,
            showSenderAvatar: widget.showSenderAvatar,
            chat: widget.chat,
            galleryAttachments: widget.galleryAttachments,
            onPressChanged: _setPressed,
          );
          addPadding = false;
        } else if ((attachment.mimeType?.startsWith("video") ?? false) && !kIsDesktop && !kIsWeb) {
          if (videoPreviewPath != null) {
            child = ImageDisplay(
              attachment: attachment,
              imagePath: videoPreviewPath,
              duration: duration,
              showSenderAvatar: widget.showSenderAvatar,
              chat: widget.chat,
              galleryAttachments: widget.galleryAttachments,
              onPressChanged: _setPressed,
            );
            addPadding = false;
          } else if (videoPreviewFailed) {
            child = Text(
              "Preview Unavailable",
              style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            );
          } else {
            child = const Text(
              "Loading video preview...",
              textAlign: TextAlign.center,
            );
          }
        } else {
          addPadding = false;
          child = OtherFile(
            file: file,
            attachment: attachment,
          );
        }
      } else {
        child = const SizedBox.shrink();
      }

      return AnimatedContainer(
        duration: M3EMotion.spatialFast.duration,
        curve: M3EMotion.spatialFast.curve,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_pressed ? M3EShapes.md : M3EShapes.lg),
          color: context.theme.colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        padding: addPadding ? const EdgeInsets.all(10) : null,
        child: child,
      );
    }); // end Obx
  }

  @override
  bool get wantKeepAlive => true;
}

class ImageDisplay extends StatefulWidget {
  const ImageDisplay({
    super.key,
    required this.attachment,
    this.file,
    this.imagePath,
    this.duration,
    this.showSenderAvatar = true,
    this.chat,
    this.galleryAttachments,
    this.onPressChanged,
  });

  final Attachment attachment;
  final PlatformFile? file;
  final String? imagePath;
  final Duration? duration;
  final bool showSenderAvatar;
  final Chat? chat;
  final List<Attachment>? galleryAttachments;
  final ValueChanged<bool>? onPressChanged;

  @override
  State<ImageDisplay> createState() => _ImageDisplayState();
}

class _ImageDisplayState extends State<ImageDisplay> {
  bool _hovered = false;

  Attachment get attachment => widget.attachment;
  PlatformFile? get file => widget.file;
  String? get imagePath => widget.imagePath;
  Duration? get duration => widget.duration;

  @override
  Widget build(BuildContext context) {
    final double cardSize = NavigationSvc.width(context) / max(2, NavigationSvc.width(context) ~/ 200);

    return OpenContainer(
      transitionDuration: Durations.medium4,
      closedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(M3EShapes.lg))),
      openBuilder: (_, closeContainer) {
        return ConversationFullscreenHolder(
          currentChat: widget.chat,
          attachment: attachment,
          showInteractions: true,
          galleryAttachments: widget.galleryAttachments,
        );
      },
      closedBuilder: (_, openContainer) {
        return MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: InkWell(
              onTap: () {
                openContainer();
              },
              onHighlightChanged: widget.onPressChanged,
              child: SizedBox(
                width: cardSize,
                height: cardSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred canvas: filled background + centered foreground.
                    ImageBlurCanvas(
                      filePath: file?.path ?? imagePath,
                      bytes: file?.bytes,
                    ),
                    if ((attachment.mimeType?.contains("video") ?? false) && duration != null)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Text(
                          duration
                              .toString()
                              .split('.')
                              .first
                              .padLeft(8, "0")
                              .padLeft(9, "a")
                              .replaceFirst("a00:", "")
                              .replaceFirst("a", ""),
                          style: context.theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (widget.showSenderAvatar &&
                        !(attachment.message.target?.isFromMe ?? true) &&
                        attachment.message.target?.handleRelation.hasValue == true)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: ContactAvatarWidget(handle: attachment.message.target?.handleRelation.target),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: _hovered ? context.theme.colorScheme.scrim.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ));
      },
    );
  }
}
