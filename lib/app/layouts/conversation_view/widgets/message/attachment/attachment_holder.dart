import 'dart:async';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/sending_opacity_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/upload_progress_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/not_loaded_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/downloading_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/resolved_file_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/attachment_state.dart';
import 'package:bluebubbles/app/state/attachment_state_scope.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/ui/attributed_body_helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ── Public entry-point ────────────────────────────────────────────────────────

class AttachmentHolder extends StatefulWidget {
  const AttachmentHolder({
    super.key,
    required this.message,
    this.transparentBackground = false,
    this.showCardShadow = false,
    this.galleryAttachments,
  });

  final MessagePart message;
  final bool transparentBackground;
  final bool showCardShadow;
  final List<Attachment>? galleryAttachments;

  @override
  State<StatefulWidget> createState() => _AttachmentHolderState();
}

class _AttachmentHolderState extends State<AttachmentHolder> with ThemeHelpers {
  late MessageState _ms;
  MessageState get controller => _ms;
  Worker? _refreshWorker;
  late final String _chatGuid;
  MessagePart get part => widget.message;
  Message get message => controller.message;
  Message? get newerMessage => controller.newMessage;

  Attachment get attachment =>
      message.dbAttachments.firstWhereOrNull((e) => e.id == part.attachments.first.id) ??
      MessagesSvc(_chatGuid).struct.attachments.firstWhereOrNull((e) => e.id == part.attachments.first.id) ??
      part.attachments.first;

  String? get audioTranscript => getAudioTranscriptsFromAttributedBody(message.attributedBody)[part.part];

  // ── AttachmentState access ─────────────────────────────────────────────────

  /// Resolves the [AttachmentState] for this attachment, creating one via
  /// [MessageState.getOrCreateAttachmentState] when needed.
  ///
  /// Lookup strategy (most-to-least stable):
  /// 1. Original part-level GUID (`part.attachments.first.guid`) — this is
  ///    always the temp GUID for outgoing messages and never changes on the
  ///    MessagePart, so the scope reference survives the temp → real swap.
  /// 2. Current `attachment.guid` — used once the state has been promoted.
  /// 3. Ephemeral fallback — when [MessageState] is not yet available.
  AttachmentState _resolveAttachmentState() {
    final currentAttachment = attachment;

    // Try the original part GUID first (stable key, even after GUID swap).
    final originalGuid = part.attachments.first.guid;
    if (originalGuid != null) {
      return controller.getOrCreateAttachmentState(originalGuid, attachment: currentAttachment);
    }

    // Fall back to the current resolved attachment GUID.
    final currentGuid = currentAttachment.guid;
    if (currentGuid != null) {
      return controller.getOrCreateAttachmentState(currentGuid, attachment: currentAttachment);
    }

    // Fallback: ephemeral state when no GUID is set.
    return AttachmentState(currentAttachment);
  }

  /// Resolves the [MessagesService] for the chat that owns this message.
  MessagesService get _msvc => MessagesSvc(_chatGuid);

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
    _chatGuid = _ms.cvController?.chat.guid ?? ChatStateScope.readChatOnce(context).guid;
    _refreshWorker = ever(_ms.attachmentRefreshKey, (_) => _loadContent());
    _loadContent();
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AttachmentHolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.message.attachments.firstOrNull?.id;
    final newId = widget.message.attachments.firstOrNull?.id;
    final oldGuid = oldWidget.message.attachments.firstOrNull?.guid;
    final newGuid = widget.message.attachments.firstOrNull?.guid;
    if (oldId != newId || oldGuid != newGuid) {
      _loadContent();
    }
  }

  // ── Content loading ────────────────────────────────────────────────────────

  /// Delegates all content loading and download orchestration to the service
  /// layer.  The widget only reacts to [_attachmentState] observable changes.
  void _loadContent() {
    final msgGuid = message.guid;
    if (msgGuid == null) return;
    if (!Get.isRegistered<MessagesService>(tag: _msvc.tag)) return;
    unawaited(_msvc.loadAttachmentContent(msgGuid, attachment));
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  VoidCallback? _buildOnTap(AttachmentState state) {
    // Already resolved — no tap action needed.
    if (state.resolvedFile.value != null) return null;

    return () {
      final isSending = state.isSending.value;
      if (message.error != 0 || isSending) return;

      final msgGuid = message.guid;
      if (msgGuid == null) return;

      final activeDownload = state.activeDownload.value;
      if (activeDownload != null) {
        // Only retry on error; ignore taps while already downloading.
        if (activeDownload.state.value != AttachmentDownloadState.error) return;
        _msvc.retryAttachmentDownload(msgGuid, attachment);
      } else {
        _msvc.startAttachmentDownload(msgGuid, attachment);
      }
    };
  }

  EdgeInsetsGeometry _computePadding(AttachmentState state, bool hideAttachments, bool showTail, bool isInReply) {
    final sideInsets = EdgeInsets.only(
      left: message.isFromMe! ? 0 : 10,
      right: message.isFromMe! ? 10 : 0,
    );

    // Treat an error preview the same as a resolved file — no extra padding.
    final hasError = state.hasError.value || message.error > 0;
    final effectiveFile =
        state.resolvedFile.value ?? (hasError && message.isFromMe == true ? state.uploadPreviewFile.value : null);

    if (effectiveFile != null && !hideAttachments) {
      return showTail ? EdgeInsets.zero : sideInsets;
    }
    if (isInReply) {
      return const EdgeInsets.symmetric(vertical: 5, horizontal: 10).add(sideInsets);
    }
    if (state.isSending.value && message.isFromMe!) {
      return EdgeInsets.zero;
    }
    // Gallery cards (transparentBackground=true) constrain their height via an
    // outer SizedBox. DownloadingContent / NotLoadedContent handle their own
    // internal padding, so adding extra padding here causes overflow.
    if (widget.transparentBackground) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(sideInsets);
  }

  Widget _buildContent({
    required AttachmentState state,
    required bool hideAttachments,
    required bool showTail,
    required bool isInReply,
    required bool isiOS,
  }) {
    // Redacted mode always shows placeholder regardless of download status.
    if (hideAttachments) {
      return NotLoadedContent(
        hideAttachments: true,
        isiOS: isiOS,
      );
    }

    // Outgoing send failed — render the local file as normal so it shows next
    // to the ErrorIndicatorObserver in MessageHolder (which handles the error UI).
    final hasError = state.hasError.value || message.error > 0;
    if (hasError && message.isFromMe == true) {
      final previewFile = state.uploadPreviewFile.value ?? state.resolvedFile.value;
      if (previewFile != null) {
        return ResolvedFileContent(
          file: previewFile,
          audioTranscript: audioTranscript,
          showTail: showTail,
          isiOS: isiOS,
          cvController: controller.cvController,
          isInReply: isInReply,
          forceAllCornersRounded: widget.transparentBackground,
          galleryAttachments: widget.galleryAttachments,
        );
      }
    }

    // File is available — render it.
    final file = state.resolvedFile.value;
    if (file != null) {
      return ResolvedFileContent(
        file: file,
        audioTranscript: audioTranscript,
        showTail: showTail,
        isiOS: isiOS,
        cvController: controller.cvController,
        isInReply: isInReply,
        forceAllCornersRounded: widget.transparentBackground,
        galleryAttachments: widget.galleryAttachments,
      );
    }

    // Upload in progress — show progress overlay (with optional preview).
    if (state.isSending.value) {
      return UploadProgressContent(
        isiOS: isiOS,
        cvController: controller.cvController,
      );
    }

    // Download in progress — show the download controller's progress UI.
    final download = state.activeDownload.value;
    if (download != null) {
      return DownloadingContent(
        downloadController: download,
        isInReply: isInReply,
        isiOS: isiOS,
        isInGallery: widget.transparentBackground,
      );
    }

    // Not yet loaded, queued, or errored.
    return NotLoadedContent(
      hideAttachments: false,
      isiOS: isiOS,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isInReply = ReplyScope.maybeOf(context) != null;
    final bool isPass = attachment.isPkPass;
    final bool showTail =
        !isInReply && !isPass && message.showTail(newerMessage) && part.part == controller.parts.length - 1;

    // Resolve state once for the scope.  The AttachmentState object is updated
    // in-place by the service layer; no re-lookup is needed on reactive changes.
    final state = _resolveAttachmentState();

    return AttachmentStateScope(
      attachmentState: state,
      child: Obx(() {
        final bool isiOS = iOS;
        // Read shouldHideAttachments inside the Obx so the widget rebuilds
        // reactively when the setting is toggled (fixes a bug where the value
        // was computed outside the Obx closure and became stale).
        final bool hideAttachments = _ms.shouldHideAttachments.value;
        final bool selected = !isiOS && (controller.cvController?.selected.any((m) => m.guid == message.guid) ?? false);

        // Reading these observables registers the Obx dependency so the widget
        // rebuilds whenever transfer state, resolved file, or active download
        // changes — including service-driven transitions (upload complete,
        // incoming GUID swap, auto-download started from another code path).
        // ignore: unused_local_variable
        final _ = state.transferState.value;
        // ignore: unused_local_variable
        final __ = state.resolvedFile.value;
        // ignore: unused_local_variable
        final ___ = state.activeDownload.value;
        // ignore: unused_local_variable
        final ____ = state.hasError.value;

        final hasError = state.hasError.value || message.error > 0;
        final hasPreview = state.resolvedFile.value != null ||
            (hasError && message.isFromMe == true && state.uploadPreviewFile.value != null);
        final transparentCard = hasPreview && (widget.transparentBackground || isPass);
        // Gallery cards in non-preview states (downloading, not-loaded, etc.) need
        // to fill the SizedBox dimensions set by MessageImageGallery and have their
        // background clipped to rounded corners.
        final shouldExpandAndClipForGallery = widget.transparentBackground && !hasPreview;
        Widget content = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _buildOnTap(state),
            child: Ink(
              color: transparentCard ? Colors.transparent : context.theme.colorScheme.surfaceContainerHighest,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: NavigationSvc.width(context) * 0.5,
                  maxHeight: isInReply ? double.infinity : context.height * 0.6,
                  minHeight: isInReply ? 0 : 40,
                  minWidth: isInReply ? 0 : 100,
                ),
                child: Padding(
                  padding: _computePadding(state, hideAttachments, showTail, isInReply),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    // AnimatedSize loosens constraints, so content would render at its
                    // natural size — smaller than the gallery SizedBox. SizedBox.expand()
                    // snaps back to the max loosened constraints (= cardWidth x cardHeight)
                    // and forces tight dimensions all the way down to the content widget.
                    child: shouldExpandAndClipForGallery
                        ? SizedBox.expand(
                            child: SendingOpacityWrapper(
                              child: _buildContent(
                                state: state,
                                hideAttachments: hideAttachments,
                                showTail: showTail,
                                isInReply: isInReply,
                                isiOS: isiOS,
                              ),
                            ),
                          )
                        : Center(
                            heightFactor: 1,
                            widthFactor: 1,
                            // SendingOpacityWrapper has its own Obx so isSending
                            // changes only rebuild the opacity layer, not this tree.
                            child: DecoratedBox(
                              decoration: widget.showCardShadow
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    )
                                  : const BoxDecoration(),
                              child: SendingOpacityWrapper(
                                child: _buildContent(
                                  state: state,
                                  hideAttachments: hideAttachments,
                                  showTail: showTail,
                                  isInReply: isInReply,
                                  isiOS: isiOS,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Gallery non-preview: wrap with shadow + rounded clip at the card boundary.
        // This clips the surfaceContainerHighest Ink background to rounded corners and
        // places the shadow around the full card rather than the smaller content widget.
        if (shouldExpandAndClipForGallery) {
          content = DecoratedBox(
            decoration: widget.showCardShadow
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  )
                : const BoxDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: content,
            ),
          );
        }
        // ColorFiltered is only for standalone (non-gallery) selection tinting.
        // In gallery mode (transparentBackground = true), the ColorFilter creates a
        // saveLayer bounded by the messages view repaint boundary. The dstOver blend
        // then fills every transparent pixel in that large layer with tertiaryContainer,
        // turning the entire messages view pink/purple while an attachment downloads.
        if (!transparentCard && !widget.transparentBackground) {
          content = ColorFiltered(
            colorFilter: ColorFilter.mode(
              context.theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              selected ? BlendMode.srcOver : BlendMode.dstOver,
            ),
            child: content,
          );
        }
        return content;
      }),
    );
  }
}
