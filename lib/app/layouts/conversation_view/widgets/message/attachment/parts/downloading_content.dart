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
    required this.showTail,
    required this.isFromMe,
    required this.hasReservedSize,
    this.isInCollection = false,
    this.compact = false,
  });

  final AttachmentDownloadController downloadController;
  final bool isInReply;
  final bool isiOS;
  final bool isInCollection;

  /// Whether [AttachmentHolder] is reserving a server-provided width/height
  /// for this attachment versus falling back to this widget's own default
  /// size. The default card trims its side/bottom padding — top padding stays
  /// fixed either way since it's the clearance the corner tags need, not
  /// decorative space.
  final bool hasReservedSize;

  /// Whether this message's bubble renders the tail notch. [TailClipper]
  /// always insets the tail side by 10pt, whether or not the notch itself is
  /// drawn there, so the corner tag on that side needs a matching extra
  /// inset to avoid getting cropped by it.
  final bool showTail;
  final bool isFromMe;

  /// Forces the small ring + label row instead of the full icon-and-labels
  /// card. Set by [AttachmentHolder] when the box reserved for the incoming
  /// image is too small to host the full layout at its natural size.
  final bool compact;

  /// Roughly what the full layout needs: the inner `minWidth: 150` plus its
  /// 20pt side padding, and 40 + icon(52) + two text lines + 20 vertically.
  /// [AttachmentHolder] compares a reserved box against this to decide whether
  /// to ask for [compact].
  static const Size fullVariantMinSize = Size(190, 150);

  /// Fixed footprint used when [hasReservedSize] is false. Without a real
  /// reserved box to fill, the Stack below has nothing else to size itself
  /// against, so it just shrink-wraps its padded content — meaning content
  /// padding and the Stack's own size are the same number, and turning one
  /// down turns the other down too. Giving it this explicit size instead
  /// (mirroring what AttachmentHolder's reserved box gives the other variant)
  /// makes the padding values below pure insets from a fixed edge, so they
  /// move content/tags around inside the card instead of resizing it.
  static const Size defaultSize = Size(170, 140);

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

      // Corner-tag padding. TailClipper insets the tail side by a fixed 10pt
      // whenever a tail is shown (see tail_clipper.dart), independent of
      // whatever padding AttachmentHolder applies around this widget — so the
      // tag on that side needs a matching extra inset or it renders flush
      // against (or cropped by) the clipped edge. A few extra pt beyond that
      // 10pt gives the tag some visual breathing room from the curved corner
      // instead of sitting exactly on the clip boundary.
      final basePadding = isInCollection ? 10.0 : (hasReservedSize ? 8.0 : 0);
      final topPadding = hasReservedSize ? 14.0 : isInCollection ? 10.0 : 4.0;
      final tailInset = showTail ? (hasReservedSize ? 14.0 : 0.0) : 0.0;

      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // scaleDown is a backstop only — AttachmentHolder only reaches this
          // branch when the reserved box is at least fullVariantMinSize, so in
          // practice this content already fits and the FittedBox is a no-op.
          // It exists so a reserved box that's exactly at that boundary can't
          // overflow now that the surrounding Stack is sized tightly to the
          // box (needed so the corner tags below land on its true corners).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                // Fixed regardless of variant: this is the clearance the
                // corner tags below need (topPadding + badge height), not
                // decorative space, so shrinking it risks the icon overlapping
                // the tags rather than just a tighter-looking card.
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
          ),
          // Download state indicator — top-right, opposite the mime-type badge.
          // TailClipper always insets the tail side by 10pt (whether or not the
          // notch itself is drawn there), so this side needs a matching extra
          // inset when it's the tail side (outgoing messages) and the tail is
          // showing, or the ring gets cropped by the bubble clip.
          Positioned(
            top: topPadding,
            right: basePadding + (hasReservedSize ? 4 : 0) + (isFromMe ? tailInset : 0),
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
          // Mime-type badge — top-left, styled like the LIVE photo tag. Same
          // tail-side inset as the status indicator, mirrored for incoming
          // messages (the tail side is on the left there).
          Positioned(
            top: topPadding,
            left: basePadding + 5 + (isFromMe ? 4 : tailInset),
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
