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
///    optional action inside a card, rather than an inline text button.
///
/// The text block is ordered the same way the iOS skin orders it, and the same
/// way Google Messages does: title first, then a source row of favicon +
/// domain beneath it. This skin used to lead with the site line and hang a
/// 40px favicon off the left of the entire block, which read as a list tile
/// rather than a link card. The favicon now sits inline with the domain at
/// [_sourceIconSize], scaled to that line's own text.
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

  /// Favicon edge in the source row.
  ///
  /// Matched to the rendered height of the `labelSmall` site line it sits
  /// against, so the two read as one line. A larger mark turns the row into a
  /// list tile and pushes the domain off its own baseline.
  static const double _sourceIconSize = 16;

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

  /// The full card: cropped image on top, then the text block.
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
        ?header,
        Padding(
          padding: inReply
              ? const EdgeInsets.all(M3ESpacing.md)
              : const EdgeInsets.fromLTRB(M3ESpacing.lg, M3ESpacing.md, M3ESpacing.lg, M3ESpacing.lg),
          child: _buildBody(context, message: message, inReply: inReply),
        ),
      ],
    );
  }

  /// No image, but the page gave us something: [_buildHero]'s text block
  /// without the image header, and tighter padding to match.
  Widget _buildCompact(BuildContext context, {required Message? message, required bool inReply}) {
    return Padding(
      padding: inReply
          ? const EdgeInsets.all(M3ESpacing.md)
          : const EdgeInsets.symmetric(horizontal: M3ESpacing.lg, vertical: M3ESpacing.md),
      child: _buildBody(context, message: message, inReply: inReply),
    );
  }

  /// The text block, plus the refresh spinner pinned to the trailing edge.
  ///
  /// Shared by [_buildHero] and [_buildCompact] — they differ only in whether
  /// an image sits above this and in how much padding surrounds it, so the two
  /// shapes cannot drift apart.
  Widget _buildBody(BuildContext context, {required Message? message, required bool inReply}) {
    return Row(
      // Full width with the spinner pushed to the trailing edge, rather than
      // tucked against the end of the text.
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _buildTextBlock(context, message: message, inReply: inReply)),
        if (controller.refreshRunning.value || controller.loading.value) _buildRefreshIndicator(context),
      ],
    );
  }

  /// The tap-to-load affordance first when it is showing, then the title, then
  /// the source row beneath it.
  ///
  /// The title/site ordering is Google Messages' arrangement, and the one the
  /// iOS skin already used: the headline leads and provenance sits under it,
  /// with the site's own mark beside the domain. The Expressive skin used to
  /// lead with the site line and hang a large favicon off the left of the whole
  /// block, which read as a list tile rather than a link card.
  ///
  /// The button leads everything else, rather than trailing as a footnote under
  /// content that has not loaded — this is a state where nothing has been
  /// fetched yet, so the action is the headline of the card, not an
  /// afterthought under a title/site line that is itself only ever payload text.
  Widget _buildTextBlock(BuildContext context, {required Message? message, required bool inReply}) {
    final site = controller.siteText;
    final hasSourceRow = site != null && site.isNotEmpty;

    // When the title *is* the host — which is what [UrlPreviewController.titleFor]
    // falls back to when the page supplied no title of its own — the source row
    // already says it, and rendering both would print the domain twice, once in
    // bold. Dropping the title leaves the icon + domain line, which is the more
    // informative of the two.
    final showsTitle = controller.showsSiteLine(message?.text) || !hasSourceRow;
    final showsManualLoad = controller.needsManualLoad.value && !inReply;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showsManualLoad) SizedBox(width: double.infinity, child: _buildLoadPreviewButton(context)),
        if (showsManualLoad) const SizedBox(height: M3ESpacing.lg),
        if (showsTitle) _buildTitle(context, message),
        if (showsTitle && hasSourceRow) const SizedBox(height: M3ESpacing.xs),
        if (hasSourceRow) _buildSourceRow(context),
      ],
    );
  }

  /// Favicon and domain on one line — where the link actually goes.
  ///
  /// The icon is sized to the site line's own text so it reads as part of that
  /// line rather than as a badge floating beside the card. The domain is
  /// derived from the URL, never from `og:site_name`.
  Widget _buildSourceRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (controller.hasIcon) _buildIcon(context, size: _sourceIconSize),
        if (controller.hasIcon) const SizedBox(width: M3ESpacing.sm),
        Flexible(child: _buildSiteLine(context)),
      ],
    );
  }

  /// Nothing resolved: one line saying where the link goes, plus the
  /// tap-to-load affordance when the policy is what is holding the preview back.
  Widget _buildBare(BuildContext context, {required bool inReply}) {
    final link = controller.linkText ?? controller.siteText ?? "";

    return Padding(
      padding: inReply
          ? const EdgeInsets.all(M3ESpacing.md)
          : const EdgeInsets.symmetric(horizontal: M3ESpacing.lg, vertical: M3ESpacing.md),
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
                    const SizedBox(width: M3ESpacing.sm),
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
              if (controller.refreshRunning.value || controller.loading.value) _buildRefreshIndicator(context),
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
      padding: const EdgeInsets.only(left: M3ESpacing.md),
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
      const SizedBox(height: M3ESpacing.lg),
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
    // Whether this image is new enough to be worth animating. The payload's own
    // artwork arrives on a different path from a downloaded preview image — an
    // attachment rather than a URL — so it carries its own flag; before that it
    // simply never animated, however it turned up.
    final bool animate;

    final Widget image;
    if (previewImagePath != null) {
      animate = !controller.previewImageFromDisk.value;
      image = Image.file(
        File(previewImagePath),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _imageFallback(context),
      );
    } else if (webImageUrl != null) {
      animate = false;
      image = Image.network(
        webImageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _imageFallback(context),
      );
    } else if (appleBytes != null) {
      animate = !controller.appleImageFromDisk.value;
      image = Image.memory(
        appleBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _imageFallback(context),
      );
    } else if (appleFile != null) {
      animate = !controller.appleImageFromDisk.value;
      image = Image.file(
        appleFile,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _imageFallback(context),
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
    if (!animate) return container;

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
  Widget _buildIcon(BuildContext context, {double size = _sourceIconSize}) {
    final iconImagePath = controller.iconImagePath.value;
    final webIconUrl = controller.webIconUrl;

    // A definite box rather than a max constraint: the source row's height must
    // not depend on the intrinsic size of whatever favicon came back, or the
    // domain shifts as icons of different sizes resolve. `contain` keeps a
    // non-square mark from being stretched into the square.
    final icon = SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        // Proportional to the mark. A radius chosen for a 40px badge rounds a
        // 16px favicon into a circle and eats its corners.
        borderRadius: BorderRadius.all(Radius.circular(size / 4)),
        child: iconImagePath != null
            ? Image.file(
                File(iconImagePath),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : Image.network(
                webIconUrl!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

    // Null while running, not an empty callback: an inert `() {}` kept the
    // button rippling on tap and announcing itself as actionable while the
    // load it represents was already in flight.
    return M3ETonalButton(
      icon: running ? Icons.hourglass_empty : Icons.download_outlined,
      label: running ? "Loading Preview\u{2026}" : "Load Preview",
      onPressed: running ? null : controller.loadManually,
      borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.md)),
    );
  }
}
