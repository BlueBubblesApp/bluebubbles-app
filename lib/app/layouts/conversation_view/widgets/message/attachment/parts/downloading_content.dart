import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Attachment being downloaded from the server.
/// The Obx reacts only to download-state and progress changes.
class DownloadingContent extends StatelessWidget {
  const DownloadingContent({
    super.key,
    required this.downloadController,
    required this.isInReply,
    required this.isiOS,
    this.isInCollection = false,
    this.compact = false,
  });

  final AttachmentDownloadController downloadController;
  final bool isInReply;
  final bool isiOS;
  final bool isInCollection;

  /// Forces the small ring + label row instead of the full icon-and-labels
  /// card. Set by [AttachmentHolder] when the box reserved for the incoming
  /// image is too small to host the full layout at its natural size.
  final bool compact;

  /// Roughly what the full layout needs: the inner `minWidth: 150` plus its
  /// 20pt side padding, and 40 + icon(52) + two text lines + 20 vertically.
  /// [AttachmentHolder] compares a reserved box against this to decide whether
  /// to ask for [compact].
  static const Size fullVariantMinSize = Size(190, 150);

  @override
  Widget build(BuildContext context) {
    final mimeType = downloadController.attachment.mimeType ?? '';
    final friendlyType = mimeTypeToFriendlyName(mimeType);
    final totalBytes = downloadController.attachment.totalBytes ?? 0;
    final fileSize = totalBytes > 0 ? (totalBytes.toDouble()).getFriendlySize(decimals: 0) : null;

    return Obx(() {
      final isError = downloadController.state.value == AttachmentDownloadState.error;
      final isProcessing = downloadController.state.value == AttachmentDownloadState.processing;
      final isQueued = downloadController.state.value == AttachmentDownloadState.queued;

      // Compact variant: just a small ring + status label, no icon, no file size.
      if (isInReply || compact) {
        return ConstrainedBox(
          // The Flexible below needs a finite width to lay out against, and
          // AttachmentHolder's reserved-box backstop is a FittedBox, which
          // hands its child unbounded constraints. Reply bubbles supply a
          // bounded width themselves, but capping here is harmless for them.
          constraints: const BoxConstraints(maxWidth: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: isError
                    ? Icon(
                        isiOS ? CupertinoIcons.arrow_clockwise : Icons.refresh,
                        size: 14,
                        color: context.theme.colorScheme.error,
                      )
                    : isProcessing
                        ? (isiOS
                            ? const CupertinoActivityIndicator(radius: 7)
                            : CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation(context.theme.colorScheme.onSurfaceVariant),
                              ))
                        : isQueued
                            ? Icon(
                                isiOS ? CupertinoIcons.clock : Icons.schedule,
                                size: 14,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              )
                            : CircleProgressBar(
                                value: downloadController.progress.value?.toDouble() ?? 0,
                                backgroundColor: context.theme.colorScheme.outline,
                                foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                                strokeWidth: 1.5,
                              ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isError
                      ? 'Failed'
                      : isProcessing
                          ? 'Processing'
                          : isQueued
                              ? 'Queued'
                              : 'Downloading',
                  style: context.theme.textTheme.bodySmall!.copyWith(
                    color: isError ? context.theme.colorScheme.error : context.theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            ),
          ),
        );
      }

      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: isInReply ? 10.0 : 40.0,
              bottom: isInReply ? 10.0 : 20.0,
            ),
            child: ConstrainedBox(
              // Minimum width sized to the longest possible label ("Failed to
              // download") so all states render at a consistent width and the
              // widget never resizes when transitioning between states.
              constraints: const BoxConstraints(minWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Large document-type icon — always represents the file kind
                  Icon(
                    getAttachmentIcon(mimeType),
                    size: 52,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                  // File size (shown when known)
                  if (fileSize != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        fileSize,
                        style: context.theme.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  // Download state label — centered on its own
                  Text(
                    isError
                        ? 'Failed to download'
                        : isProcessing
                            ? 'Processing...'
                            : isQueued
                                ? 'Queued'
                                : 'Downloading...',
                    style: context.theme.textTheme.bodySmall!.copyWith(
                      color: isError ? context.theme.colorScheme.error : context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Download state indicator — top-right, opposite the mime-type badge
          Positioned(
            top: isInCollection ? 10 : 5,
            right: isInCollection ? 10 : 0,
            child: SizedBox(
              width: 16,
              height: 16,
              child: isError
                  ? Icon(
                      isiOS ? CupertinoIcons.arrow_clockwise : Icons.refresh,
                      size: 14,
                      color: context.theme.colorScheme.error,
                    )
                  : isProcessing
                      ? (isiOS
                          ? const CupertinoActivityIndicator(radius: 7)
                          : CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation(context.theme.colorScheme.onSurfaceVariant),
                            ))
                      : isQueued
                          ? Icon(
                              isiOS ? CupertinoIcons.clock : Icons.schedule,
                              size: 14,
                              color: context.theme.colorScheme.onSurfaceVariant,
                            )
                          : CircleProgressBar(
                              value: downloadController.progress.value?.toDouble() ?? 0,
                              backgroundColor: context.theme.colorScheme.outline,
                              foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                              strokeWidth: 1.5,
                            ),
            ),
          ),
          // Mime-type badge — top-left, styled like the LIVE photo tag
          Positioned(
            top: isInCollection ? 10 : 5,
            left: isInCollection ? 10 : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                friendlyType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
