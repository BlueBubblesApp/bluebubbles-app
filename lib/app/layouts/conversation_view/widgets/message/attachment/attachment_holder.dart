import 'dart:async';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/sending_opacity_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/upload_progress_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/not_loaded_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/downloading_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/parts/resolved_file_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
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
    this.fill = false,
    this.galleryAttachments,
    this.collectionController,
  });

  final MessagePart message;

  /// Cover-expand into a parent-fixed frame and suppress standalone bubble chrome
  /// (padding, selection tint, holder shadow/radius). Parents own clip/shadow.
  /// Disabled automatically inside [PopupScope].
  final bool fill;
  final List<Attachment>? galleryAttachments;

  /// When set, fullscreen viewers show a collection-grid button (omit when opened from the collections gallery).
  final CollectionMediaController? collectionController;

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

  /// The box an image attachment will occupy once it renders, so the
  /// download / not-loaded placeholders can reserve exactly that space and
  /// nothing moves when the file finally resolves.
  ///
  /// Null when the size isn't knowable or reserving it would be wrong:
  /// - dimensions haven't been extracted yet (nothing to reserve),
  /// - reply bubbles and gallery cards, which impose their own geometry,
  /// - non-images. Video is deliberately excluded: `VideoPlayer` doesn't size
  ///   itself from [Attachment.displayBox], so reserving that box would just
  ///   move the jump rather than remove it.
  ({double width, double height})? _reservedImageBox(BuildContext context, bool isInReply, bool hideAttachments) {
    if (isInReply || hideAttachments || widget.fill) return null;
    if (attachment.mimeStart != "image") return null;
    if (!attachment.hasValidSize) return null;
    return attachment.displayBox(NavigationSvc.width(context) * 0.5, context.height * 0.6);
  }

  EdgeInsetsGeometry _computePadding(
    AttachmentState state,
    bool hideAttachments,
    bool showTail,
    bool isInReply, {
    required bool hasReservedBox,
  }) {
    final sideInsets = EdgeInsets.only(
      left: message.isFromMe! ? 0 : 10,
      right: message.isFromMe! ? 10 : 0,
    );

    // Collection fill cards are sized by the parent; padding is on the collection wrapper.
    // Use [widget.fill] (not the popup-adjusted layout fill) so popup cards stay zero-padded.
    if (widget.fill) {
      return EdgeInsets.zero;
    }

    // Treat an error preview the same as a resolved file — no extra padding.
    final hasError = state.hasError.value || message.error > 0;
    final effectiveFile =
        state.resolvedFile.value ?? (hasError && message.isFromMe == true ? state.uploadPreviewFile.value : null);

    // A reserved box means the placeholder is standing in for the image at its
    // exact final size, so it has to take the image's padding too — otherwise
    // the outer geometry still shifts by the padding delta on resolve.
    if ((effectiveFile != null || hasReservedBox) && !hideAttachments) {
      return showTail ? EdgeInsets.zero : sideInsets;
    }
    if (isInReply) {
      return const EdgeInsets.symmetric(vertical: 5, horizontal: 10).add(sideInsets);
    }
    if (state.isSending.value && message.isFromMe!) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(sideInsets);
  }

  /// Reserves [box] around a pre-resolve placeholder so it claims exactly the
  /// space the image will.
  ///
  /// The placeholder is deliberately **not** scaled to the box. Scaling made
  /// every download card a different size and a different text size, since the
  /// factor came from whatever aspect ratio that particular photo happened to
  /// have. Callers instead switch to the compact layout (see
  /// [_useCompactPlaceholder]) when the box can't host the full one, so the
  /// content always renders at its designed proportions.
  ///
  /// [stretch] lets a full-layout child (never smaller than [box] — that's
  /// what [_useCompactPlaceholder] guarantees) fill the reserved box exactly,
  /// so its own corner-positioned content (e.g. [DownloadingContent]'s mime
  /// and status tags) lands at the true corners of the placeholder instead of
  /// hugging its own natural-size content when that's smaller than [box].
  /// Compact children still center at natural size with a scaleDown backstop,
  /// since they don't lay out their content relative to the full box.
  Widget _reserve(({double width, double height})? box, Widget child, {bool stretch = false}) {
    if (box == null) return child;
    if (stretch) {
      return SizedBox(width: box.width, height: box.height, child: child);
    }
    return SizedBox(
      width: box.width,
      height: box.height,
      // scaleDown is a backstop only, for a box too small even for the compact
      // layout. It is a no-op whenever the child already fits.
      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
    );
  }

  /// Whether [box] is too small to host a placeholder of [naturalSize] without
  /// squashing it.
  bool _useCompactPlaceholder(({double width, double height})? box, Size naturalSize) {
    if (box == null) return false;
    return box.width < naturalSize.width || box.height < naturalSize.height;
  }

  Widget _buildContent({
    required AttachmentState state,
    required bool hideAttachments,
    required bool showTail,
    required bool isInReply,
    required bool isiOS,
    required ({double width, double height})? reservedBox,
    required bool fill,
    required bool forceAllCornersRounded,
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
          forceAllCornersRounded: forceAllCornersRounded,
          fill: fill,
          galleryAttachments: widget.galleryAttachments,
          collectionController: widget.collectionController,
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
        forceAllCornersRounded: forceAllCornersRounded,
        fill: fill,
        galleryAttachments: widget.galleryAttachments,
        collectionController: widget.collectionController,
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
      final compact = _useCompactPlaceholder(reservedBox, DownloadingContent.fullVariantMinSize);
      return _reserve(
        reservedBox,
        DownloadingContent(
          downloadController: download,
          isInReply: isInReply,
          isiOS: isiOS,
          isInCollection: widget.fill,
          compact: compact,
          showTail: showTail,
          isFromMe: message.isFromMe!,
          hasReservedSize: reservedBox != null,
        ),
        stretch: !compact,
      );
    }

    // Not yet loaded, queued, or errored.
    return _reserve(
      reservedBox,
      NotLoadedContent(
        hideAttachments: false,
        isiOS: isiOS,
        compact: _useCompactPlaceholder(reservedBox, NotLoadedContent.fullVariantMinSize),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isInReply = ReplyScope.maybeOf(context) != null;
    final bool isPass = attachment.isPkPass;
    final bool showTail =
        !isInReply && !isPass && message.showTail(newerMessage) && controller.isTrailingMessagePart(part);

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
        final _ = state.resolvedFile.value;
        // ignore: unused_local_variable
        final _ = state.activeDownload.value;
        // ignore: unused_local_variable
        final _ = state.hasError.value;

        final hasError = state.hasError.value || message.error > 0;
        final hasPreview = state.resolvedFile.value != null ||
            (hasError && message.isFromMe == true && state.uploadPreviewFile.value != null);
        // Message popup has no tight parent frame — skip cover-fill expand.
        final inPopup = PopupScope.maybeOf(context) != null;
        final fill = widget.fill && !inPopup;
        // Parent ClipRRect owns collection corners; popup has no bubble tail so round all.
        final forceAllCornersRounded = inPopup;
        // Fill cards (and images / pkpasses) use transparent ink so media shows through.
        // Popup videos also need transparency — otherwise the square Ink peeks past ClipRRect.
        final transparentCard = hasPreview &&
            (widget.fill ||
                isPass ||
                attachment.mimeStart == "image" ||
                (inPopup && attachment.mimeStart == "video"));
        // Only meaningful before the file resolves; once it has, the image
        // itself defines the box.
        final reservedBox = hasPreview ? null : _reservedImageBox(context, isInReply, hideAttachments);
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
                  padding: _computePadding(
                    state,
                    hideAttachments,
                    showTail,
                    isInReply,
                    hasReservedBox: reservedBox != null,
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    // AnimatedSize loosens constraints, so content would render at its
                    // natural size — smaller than the parent frame. SizedBox.expand()
                    // snaps back to the max loosened constraints and forces tight
                    // dimensions all the way down to the content widget.
                    child: fill
                        ? SizedBox.expand(
                            child: SendingOpacityWrapper(
                              child: _buildContent(
                                state: state,
                                hideAttachments: hideAttachments,
                                showTail: showTail,
                                isInReply: isInReply,
                                isiOS: isiOS,
                                reservedBox: reservedBox,
                                fill: fill,
                                forceAllCornersRounded: forceAllCornersRounded,
                              ),
                            ),
                          )
                        : Center(
                            heightFactor: 1,
                            widthFactor: 1,
                            // SendingOpacityWrapper has its own Obx so isSending
                            // changes only rebuild the opacity layer, not this tree.
                            child: SendingOpacityWrapper(
                              child: _buildContent(
                                state: state,
                                hideAttachments: hideAttachments,
                                showTail: showTail,
                                isInReply: isInReply,
                                isiOS: isiOS,
                                reservedBox: reservedBox,
                                fill: fill,
                                forceAllCornersRounded: forceAllCornersRounded,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        // ColorFiltered is only for standalone selection tinting.
        // In fill mode the ColorFilter creates a saveLayer bounded by the messages
        // view repaint boundary; dstOver then fills every transparent pixel in that
        // large layer with tertiaryContainer (pink/purple flash while downloading).
        if (!transparentCard && !widget.fill) {
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
