import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

/// iOS skin for the link preview card.
///
/// Keeps the iMessage treatment: 20px top corners, and the image letterboxed
/// over a blurred copy of itself.
///
/// Renders one of three shapes depending on how much the page gave us — see
/// [UrlPreviewLayout]. The card's width does not change between them, so a link
/// that resolves an image grows downward into the hero shape rather than
/// resizing in place.
class CupertinoUrlPreview extends StatelessWidget {
  const CupertinoUrlPreview({super.key, required this.controller});

  final UrlPreviewController controller;

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

  /// The full card: image on top, then title and site line.
  Widget _buildHero(BuildContext context, {required Message? message, required bool inReply}) {
    final webImageUrl = controller.webImageUrl;
    final previewImagePath = controller.previewImagePath.value;
    final resolvedContent = controller.resolvedContent;
    final contentFile = controller.contentFile;
    final hasAppleImage = controller.showsAppleImage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewImagePath != null || webImageUrl != null)
          _buildPreviewImage(
            context,
            animate: previewImagePath != null && !controller.previewImageFromDisk.value,
            previewImagePath: previewImagePath,
            webImageUrl: webImageUrl,
          ),
        if (hasAppleImage && resolvedContent?.bytes != null)
          _growIn(_buildBlurredImage(context, MemoryImage(resolvedContent!.bytes!), _appleImageFromBytes(context))),
        if (hasAppleImage && resolvedContent != null && resolvedContent.bytes == null && contentFile != null)
          _growIn(_buildBlurredImage(context, FileImage(contentFile), _appleImageFromFile(context))),
        Padding(
          padding: inReply
              ? const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0)
              : const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Above the title/site line rather than below them, so the action
              // reads as the card's headline rather than as a footnote under
              // content that has not loaded yet.
              if (controller.needsManualLoad.value && !inReply) _buildLoadPreviewButton(context),
              if (controller.needsManualLoad.value && !inReply) const SizedBox(height: 8),
              // Two nested rows so the two trailing/leading elements can align
              // differently: the spinner centres against the whole text block,
              // while the favicon stays level with the first line of it.
              Row(
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
                        if (controller.hasIcon) const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitle(context, message),
                              // I think it looks better without the summary -Zach
                              // if (controller.hasSummary && !inReply) const SizedBox(height: 5),
                              // if (controller.hasSummary && !inReply) _buildSummary(context),
                              if (controller.showsSiteLine(message?.text)) const SizedBox(height: 5),
                              if (controller.showsSiteLine(message?.text)) _buildSiteLine(context, inReply: inReply),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.refreshRunning.value || controller.loading.value) _buildRefreshIndicator(context),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// No image, but the page described itself: favicon, title and site line in a
  /// single dense row — [_buildHero] without the image header, and tighter
  /// padding with a smaller favicon to match.
  Widget _buildCompact(BuildContext context, {required Message? message, required bool inReply}) {
    return Padding(
      padding: inReply
          ? const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0)
          : const EdgeInsets.fromLTRB(18.0, 12.0, 18.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Above the title/site line rather than below them, so the action
          // reads as the card's headline rather than as a footnote under
          // content that has not loaded yet.
          if (controller.needsManualLoad.value && !inReply) _buildLoadPreviewButton(context),
          if (controller.needsManualLoad.value && !inReply) const SizedBox(height: 10),
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
                    // source badge for the line it sits against.
                    if (controller.hasIcon) _buildIcon(context, size: 32),
                    if (controller.hasIcon) const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(context, message),
                          if (controller.showsSiteLine(message?.text)) const SizedBox(height: 2),
                          if (controller.showsSiteLine(message?.text)) _buildSiteLine(context, inReply: inReply),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.refreshRunning.value || controller.loading.value) _buildRefreshIndicator(context),
            ],
          ),
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
          ? const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0)
          : const EdgeInsets.fromLTRB(15.0, 12.0, 15.0, 12.0),
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
                    Icon(CupertinoIcons.link, size: 14, color: context.theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        link,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.labelMedium!.copyWith(
                          fontWeight: FontWeight.normal,
                          color: context.theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.refreshRunning.value || controller.loading.value) _buildRefreshIndicator(context),
            ],
          ),
          if (controller.needsManualLoad.value && !inReply) const SizedBox(height: 10),
          if (controller.needsManualLoad.value && !inReply) _buildLoadPreviewButton(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  Widget _buildTitle(BuildContext context, Message? message) {
    return Text(
      controller.titleFor(message?.text),
      style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // Widget _buildSummary(BuildContext context) {
  //   return Text(
  //     controller.summary ?? "",
  //     maxLines: 3,
  //     overflow: TextOverflow.ellipsis,
  //     style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal),
  //   );
  // }

  /// Trailing spinner shown while "Refresh Preview" is re-fetching.
  ///
  /// Trailing because the favicon leads; it sits in the space the favicon used
  /// to occupy, so nothing else on the card shifts while it is up. Vertically
  /// centred against the text block by the row that holds it.
  Widget _buildRefreshIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: CupertinoActivityIndicator(
        radius: 8,
        color: context.theme.colorScheme.outline,
      ),
    );
  }

  Widget _buildSiteLine(BuildContext context, {required bool inReply}) {
    return Text(
      controller.siteText!,
      style: context.theme.textTheme.labelMedium!
          .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
      overflow: inReply ? TextOverflow.ellipsis : TextOverflow.clip,
      maxLines: 1,
    );
  }

  /// The favicon.
  ///
  /// Renders from the disk cache, and only falls back to the network on web,
  /// where there is no disk cache — see [UrlPreviewController.webIconUrl] for
  /// why there is no such fallback anywhere else. A load failure collapses the
  /// icon rather than surfacing as an uncaught rendering error.
  Widget _buildIcon(BuildContext context, {double size = 45}) {
    final iconImagePath = controller.iconImagePath.value;
    final webIconUrl = controller.webIconUrl;

    final icon = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: iconImagePath != null
            ? Image.file(
                File(iconImagePath),
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : Image.network(
                webIconUrl!,
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
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
      opacity: CurvedAnimation(parent: controller.iconAnimation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: controller.iconAnimation, curve: Curves.easeOutBack),
        child: icon,
      ),
    );
  }

  /// The tap-to-load affordance shown when the policy declines to fetch a
  /// preview on its own.
  ///
  /// Deliberately understated: this appears on links from unknown senders, and
  /// it should read as an available action rather than as a warning about the
  /// message.
  Widget _buildLoadPreviewButton(BuildContext context) {
    final color = context.theme.colorScheme.primary;
    final running = controller.manualLoadRunning.value;

    return InkWell(
      onTap: running ? null : controller.loadManually,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed slot: the spinner and the icon are different sizes, and
            // letting them size the row shifts the label sideways the moment
            // the user taps.
            SizedBox(
              width: 14,
              height: 14,
              child: running
                  ? CircularProgressIndicator(strokeWidth: 2, color: color)
                  : Icon(CupertinoIcons.cloud_download, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              running ? "Loading Preview\u{2026}" : "Load Preview",
              style: context.theme.textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Images
  // ---------------------------------------------------------------------------

  /// Builds the preview image container. When [animate] is true (fresh
  /// download) the container is wrapped in [SizeTransition] so it grows in
  /// smoothly. When [animate] is false (disk load or web) it is returned as-is
  /// to avoid the re-entrancy crash that occurs when [AnimatedSize] ticks its
  /// animation controller during its own [performLayout].
  Widget _buildPreviewImage(
    BuildContext context, {
    required bool animate,
    required String? previewImagePath,
    required String? webImageUrl,
  }) {
    final ImageProvider imageProvider =
        previewImagePath != null ? FileImage(File(previewImagePath)) : NetworkImage(webImageUrl!) as ImageProvider;

    final container = _buildBlurredImage(
      context,
      imageProvider,
      previewImagePath != null
          ? Image.file(
              File(previewImagePath),
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => _imageErrorText(context),
            )
          : Image.network(
              webImageUrl ?? '',
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => _imageErrorText(context),
            ),
    );

    if (!animate) return container;
    return _sizeTransition(container);
  }

  /// Wraps the plugin payload's artwork (Apple Music and friends) in the same
  /// grow-in the downloaded preview image gets.
  ///
  /// This image arrives on its own path — an attachment, not a URL — so it does
  /// not go through [_buildPreviewImage] and used to appear with no animation at
  /// all, however it turned up. It animates on the same rule as everything else:
  /// only when it landed while the user was looking.
  Widget _growIn(Widget child) {
    if (controller.appleImageFromDisk.value) return child;
    return _sizeTransition(child);
  }

  /// SizeTransition animates via the ticker between frames (not during
  /// performLayout), so it never causes the re-entrancy crash that AnimatedSize
  /// triggers when a child changes size during layout.
  Widget _sizeTransition(Widget child) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: controller.imageAnimation, curve: Curves.easeIn),
      axisAlignment: -1.0,
      child: child,
    );
  }

  /// The iMessage image treatment: [child] letterboxed over a blurred,
  /// cover-fitted copy of [backdrop].
  Widget _buildBlurredImage(BuildContext context, ImageProvider backdrop, Widget child) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          // The foreground image has an errorBuilder, but a DecorationImage has
          // no such thing — without onError a deleted cache file or an
          // unreachable host escapes as an uncaught rendering error.
          image: DecorationImage(
            image: backdrop,
            fit: BoxFit.cover,
            onError: (ex, stack) =>
                Logger.debug('Failed to load URL preview backdrop: $ex', tag: 'CupertinoUrlPreview'),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageErrorText(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
    );
  }

  /// The plugin-payload image rendered from bytes.
  Widget _appleImageFromBytes(BuildContext context) {
    return Image.memory(
      controller.resolvedContent!.bytes!,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => _imageErrorText(context),
    );
  }

  /// The plugin-payload image rendered from a file, with the stacktrace
  /// inspector kept from the original implementation — this is the path that
  /// historically failed on malformed payloads.
  Widget _appleImageFromFile(BuildContext context) {
    return Image.file(
      controller.contentFile!,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, object, stacktrace) => Center(
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 5.0),
          child: Row(children: [
            Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            const SizedBox(width: 2.0),
            IconButton(
                onPressed: () {
                  showBBDialog(
                    context: context,
                    title: "URL Preview Stacktrace",
                    content: SizedBox(
                      width: NavigationSvc.width(context) * 3 / 5,
                      height: context.height * 1 / 4,
                      child: Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                            color: context.theme.colorScheme.surface,
                            borderRadius: const BorderRadius.all(Radius.circular(10))),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            stacktrace.toString(),
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
                },
                icon: const Icon(CupertinoIcons.info_circle))
          ]),
        ),
      ),
    );
  }
}
