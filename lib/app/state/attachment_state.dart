import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/network/downloads_service.dart';
import 'package:get/get.dart';

/// The lifecycle state of an attachment's transfer.
///
/// Covers both outgoing uploads and incoming downloads — call sites use
/// [AttachmentState.transferState] to decide which UI to render rather than
/// inspecting the raw [Attachment] flags or probing [AttachmentDownloadController]
/// directly.
enum AttachmentTransferState {
  /// No transfer is in progress.  Check [AttachmentState.isDownloaded] to
  /// determine whether the file is already available on disk.
  idle,

  /// The outgoing attachment is being uploaded to the server.
  uploading,

  /// The attachment has been queued for automatic download but has not yet
  /// begun transferring.
  queued,

  /// The attachment is actively being downloaded from the server.
  downloading,

  /// The download has finished and post-processing (EXIF extraction, format
  /// conversion, etc.) is in progress.
  processing,

  /// Transfer is complete — either the upload was confirmed by the server or
  /// the download + processing finished.
  complete,

  /// Transfer failed with an unrecoverable error.
  error,
}

/// State wrapper for [Attachment] that provides granular reactivity for UI
/// components.
///
/// Mirrors the UI-relevant fields of the underlying [Attachment] entity as
/// [Rx*] observables so widgets can subscribe only to the properties they need.
/// Upload and download progress are exposed as separate observables for
/// fine-grained progress indicators.
///
/// ## Ownership
/// Each [AttachmentState] is owned by its parent [MessageState] and stored in
/// [MessageState.attachmentStates], keyed by attachment GUID.  Access it via
/// [MessagesService] → [MessageState.getAttachmentState].
///
/// ## Mutation rules
/// Only call [*Internal()] methods from [MessagesService],
/// [OutgoingMessageHandler], or [IncomingMessageHandler].  UI code must never
/// write to these observables directly, and should route updates through
/// [MessagesService] instead.
class AttachmentState {
  /// The underlying attachment object.
  final Attachment attachment;

  // ── Core fields ────────────────────────────────────────────────────────────

  /// Attachment GUID.  Transitions from a temp GUID to a real GUID after a
  /// successful upload (temp → real GUID swap).
  final RxnString guid;

  final RxnString mimeType;
  final RxnString transferName;
  final RxnInt totalBytes;

  /// RAW (decode-native, pre-rotation) pixel dimensions, mirroring
  /// [Attachment.width] / [Attachment.height].
  ///
  /// These are **not** the size to lay an image out at. For that, use
  /// [Attachment.displayWidth] / [Attachment.displayHeight], which apply the
  /// EXIF orientation swap.
  final RxnInt width;
  final RxnInt height;
  final RxBool hasLivePhoto;
  final RxnBool isOutgoing;

  /// Whether the attachment file is present and ready on local disk.
  final RxBool isDownloaded;

  // ── Transfer state ─────────────────────────────────────────────────────────

  /// High-level lifecycle state of the attachment transfer.
  final Rx<AttachmentTransferState> transferState;

  /// Upload progress in the range [0.0, 1.0]; `null` when not uploading.
  final RxnDouble uploadProgress;

  /// Download progress in the range [0.0, 1.0]; `null` when not downloading.
  final RxnDouble downloadProgress;

  // ── Resolved content ──────────────────────────────────────────────────────

  /// The [PlatformFile] once the attachment is available locally — set when
  /// [MessagesService] loads existing content or a download completes.
  final Rxn<PlatformFile> resolvedFile;

  /// The active [AttachmentDownloadController] while a download is in flight.
  /// Cleared when the download finishes, errors, or is retried.
  final Rxn<AttachmentDownloadController> activeDownload;

  /// A locally-accessible [PlatformFile] shown at reduced opacity beneath the
  /// upload progress indicator.  `null` when the file is not accessible during
  /// the upload (e.g., cloud picks).
  final Rxn<PlatformFile> uploadPreviewFile;

  // ── Derived states ─────────────────────────────────────────────────────────

  /// `true` while [guid] starts with `temp` AND [transferState] is
  /// [AttachmentTransferState.uploading].
  final RxBool isSending;

  /// `true` when [transferState] is [AttachmentTransferState.error].
  final RxBool hasError;

  // ── Internal lifecycle ─────────────────────────────────────────────────────

  /// Worker that forwards [AttachmentDownloadController.progress] to
  /// [downloadProgress].  Disposed automatically when the transfer state
  /// leaves the downloading states.
  Worker? _progressWorker;

  /// Worker that fires the file-completion callback once
  /// [AttachmentDownloadController.file] becomes non-null.
  Worker? _fileWorker;

  // ── Constructor ────────────────────────────────────────────────────────────

  AttachmentState(this.attachment)
      : guid = RxnString(attachment.guid),
        mimeType = RxnString(attachment.mimeType),
        transferName = RxnString(attachment.transferName),
        totalBytes = RxnInt(attachment.totalBytes),
        width = RxnInt(attachment.width),
        height = RxnInt(attachment.height),
        hasLivePhoto = attachment.hasLivePhoto.obs,
        isOutgoing = RxnBool(attachment.isOutgoing),
        isDownloaded = attachment.isDownloaded.obs,
        transferState = Rx<AttachmentTransferState>(
          attachment.isDownloaded ? AttachmentTransferState.complete : AttachmentTransferState.idle,
        ),
        uploadProgress = RxnDouble(),
        downloadProgress = RxnDouble(),
        resolvedFile = Rxn<PlatformFile>(),
        activeDownload = Rxn<AttachmentDownloadController>(),
        uploadPreviewFile = Rxn<PlatformFile>(),
        // Previously had a condition for !isDownloaded. However, isDownloaded is set to true
        // immediately for outgoing attachments to reflect that the file is available locally,
        // even though the upload is still in progress.
        isSending = (attachment.guid?.startsWith('temp') ?? false).obs,
        hasError = false.obs;

  // ── Internal state update methods ──────────────────────────────────────────
  // Only [MessagesService], [OutgoingMessageHandler], and
  // [IncomingMessageHandler] may call these.

  /// Updates the attachment GUID.  Called during the temp → real GUID swap
  /// after a successful upload.
  void updateGuidInternal(String? value) {
    if (guid.value != value) {
      guid.value = value;
      attachment.guid = value;
      // Refresh derived isSending: still uploading but no longer a temp GUID
      isSending.value =
          (value?.startsWith('temp') ?? false) && transferState.value == AttachmentTransferState.uploading;
    }
  }

  /// Updates the MIME type (e.g., after the server resolves the format).
  void updateMimeTypeInternal(String? value) {
    if (mimeType.value != value) {
      mimeType.value = value;
      attachment.mimeType = value;
    }
  }

  /// Updates the transfer name (filename).
  void updateTransferNameInternal(String? value) {
    if (transferName.value != value) {
      transferName.value = value;
      attachment.transferName = value;
    }
  }

  /// Updates image dimensions simultaneously to minimise rebuilds.
  void updateDimensionsInternal(int? newWidth, int? newHeight) {
    if (width.value != newWidth) {
      width.value = newWidth;
      attachment.width = newWidth;
    }
    if (height.value != newHeight) {
      height.value = newHeight;
      attachment.height = newHeight;
    }
  }

  /// Marks whether the attachment file is available on disk.
  void updateIsDownloadedInternal(bool value) {
    if (isDownloaded.value != value) {
      isDownloaded.value = value;
      attachment.isDownloaded = value;
    }
  }

  /// Transitions to [state], clearing stale progress values as appropriate,
  /// and updates the derived [isSending] and [hasError] flags.
  void updateTransferStateInternal(AttachmentTransferState state, {double? progress}) {
    if (transferState.value != state) {
      transferState.value = state;
    }

    switch (state) {
      case AttachmentTransferState.uploading:
        isSending.value = guid.value?.startsWith('temp') ?? false;
        hasError.value = false;
        uploadProgress.value = progress ?? 0.0;
        downloadProgress.value = null;
        _progressWorker?.dispose();
        _progressWorker = null;
      case AttachmentTransferState.queued:
        isSending.value = false;
        hasError.value = false;
        uploadProgress.value = null;
        downloadProgress.value = 0.0;
        _progressWorker?.dispose();
        _progressWorker = null;
      case AttachmentTransferState.downloading:
        isSending.value = false;
        hasError.value = false;
        uploadProgress.value = null;
        downloadProgress.value = progress ?? 0.0;
      case AttachmentTransferState.processing:
        isSending.value = false;
        hasError.value = false;
        downloadProgress.value = 1.0;
      case AttachmentTransferState.complete:
        isSending.value = false;
        hasError.value = false;
        uploadProgress.value = null;
        downloadProgress.value = null;
        _disposeTransferWorkers();
      case AttachmentTransferState.error:
        isSending.value = false;
        hasError.value = true;
        _disposeTransferWorkers();
      case AttachmentTransferState.idle:
        isSending.value = false;
        hasError.value = false;
        uploadProgress.value = null;
        downloadProgress.value = null;
    }
  }

  /// Tears down the progress and file workers — unless a download is still
  /// attached, in which case they are the live wiring for it and must survive.
  ///
  /// [updateFromAttachment] promotes to [AttachmentTransferState.complete] as
  /// soon as a refreshed [Attachment] reports `isDownloaded`, and
  /// [MessageState._syncAttachmentStates] can deliver that in the middle of an
  /// in-flight download. Disposing [_fileWorker] there drops the only
  /// completion signal some download paths have — [MessagesService.redownloadAttachment]
  /// wires up no `completeFuncs` callback at all — leaving [resolvedFile] null
  /// while [activeDownload] stays set, so the UI is stuck on the downloading
  /// widget until the message is disposed and rebuilt.
  ///
  /// Every legitimate completion path (`_onAttachmentDownloadComplete`,
  /// `notifyAttachmentDownloadComplete`, `notifyAttachmentSendComplete`) clears
  /// [activeDownload] before transitioning, so this still disposes there.
  /// [dispose] tears them down unconditionally regardless.
  void _disposeTransferWorkers() {
    if (activeDownload.value != null) return;
    _progressWorker?.dispose();
    _progressWorker = null;
    _fileWorker?.dispose();
    _fileWorker = null;
  }

  /// Sets [activeDownload] to [ctrl].
  void updateActiveDownloadInternal(AttachmentDownloadController? ctrl) {
    if (activeDownload.value != ctrl) activeDownload.value = ctrl;
  }

  /// Sets [resolvedFile] once the attachment is available on disk.
  void updateResolvedFileInternal(PlatformFile? file) {
    if (resolvedFile.value != file) resolvedFile.value = file;
  }

  /// Sets [uploadPreviewFile] — the file accessible for preview during upload.
  void updateUploadPreviewFileInternal(PlatformFile? file) {
    if (uploadPreviewFile.value != file) uploadPreviewFile.value = file;
  }

  /// Synchronises [downloadProgress] AND [resolvedFile] with [controller] for
  /// the duration of the active download.
  ///
  /// Unlike the old [syncDownloadProgressInternal], this also sets up a
  /// [_fileWorker] that fires [onFileComplete] as soon as
  /// [controller.file] becomes non-null (or immediately if it already is).
  /// Both workers are disposed automatically when a new call is made or when
  /// the transfer transitions away from downloading states.
  void syncDownloadInternal(
    AttachmentDownloadController controller,
    void Function(PlatformFile) onFileComplete,
  ) {
    _progressWorker?.dispose();
    _fileWorker?.dispose();

    // If the download already finished, fire immediately and skip workers.
    if (controller.file.value != null) {
      onFileComplete(controller.file.value!);
      return;
    }

    _progressWorker = ever(controller.progress, (num? value) {
      if (value != null) {
        downloadProgress.value = value.toDouble().clamp(0.0, 1.0);
      }
    });

    _fileWorker = ever(controller.file, (PlatformFile? file) {
      if (file != null) {
        _fileWorker?.dispose();
        _fileWorker = null;
        onFileComplete(file);
      }
    });
  }

  /// Updates upload progress.  Only meaningful while
  /// [transferState] is [AttachmentTransferState.uploading].
  void updateUploadProgressInternal(double value) {
    uploadProgress.value = value.clamp(0.0, 1.0);
  }

  /// Performs a bulk update from a revised [Attachment] object.
  ///
  /// Updates metadata fields (GUID, MIME type, dimensions, etc.) without
  /// resetting an active transfer state — so an attachment that is currently
  /// uploading stays in the [AttachmentTransferState.uploading] state even
  /// after this method is called.
  void updateFromAttachment(Attachment updated) {
    updateGuidInternal(updated.guid);
    updateMimeTypeInternal(updated.mimeType);
    updateTransferNameInternal(updated.transferName);

    if (totalBytes.value != updated.totalBytes) {
      totalBytes.value = updated.totalBytes;
      attachment.totalBytes = updated.totalBytes;
    }

    updateDimensionsInternal(updated.width, updated.height);

    if (hasLivePhoto.value != updated.hasLivePhoto) {
      hasLivePhoto.value = updated.hasLivePhoto;
      attachment.hasLivePhoto = updated.hasLivePhoto;
    }

    if (isOutgoing.value != updated.isOutgoing) {
      isOutgoing.value = updated.isOutgoing;
      attachment.isOutgoing = updated.isOutgoing;
    }

    // Only promote to complete if the file is now on disk and we weren't
    // already in a terminal state.
    if (updated.isDownloaded && !isDownloaded.value) {
      updateIsDownloadedInternal(true);
      // Don't overwrite a user-visible error state — only transitions from
      // non-terminal states to complete.
      if (transferState.value != AttachmentTransferState.error) {
        updateTransferStateInternal(AttachmentTransferState.complete);
      }
    }
  }

  /// Resets this attachment state in-place for a retry send.
  ///
  /// Updates the GUID observable to [newGuid] and immediately transitions to
  /// [AttachmentTransferState.uploading] so that any existing [Obx] subscriptions
  /// (which hold a direct reference to this object) react to the change and
  /// show the upload-progress UI without waiting for [notifyAttachmentUploadStarted].
  ///
  /// Called exclusively from [MessagesService.retryFailedMessage].
  void resetForRetryInternal(String newGuid) {
    if (guid.value != newGuid) {
      guid.value = newGuid;
      attachment.guid = newGuid;
    }
    // Clear resolved file — this attachment has not yet been confirmed by the server.
    if (resolvedFile.value != null) resolvedFile.value = null;
    // Transition directly to uploading — sets isSending=true, hasError=false,
    // uploadProgress=0.0, clears download progress workers.
    updateTransferStateInternal(AttachmentTransferState.uploading);
  }

  /// Disposes internal workers.  Called by [MessageState] when the owning
  /// message is removed.
  void dispose() {
    _progressWorker?.dispose();
    _progressWorker = null;
    _fileWorker?.dispose();
    _fileWorker = null;
  }
}
