import 'dart:typed_data';

import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
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
///
/// Renders one of three shapes depending on how much the page gave us — see
/// [UrlPreviewLayout]. The card's width does not change between them, so a link
/// that resolves an image grows downward into the hero shape rather than
/// resizing in place.
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

      final Widget body;
      switch (controller.layout) {
        case UrlPreviewLayout.hero:
          body = _buildHero(context, message: message, inReply: inReply);
        case UrlPreviewLayout.compact:
          body = _buildCompact(context, message: message, inReply: inReply);
        case UrlPreviewLayout.bare:
          body = _buildBare(context, inReply: inReply);
      }

      return InkWell(
        onTap: controller.file != null && (data.originalUrl ?? data.url) != null
            ? () async {
                await launchUrl(Uri.parse(data.originalUrl ?? data.url!), mode: LaunchMode.externalApplication);
              }
            : null,
        child: body,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Shapes
  // ---------------------------------------------------------------------------

  /// The full card: cropped image on top, then site line and title.
  Widget _buildHero(BuildContext context, {required Message? message, required bool inReply}) {
    final resolvedContent = controller.resolvedContent;

    final header = _buildHeader(
      context,
      previewImagePath: controller.previewImagePath.value,
      webImageUrl: controller.webImageUrl,
      appleBytes: controller.showsAppleImage ? resolvedContent?.bytes : null,
      appleFile: controller.showsAppleImage && resolvedContent?.bytes == null ? controller.contentFile : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) header,
        Padding(
          padding: inReply
              ? const EdgeInsets.all(M3EShapes.md)
              : const EdgeInsets.fromLTRB(M3EShapes.lg, M3EShapes.md, M3EShapes.lg, M3EShapes.lg),
          // Two nested rows so the two trailing/leading elements can align
          // differently: the spinner centres against the whole text block,
          // while the favicon stays level with the first line of it.
          child: Row(
            // Full width with the spinner pushed to the trailing edge, rather
            // than tucked against the end of the text.
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leading, matching the compact shape: the favicon is the
                    // source badge for the text it sits against, so it stays on
                    // the same side no matter which shape the card is in.
                    if (controller.hasIcon) _buildIcon(context),
                    if (controller.hasIcon) const SizedBox(width: M3EShapes.md),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Provenance first: the host is the one line a user
                          // relies on to see where a link actually goes, and it
                          // is derived from the URL, never from og:site_name.
                          if (controller.showsSiteLine(message?.text)) _buildSiteLine(context),
                          if (controller.showsSiteLine(message?.text)) const SizedBox(height: M3EShapes.xs),
                          _buildTitle(context, message),
                          ..._buildManualLoadAffordance(context, inReply: inReply),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.refreshRunning.value) _buildRefreshIndicator(context),
            ],
          ),
        ),
      ],
    );
  }

  /// No image, but the page described itself: favicon, site line and title in a
  /// single dense row — [_buildHero] without the image header, and tighter
  /// padding with a smaller favicon to match.
  Widget _buildCompact(BuildContext context, {required Message? message, required bool inReply}) {
    return Padding(
      padding: inReply
          ? const EdgeInsets.all(M3EShapes.md)
          : const EdgeInsets.symmetric(horizontal: M3EShapes.lg, vertical: M3EShapes.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading rather than trailing here: with no image above it,
                    // the favicon is the only mark on the card and reads as the
                    // source badge for the lines it sits against.
                    if (controller.hasIcon) _buildIcon(context, size: 32),
                    if (controller.hasIcon) const SizedBox(width: M3EShapes.md),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.showsSiteLine(message?.text)) _buildSiteLine(context),
                          if (controller.showsSiteLine(message?.text)) const SizedBox(height: M3EShapes.xs),
                          _buildTitle(context, message),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.refreshRunning.value) _buildRefreshIndicator(context),
            ],
          ),
          ..._buildManualLoadAffordance(context, inReply: inReply),
        ],
      ),
    );
  }

  /// Nothing resolved: one line saying where the link goes, plus the
  /// tap-to-load affordance when the policy is what is holding the preview back.
  Widget _buildBare(BuildContext context, {required bool inReply}) {
    final link = controller.linkText ?? controller.siteText ?? "";

    return Padding(
      padding: inReply
          ? const EdgeInsets.all(M3EShapes.md)
          : const EdgeInsets.symmetric(horizontal: M3EShapes.lg, vertical: M3EShapes.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 16, color: context.theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: M3EShapes.sm),
                    Flexible(
                      child: Text(
                        link,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.refreshRunning.value) _buildRefreshIndicator(context),
            ],
          ),
          ..._buildManualLoadAffordance(context, inReply: inReply),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  Widget _buildSiteLine(BuildContext context) {
    return Text(
      controller.siteText!,
      style: context.theme.textTheme.labelSmall?.copyWith(
        color: context.theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Trailing spinner shown while "Refresh Preview" is re-fetching.
  ///
  /// Trailing because the favicon leads; it sits in the space the favicon used
  /// to occupy, so nothing else on the card shifts while it is up. Vertically
  /// centred against the text block by the row that holds it.
  Widget _buildRefreshIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: M3EShapes.md),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, Message? message) {
    return Text(
      controller.titleFor(message?.text),
      style: context.theme.textTheme.titleSmall?.copyWith(
        color: context.theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The tap-to-load affordance and the gap above it, or nothing.
  ///
  /// A generous gap and a full-width target: it only reads as a card action
  /// once it is not crowded against the text above it.
  List<Widget> _buildManualLoadAffordance(BuildContext context, {required bool inReply}) {
    if (!controller.needsManualLoad.value || inReply) return const [];
    return [
      const SizedBox(height: M3EShapes.lg),
      SizedBox(width: double.infinity, child: _buildLoadPreviewButton(context)),
    ];
  }

  /// The card's leading image, or null when there is nothing to show.
  Widget? _buildHeader(
    BuildContext context, {
    required String? previewImagePath,
    required String? webImageUrl,
    required Uint8List? appleBytes,
    required File? appleFile,
  }) {
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

  /// The favicon.
  ///
  /// Renders from the disk cache, and only falls back to the network on web,
  /// where there is no disk cache — see [UrlPreviewController.webIconUrl] for
  /// why there is no such fallback anywhere else. A load failure collapses the
  /// icon rather than surfacing as an uncaught rendering error.
  Widget _buildIcon(BuildContext context, {double size = 40}) {
    final iconImagePath = controller.iconImagePath.value;
    final webIconUrl = controller.webIconUrl;

    final icon = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size, maxHeight: size),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.sm)),
        child: iconImagePath != null
            ? Image.file(
                File(iconImagePath),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : Image.network(
                webIconUrl!,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
      ),
    );

    // Pops in only on a fresh download — the controller leaves the animation at
    // its end value for a disk load, so a scroll past a cached card is still
    // instant. Fade plus scale rather than a size transition: the icon's box is
    // already in the layout by the time this runs, and animating its size would
    // shove the title sideways.
    return FadeTransition(
      opacity: CurvedAnimation(parent: controller.iconAnimation, curve: M3EMotion.effectsFast.curve),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: controller.iconAnimation, curve: M3EMotion.spatialFast.curve),
        child: icon,
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
