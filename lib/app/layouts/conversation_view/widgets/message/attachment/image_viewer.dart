import 'dart:math';
import 'dart:io';

import 'package:bluebubbles/app/components/image_blur_canvas.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/live_photo_mixin.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/media_unavailable_placeholder.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gif_view/gif_view.dart';

class ImageViewer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;
  final bool isFromMe;
  final bool isInReply;

  /// Cover-expand into a parent-fixed frame (gallery cards). Layout only.
  final bool fill;

  const ImageViewer({
    super.key,
    required this.file,
    required this.attachment,
    required this.isFromMe,
    this.controller,
    this.isInReply = false,
    this.fill = false,
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

  // Reduce-motion GIF playback (desktop): controller pauses the GIF until hovered.
  GifController? _gifController;
  Future<Uint8List?>? _gifBytesFuture;
  final RxBool _gifHovering = false.obs;

  // Rotation-corrected, downsampled preview used for fast inline display.
  Future<String?>? _previewPathFuture;

  @override
  void initState() {
    super.initState();
    // Migration path for attachments processed before orientation tracking
    // was added: opportunistically reprocess once, only for attachments
    // actually scrolled into view (never a bulk startup scan).
    if (!kIsWeb && file.path != null && attachment.metadata?['_orientation_processed'] != true) {
      AttachmentsSvc.loadImageProperties(attachment, actualPath: file.path).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  bool get _isGif => attachment.mimeType?.contains("gif") ?? attachment.path.endsWith(".gif");

  BoxFit get _fit => widget.fill ? BoxFit.cover : BoxFit.contain;

  Widget _wrapForFill(Widget child) => widget.fill ? SizedBox.expand(child: child) : child;

  // Read bytes off the UI thread — a synchronous read of a multi-MB GIF during
  // build freezes the app, especially with several GIFs on screen at once.
  Future<Uint8List?> _loadGifBytes() async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) return f.readAsBytes();
    }
    return null;
  }

  @override
  void dispose() {
    _gifController?.dispose();
    super.dispose();
  }

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
    // Skip when fill — gallery cards are never in-reply and must expand into the frame.
    if (!widget.fill && widget.isInReply) {
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
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: imageContent),
        );
      }
    }

    // Reduce Motion (desktop): keep GIFs paused on their first frame and only
    // animate while hovered. GifView decodes every frame up front, so the native
    // (streaming) Image path stays the default — routing all GIFs through GifView
    // stalls the UI on large/many GIFs. Only opt in when Reduce Motion is on.
    if (_isGif && kIsDesktop) {
      return Obx(() {
        if (!SettingsSvc.settings.reduceMotion.value) return _buildStandardImage(context);
        return FutureBuilder<Uint8List?>(
          future: _gifBytesFuture ??= _loadGifBytes(),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            // Until bytes are loaded (or if unavailable), show the native path.
            if (bytes == null) return _buildStandardImage(context);
            _gifController ??= GifController();
            // Same explicit sizing as the native path, so swapping from
            // _buildStandardImage to GifView once the bytes land doesn't
            // resize the bubble. Fill mode expands into the parent frame instead.
            final size = _displaySize(context);
            final gifStack = MouseRegion(
              onEnter: (_) {
                _gifHovering.value = true;
                _gifController?.play();
              },
              onExit: (_) {
                _gifHovering.value = false;
                _gifController?.pause();
              },
              child: Stack(
                fit: widget.fill ? StackFit.expand : StackFit.loose,
                alignment: !widget.isFromMe ? Alignment.topRight : Alignment.topLeft,
                children: [
                  GifView.memory(
                    bytes,
                    controller: _gifController,
                    autoPlay: false,
                    width: widget.fill ? null : size.width,
                    height: widget.fill ? null : size.height,
                    fit: _fit,
                  ),
                  // GIF badge, mirroring the LIVE badge — hidden while playing (hovered).
                  Obx(() => _gifHovering.value ? const SizedBox.shrink() : _buildGifBadge()),
                ],
              ),
            );
            if (widget.fill) return _wrapForFill(gifStack);
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
              child: gifStack,
            );
          },
        );
      });
    }

    return _buildStandardImage(context);
  }

  /// "GIF" badge shown on a paused reduce-motion GIF, styled like the LIVE badge.
  Widget _buildGifBadge() {
    return Positioned(
      top: 8,
      right: widget.isFromMe ? null : 8,
      left: widget.isFromMe ? 8 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gif_box_outlined, size: 12, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'GIF',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// The logical-point box this image occupies. Every `Image` in this widget is
  /// given this exact size, and [AttachmentHolder] reserves the same box for the
  /// download/not-loaded placeholders — see [Attachment.displayBox].
  ({double width, double height}) _displaySize(BuildContext context) =>
      attachment.displayBox(NavigationSvc.width(context) * 0.5, context.height * 0.6);

  Widget _buildStandardImage(BuildContext context) {
    // Build the appropriate image widget based on platform and file availability
    Widget imageWidget;
    if (kIsWeb || file.path == null) {
      // Web or no path - use memory image
      final size = _displaySize(context);
      final displayWidth = size.width;
      final displayHeight = size.height;
      if (file.bytes == null) {
        imageWidget = widget.fill
            ? const ColoredBox(color: Colors.transparent)
            : SizedBox(width: displayWidth, height: displayHeight);
      } else {
        final qualityFactor = SettingsSvc.settings.previewImageQuality.value;
        final calculatedWidth = (displayWidth * Get.pixelRatio * qualityFactor).round().abs().nonZero;
        imageWidget = Image.memory(
          file.bytes!,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          width: widget.fill ? null : displayWidth,
          // height omitted for non-fill — see comment below. Fill expands via SizedBox.
          // Display space, width only. The decoder already applies EXIF
          // orientation (dimensions it reports, and cacheWidth/cacheHeight it
          // accepts, are post-rotation), so nothing here may re-apply it.
          // Passing height as well would make ResizeImagePolicy.exact behave
          // like BoxFit.fill and stretch the bitmap; width alone preserves the
          // aspect ratio.
          cacheWidth: calculatedWidth,
          fit: _fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            if (frame == null) {
              // Show placeholder while loading
              return Container(
                width: widget.fill ? null : displayWidth,
                height: widget.fill ? null : displayHeight,
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
              _buildImageError(context, displayWidth, displayHeight, object, stacktrace),
        );
      }
    } else {
      // The box this image occupies, reserved up front so nothing moves when
      // the decoded frame lands.
      final size = _displaySize(context);
      final displayWidth = size.width;
      final displayHeight = size.height;
      // Use configured quality factor from settings (25% to 100%)
      // Display space, width only — see the note on the Image.memory path above.
      final qualityFactor = SettingsSvc.settings.previewImageQuality.value;
      final calculatedWidth = (displayWidth * Get.pixelRatio * qualityFactor).round().abs().nonZero;

      Widget placeholder() => Container(
        width: widget.fill ? null : displayWidth,
        height: widget.fill ? null : displayHeight,
        color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.outline),
          ),
        ),
      );

      // Fallback: render the original file directly, used when preview
      // generation fails.
      Widget buildOriginalFallback() {
        return Image.file(
          File(file.path!),
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          fit: _fit,
          width: widget.fill ? null : displayWidth,
          // Commented out because it causes clipping issues
          // when an image exists in the same message as text.
          // height: displayHeight,
          cacheWidth: calculatedWidth,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            if (frame == null) return placeholder();
            return child;
          },
          errorBuilder: (context, object, stacktrace) => FutureBuilder<String?>(
            future: AttachmentsSvc.ensureImageCompatibility(attachment, actualPath: file.path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return widget.fill
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: displayWidth,
                        height: displayHeight,
                        child: const Center(child: CircularProgressIndicator()),
                      );
              }

              if (snapshot.hasData && snapshot.data != null && snapshot.data != file.path) {
                // Conversion successful, display converted image.
                return Image.file(
                  File(snapshot.data!),
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  width: widget.fill ? null : displayWidth,
                  // Commented out because it causes clipping issues
                  // when an image exists in the same message as text.
                  // height: displayHeight,
                  cacheWidth: calculatedWidth,
                  fit: _fit,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    if (frame == null) return placeholder();
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

      Widget buildPreview(String previewPath) {
        return Image.file(
          File(previewPath),
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          width: widget.fill ? null : displayWidth,
          // Commented out because it causes clipping issues
          // when an image exists in the same message as text.
          // height: displayHeight,
          cacheWidth: calculatedWidth,
          fit: _fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            if (frame == null) return placeholder();
            return child;
          },
          errorBuilder: (context, object, stacktrace) => buildOriginalFallback(),
        );
      }

      final knownPreview = AttachmentsSvc.knownPreviewPath(attachment);
      if (knownPreview != null) {
        imageWidget = buildPreview(knownPreview);
      } else {
        _previewPathFuture ??= AttachmentsSvc.getOrCreateImagePreview(attachment, actualPath: file.path);
        imageWidget = FutureBuilder<String?>(
          future: _previewPathFuture,
          builder: (context, snapshot) {
            // While the preview is still generating, hold the placeholder
            // rather than decoding the full-resolution original — that decode
            // is the expensive work the preview exists to avoid, and it would
            // be thrown away moments later when the preview lands.
            if (snapshot.connectionState != ConnectionState.done) return placeholder();
            final previewPath = snapshot.data;
            if (previewPath != null) return buildPreview(previewPath);
            // Preview generation genuinely failed — fall back to the original.
            return buildOriginalFallback();
          },
        );
      }
    }

    // No AnimatedSize here: every Image above is given an explicit size, so the
    // box never changes once laid out. Animating it only ever amplified a
    // residual shift into a visible 150ms slide. Fill mode expands into a
    // parent-fixed gallery frame instead.
    final stack = Stack(
      fit: widget.fill ? StackFit.expand : StackFit.loose,
      alignment: !widget.isFromMe ? Alignment.topRight : Alignment.topLeft,
      children: [
        imageWidget,
        // Live photo video overlay
        if (attachment.hasLivePhoto) buildLivePhotoOverlay(),
        // Live photo button indicator
        if (attachment.hasLivePhoto)
          Obx(
            () => !isPlayingLivePhoto.value
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
                              const Icon(Icons.album_outlined, size: 12, color: Colors.white),
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
                : const SizedBox.shrink(),
          ),
      ],
    );

    if (widget.fill) return _wrapForFill(stack);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40, minWidth: 100),
      child: stack,
    );
  }

  Widget _buildImageError(BuildContext context, double width, double height, Object error, StackTrace? stacktrace) {
    return MediaUnavailablePlaceholder(
      width: width,
      height: height,
      iosIcon: CupertinoIcons.photo,
      materialIcon: Icons.broken_image_outlined,
      message: "Photo Unavailable",
      onViewDetails: () => _showImageErrorDetails(context, error, stacktrace),
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
            color: context.theme.colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: SingleChildScrollView(
            child: SelectableText("$error\n\n$stacktrace", style: context.theme.textTheme.bodyLarge),
          ),
        ),
      ),
      actions: [BBDialogAction(text: "Close", onPressed: () => Navigator.of(context, rootNavigator: true).pop())],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
