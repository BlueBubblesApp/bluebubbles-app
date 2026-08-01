import 'dart:typed_data';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

/// Material / Samsung skin for the link preview card, in M3 Expressive.
///
/// Differs from the iOS skin in more than tokens:
///
///  * the image is a clean `AspectRatio` crop rather than a letterbox over a
///    blurred copy of itself — the blur-fill is an iMessage idiom and reads as
///    foreign here;
///  * `M3EShapes` corner radii instead of a hardcoded 20px;
///  * the tap-to-load affordance is an `M3ETonalButton`, the M3E idiom for an
///    optional action inside a card, rather than an inline text button;
///  * the site line sits above the title, which is how M3E cards lead with
///    provenance.
class ExpressiveUrlPreview extends StatelessWidget {
  const ExpressiveUrlPreview({super.key, required this.controller});

  final UrlPreviewController controller;

  /// Preview images are letterboxed into this ratio rather than being allowed
  /// to drive the card's height, so a very tall or very wide og:image cannot
  /// distort the bubble.
  static const double _imageAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final message = MessageStateScope.maybeMessageOf(context);
      final inReply = ReplyScope.maybeOf(context) != null;

      final data = controller.effectiveData;
      final webImageUrl = controller.webImageUrl;
      final previewImagePath = controller.previewImagePath.value;
      final siteText = controller.siteText;
      final resolvedContent = controller.resolvedContent;
      final contentFile = controller.contentFile;

      final header = _buildHeader(
        context,
        inReply: inReply,
        previewImagePath: previewImagePath,
        webImageUrl: webImageUrl,
        appleBytes: controller.showsAppleImage ? resolvedContent?.bytes : null,
        appleFile: controller.showsAppleImage && resolvedContent?.bytes == null ? contentFile : null,
      );

      return InkWell(
        onTap: controller.file != null && (data.originalUrl ?? data.url) != null
            ? () async {
                await launchUrl(Uri.parse(data.originalUrl ?? data.url!), mode: LaunchMode.externalApplication);
              }
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) header,
            Padding(
              padding: inReply
                  ? const EdgeInsets.all(M3EShapes.md)
                  : const EdgeInsets.fromLTRB(M3EShapes.lg, M3EShapes.md, M3EShapes.lg, M3EShapes.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Provenance first: the host is the one line a user
                        // relies on to see where a link actually goes, and it
                        // is derived from the URL, never from og:site_name.
                        if (!isNullOrEmpty(siteText))
                          Text(
                            siteText!,
                            style: context.theme.textTheme.labelSmall?.copyWith(
                              color: context.theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (!isNullOrEmpty(siteText)) const SizedBox(height: M3EShapes.xs),
                        Text(
                          controller.titleFor(message?.text),
                          style: context.theme.textTheme.titleSmall?.copyWith(
                            color: context.theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (controller.hasSummary && !inReply) const SizedBox(height: M3EShapes.xs),
                        if (controller.hasSummary && !inReply)
                          Text(
                            controller.summary ?? "",
                            style: context.theme.textTheme.bodySmall?.copyWith(
                              color: context.theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (controller.needsManualLoad.value && !inReply) const SizedBox(height: M3EShapes.md),
                        if (controller.needsManualLoad.value && !inReply) _buildLoadPreviewButton(context),
                      ],
                    ),
                  ),
                  if (controller.hasIcon) const SizedBox(width: M3EShapes.md),
                  if (controller.hasIcon) _buildIcon(context, data.iconMetadata?.url),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// The card's leading image, or null when there is nothing to show.
  Widget? _buildHeader(
    BuildContext context, {
    required bool inReply,
    required String? previewImagePath,
    required String? webImageUrl,
    required Uint8List? appleBytes,
    required File? appleFile,
  }) {
    if (inReply) return null;

    final Widget image;
    if (previewImagePath != null) {
      image = Image.file(
        File(previewImagePath),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _imageFallback(context),
      );
    } else if (webImageUrl != null) {
      image = Image.network(
        webImageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _imageFallback(context),
      );
    } else if (appleBytes != null) {
      image = Image.memory(
        appleBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _imageFallback(context),
      );
    } else if (appleFile != null) {
      image = Image.file(
        appleFile,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _imageFallback(context),
      );
    } else {
      return null;
    }

    final container = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(M3EShapes.lg)),
      child: AspectRatio(
        aspectRatio: _imageAspectRatio,
        child: SizedBox.expand(child: image),
      ),
    );

    // Only a freshly downloaded image grows in; a disk load appears at once.
    if (previewImagePath == null || controller.previewImageFromDisk.value) return container;

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: controller.imageAnimation, curve: Curves.easeOutCubic),
      axisAlignment: -1.0,
      child: container,
    );
  }

  Widget _imageFallback(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: context.theme.colorScheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, String? networkUrl) {
    final iconImagePath = controller.iconImagePath.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.sm)),
        child: iconImagePath != null
            ? Image.file(File(iconImagePath), gaplessPlayback: true, filterQuality: FilterQuality.medium)
            : Image.network(networkUrl!, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }

  /// Tap-to-load affordance, shown when the policy declines to fetch a preview
  /// on its own.
  ///
  /// An `M3ETonalButton` rather than a plain text button — this is an optional
  /// action attached to a card, which is exactly what the tonal button is for.
  Widget _buildLoadPreviewButton(BuildContext context) {
    final running = controller.manualLoadRunning.value;

    return M3ETonalButton(
      icon: running ? Icons.hourglass_empty : Icons.download_outlined,
      label: running ? "Loading Preview\u{2026}" : "Load Preview",
      onPressed: running ? () {} : controller.loadManually,
      borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.md)),
    );
  }
}
