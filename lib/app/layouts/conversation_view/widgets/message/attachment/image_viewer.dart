import 'dart:math';
import 'dart:io';

import 'package:bluebubbles/app/components/image_blur_canvas.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/live_photo_mixin.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ImageViewer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;
  final bool isFromMe;
  final bool isInReply;

  const ImageViewer({
    super.key,
    required this.file,
    required this.attachment,
    required this.isFromMe,
    this.controller,
    this.isInReply = false,
  });

  final ConversationViewController? controller;

  @override
  State<StatefulWidget> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with AutomaticKeepAliveClientMixin, LivePhotoMixin, ThemeHelpers {
  Attachment get attachment => widget.attachment;
  PlatformFile get file => widget.file;
  ConversationViewController? get controller => widget.controller;

  // Implement required getter for LivePhotoMixin
  @override
  Attachment get livePhotoAttachment => attachment;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Handle demo attachments
    if (attachment.guid!.contains("demo")) {
      return Image.asset(attachment.transferName!, fit: BoxFit.cover);
    }

    // In reply context use a compact blur canvas instead of the full viewer.
    // Size is dynamic: scale the image down to fit within maxReplySize × maxReplySize
    // (never scaling up). The blur canvas only activates when the scaled image is
    // genuinely smaller than the minimum dimension — otherwise just show the image
    // at its natural scaled size to avoid the blurred background appearing wider than
    // the actual image content.
    if (widget.isInReply) {
      final String? imagePath = (!kIsWeb && file.path != null) ? file.path : null;
      final imageBytes = file.bytes;
      if (imagePath != null || imageBytes != null) {
        const double maxReplySize = 100;
        // Minimum size below which blur kicks in to fill the container.
        // Kept small so normal portrait/landscape photos are shown without blur;
        // only truly extreme aspect ratios (e.g. panoramas, tall screenshots) get it.
        const double minReplyDimension = 48.0;

        final double? naturalW = attachment.displayWidth?.toDouble();
        final double? naturalH = attachment.displayHeight?.toDouble();

        double containerW, containerH;
        bool needsBlur;
        if (naturalW != null && naturalH != null && naturalW > 0 && naturalH > 0) {
          // Scale down to fit within the max box; never scale up.
          final scale = min(1.0, min(maxReplySize / naturalW, maxReplySize / naturalH));
          final scaledW = naturalW * scale;
          final scaledH = naturalH * scale;

          // If the image fits within reasonable bounds, use its natural scaled size
          // (no empty space, no blur). Only expand + blur when a dimension is too small.
          needsBlur = scaledW < minReplyDimension || scaledH < minReplyDimension;
          containerW = needsBlur ? max(minReplyDimension, scaledW) : scaledW;
          containerH = needsBlur ? max(minReplyDimension, scaledH) : scaledH;
        } else {
          // Unknown dimensions — square default with blur.
          needsBlur = true;
          containerW = maxReplySize;
          containerH = maxReplySize;
        }

        Widget imageContent;
        if (needsBlur) {
          imageContent = ImageBlurCanvas(filePath: imagePath, bytes: imageBytes);
        } else if (imagePath != null) {
          imageContent = Image.file(File(imagePath), fit: BoxFit.contain);
        } else {
          imageContent = Image.memory(imageBytes!, fit: BoxFit.contain);
        }

        return SizedBox(
          width: containerW,
          height: containerH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageContent,
          ),
        );
      }
    }

    // Build the appropriate image widget based on platform and file availability
    Widget imageWidget;
    if (kIsWeb || file.path == null) {
      // Web or no path - use memory image
      if (file.bytes == null) {
        imageWidget = SizedBox(
          width: min((attachment.displayWidth?.toDouble() ?? NavigationSvc.width(context) * 0.5),
              NavigationSvc.width(context) * 0.5),
          height: min(
              (attachment.displayHeight?.toDouble() ?? NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
              NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
        );
      } else {
        final displayWidth = min((attachment.displayWidth?.toDouble() ?? NavigationSvc.width(context) * 0.5),
            NavigationSvc.width(context) * 0.5);
        final displayHeight = min(
            (attachment.displayHeight?.toDouble() ?? NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
            NavigationSvc.width(context) * 0.5 / attachment.aspectRatio);
        final qualityFactor = SettingsSvc.settings.previewImageQuality.value;
        final calculatedWidth = (displayWidth * Get.pixelRatio * qualityFactor).round().abs().nonZero;
        final calculatedHeight = (displayHeight * Get.pixelRatio * qualityFactor).round().abs().nonZero;
        imageWidget = Image.memory(file.bytes!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            cacheWidth: calculatedWidth,
            cacheHeight: calculatedHeight,
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              if (frame == null) {
                // Show placeholder while loading
                return Container(
                  width: displayWidth,
                  height: displayHeight,
                  color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.outline),
                    ),
                  ),
                );
              }
              return child;
            },
            errorBuilder: (context, object, stacktrace) =>
                _buildImageError(context, displayWidth, displayHeight, object, stacktrace));
      }
    } else {
      // Calculate the proper height/width for the attachment to use only for the
      // containers and placeholders, not the actual image. The Image widget should respect
      // the EXIF data and display the image properly.
      final displayWidth = min((attachment.displayWidth?.toDouble() ?? NavigationSvc.width(context) * 0.5),
          NavigationSvc.width(context) * 0.5);
      final displayHeight = min(
          (attachment.displayHeight?.toDouble() ?? NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
          NavigationSvc.width(context) * 0.5 / attachment.aspectRatio);
      // Use configured quality factor from settings (25% to 100%)
      final qualityFactor = SettingsSvc.settings.previewImageQuality.value;
      final calculatedWidth = (displayWidth * Get.pixelRatio * qualityFactor).round().abs().nonZero;
      final calculatedHeight = (displayHeight * Get.pixelRatio * qualityFactor).round().abs().nonZero;
      imageWidget = Image.file(
        File(file.path!),
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          if (frame == null) {
            // Show placeholder while loading
            return Container(
              width: displayWidth,
              height: displayHeight,
              color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.outline),
                ),
              ),
            );
          }
          return child;
        },
        errorBuilder: (context, object, stacktrace) => FutureBuilder<String?>(
          future: AttachmentsSvc.ensureImageCompatibility(attachment, actualPath: file.path),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                width: min((attachment.displayWidth?.toDouble() ?? NavigationSvc.width(context) * 0.5),
                    NavigationSvc.width(context) * 0.5),
                height: min(
                    (attachment.displayHeight?.toDouble() ??
                        NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
                    NavigationSvc.width(context) * 0.5 / attachment.aspectRatio),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data != null && snapshot.data != file.path) {
              // Conversion successful, display converted image
              return Image.file(
                File(snapshot.data!),
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                cacheWidth: calculatedWidth,
                cacheHeight: calculatedHeight,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  if (frame == null) {
                    // Show placeholder while loading converted image
                    return Container(
                      width: displayWidth,
                      height: displayHeight,
                      color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.outline),
                        ),
                      ),
                    );
                  }
                  return child;
                },
              );
            }

            // Conversion failed or not needed
            return _buildImageError(context, displayWidth, displayHeight, object, stacktrace);
          },
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 40,
          minWidth: 100,
        ),
        child: Stack(
          alignment: !widget.isFromMe ? Alignment.topRight : Alignment.topLeft,
          children: [
            imageWidget,
            // Live photo video overlay
            if (attachment.hasLivePhoto) buildLivePhotoOverlay(),
            // Live photo button indicator
            if (attachment.hasLivePhoto)
              Obx(() => !isPlayingLivePhoto.value
                  ? Positioned(
                      top: 8,
                      right: widget.isFromMe ? null : 8,
                      left: widget.isFromMe ? 8 : null,
                      child: GestureDetector(
                        onTap: () {
                          if (!isDownloadingLivePhoto.value) {
                            handleLivePhotoTap();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDownloadingLivePhoto.value)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.album_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 3),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  /// Themed placeholder shown in place of an image that failed to decode/render.
  /// Sized to match the placeholder used while the image is loading so it doesn't
  /// collapse to a sliver and hug the top of the top-aligned [Stack] in [build].
  Widget _buildImageError(BuildContext context, double width, double height, Object error, StackTrace? stacktrace) {
    return Container(
      width: max(width, 120),
      height: max(height, 100),
      alignment: Alignment.center,
      color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iOS ? CupertinoIcons.photo : Icons.broken_image_outlined,
              size: 30,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              "Photo Unavailable",
              style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _showImageErrorDetails(context, error, stacktrace),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Text(
                  "View Details",
                  style: context.theme.textTheme.bodySmall!.copyWith(
                    color: context.theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageErrorDetails(BuildContext context, Object error, StackTrace? stacktrace) {
    showBBDialog(
      context: context,
      title: "Image Error Details",
      content: SizedBox(
        width: NavigationSvc.width(context) * 3 / 5,
        height: context.height * 1 / 4,
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
              color: context.theme.colorScheme.surface, borderRadius: const BorderRadius.all(Radius.circular(10))),
          child: SingleChildScrollView(
            child: SelectableText(
              "$error\n\n$stacktrace",
              style: context.theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
      actions: [
        BBDialogAction(
          text: "Close",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
