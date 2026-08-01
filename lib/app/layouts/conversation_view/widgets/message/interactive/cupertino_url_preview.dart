import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

/// iOS skin for the link preview card.
///
/// Rendering is unchanged from the single-widget version this was split out of:
/// 20px top corners, and the image letterboxed over a blurred copy of itself,
/// which is the iMessage treatment.
class CupertinoUrlPreview extends StatelessWidget {
  const CupertinoUrlPreview({super.key, required this.controller});

  final UrlPreviewController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final message = MessageStateScope.maybeMessageOf(context);
      final inReply = ReplyScope.maybeOf(context) != null;

      final data = controller.effectiveData;
      final webImageUrl = controller.webImageUrl;
      final previewImagePath = controller.previewImagePath.value;
      final iconImagePath = controller.iconImagePath.value;
      final siteText = controller.siteText;
      final resolvedContent = controller.resolvedContent;
      final contentFile = controller.contentFile;
      final hasAppleImage = controller.showsAppleImage;

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
            if (!inReply && (previewImagePath != null || webImageUrl != null))
              _buildPreviewImage(
                context,
                animate: previewImagePath != null && !controller.previewImageFromDisk.value,
                previewImagePath: previewImagePath,
                webImageUrl: webImageUrl,
              ),
            if (resolvedContent?.bytes != null && hasAppleImage && !inReply)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: MemoryImage(resolvedContent!.bytes!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                        child: Image.memory(
                          resolvedContent!.bytes!,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (context, object, stacktrace) => Center(
                            heightFactor: 1,
                            child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (resolvedContent != null &&
                hasAppleImage &&
                resolvedContent.bytes == null &&
                contentFile != null &&
                !inReply)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(contentFile),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                        child: Image.file(
                          contentFile,
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: inReply
                  ? const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0)
                  : const EdgeInsets.fromLTRB(15.0, 20, 15.0, 15.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child:
                        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        controller.titleFor(message?.text),
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (controller.hasSummary && !inReply) const SizedBox(height: 5),
                      if (controller.hasSummary && !inReply)
                        Text(controller.summary ?? "",
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)),
                      if (!isNullOrEmpty(siteText) && !inReply) const SizedBox(height: 5),
                      if (!isNullOrEmpty(siteText) && !inReply)
                        Text(
                          siteText!,
                          style: context.theme.textTheme.labelMedium!
                              .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                        ),
                      if (!isNullOrEmpty(siteText) && inReply) const SizedBox(height: 5),
                      if (!isNullOrEmpty(siteText) && inReply)
                        Text(
                          siteText!,
                          style: context.theme.textTheme.labelMedium!
                              .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      if (controller.needsManualLoad.value && !inReply) const SizedBox(height: 8),
                      if (controller.needsManualLoad.value && !inReply) _buildLoadPreviewButton(context),
                    ]),
                  ),
                  if (controller.hasIcon) const SizedBox(width: 10),
                  if (controller.hasIcon)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 45,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: iconImagePath != null
                            ? Image.file(
                                File(iconImagePath),
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.none,
                              )
                            : Image.network(
                                data.iconMetadata!.url!,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.none,
                              ),
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
      );
    });
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
            if (running)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(CupertinoIcons.cloud_download, size: 14, color: color),
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

    final container = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                child: previewImagePath != null
                    ? Image.file(
                        File(previewImagePath),
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      )
                    : Image.network(
                        webImageUrl ?? '',
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!animate) return container;

    // SizeTransition animates via the ticker between frames (not during
    // performLayout), so it never causes the re-entrancy crash that
    // AnimatedSize triggers when a child changes size during layout.
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: controller.imageAnimation, curve: Curves.easeIn),
      axisAlignment: -1.0,
      child: container,
    );
  }
}
