import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Compact square thumbnail for an image or video that is already on disk.
///
/// Never starts a download. Callers gate on [canShow] and keep their text
/// fallback (e.g. "1 Photo") until the file exists; once built, this always
/// occupies its square: a loader while the file is converted or thumbnailed,
/// the image once ready, or a broken-image marker if it can't be rendered.
class AttachmentPreview extends StatefulWidget {
  const AttachmentPreview({
    super.key,
    required this.attachment,
    required this.size,
    this.borderRadius,
    this.generateVideoThumbnail = false,
  });

  final Attachment attachment;
  final double size;
  final BorderRadius? borderRadius;

  /// When false, videos only render if a `.thumbnail` already exists on disk
  /// (conversation-list / pin grid). When true, ffmpeg may generate one.
  final bool generateVideoThumbnail;

  /// First image or video attachment, or null if the message has neither.
  static Attachment? firstPreviewableAttachment(Iterable<Attachment> attachments) {
    for (final attachment in attachments) {
      if (attachment.mimeStart == 'image' || attachment.mimeStart == 'video') {
        return attachment;
      }
    }
    return null;
  }

  /// Attachments for [message], re-querying the store when the in-memory
  /// [Message.dbAttachments] backlink is a stale empty cache.
  ///
  /// Chat-list latest messages often hit `getNotificationText()` before the
  /// attachment rows are linked. ObjectBox caches that empty ToMany, so later
  /// reads on the same instance stay empty even after the files exist on disk.
  static List<Attachment> attachmentsFor(Message message, {String? chatGuid}) {
    if (message.dbAttachments.isNotEmpty) {
      return List<Attachment>.from(message.dbAttachments);
    }

    final guid = chatGuid ?? message.chat.target?.guid;
    if (guid != null && message.guid != null) {
      final parts = maybeFindMessagesSvc(guid)?.getMessageStateIfExists(message.guid!)?.parts;
      if (parts != null) {
        final fromParts = [for (final part in parts) ...part.attachments];
        if (fromParts.isNotEmpty) return fromParts;
      }
    }

    if (kIsWeb) return const [];

    if (message.id != null) {
      final byMessage = (Database.attachments.query()
            ..link(Attachment_.message, Message_.id.equals(message.id!)))
          .build();
      try {
        final found = byMessage.find();
        if (found.isNotEmpty) return found;
      } finally {
        byMessage.close();
      }
    }

    final guids = <String>[
      for (final body in message.attributedBody)
        for (final run in body.runs)
          if (run.attributes?.attachmentGuid != null) run.attributes!.attachmentGuid!,
    ];
    if (guids.isEmpty) return const [];

    final byGuid = Database.attachments.query(Attachment_.guid.oneOf(guids)).build();
    try {
      return byGuid.find();
    } finally {
      byGuid.close();
    }
  }

  /// Whether [attachment] can render a compact preview without downloading.
  /// Videos need an on-disk `.thumbnail` unless [generateVideoThumbnail] is true.
  static bool canShow(
    Attachment attachment, {
    required bool generateVideoThumbnail,
  }) {
    if (kIsWeb) return false;
    if (_hidePreview()) return false;
    final mimeStart = attachment.mimeStart;
    if (mimeStart != 'image' && mimeStart != 'video') return false;
    if (!AttachmentsSvc.hasLocalFile(attachment)) return false;
    if (mimeStart == 'video') {
      if (AttachmentsSvc.getCachedVideoThumbnailSync(attachment.path) != null) return true;
      if (!generateVideoThumbnail) return false;
      return File(attachment.path).existsSync();
    }
    return true;
  }

  static bool _hidePreview() {
    // Read each Rx unconditionally so Obx subscriptions don't depend on short-circuiting.
    final redacted = SettingsSvc.settings.redactedMode.value;
    final hideAttachments = SettingsSvc.settings.hideAttachments.value;
    final highPerf = SettingsSvc.settings.highPerfMode.value;
    return (redacted && hideAttachments) || highPerf;
  }

  @override
  State<AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<AttachmentPreview> with ThemeHelpers {
  String? _imagePath;
  bool _isVideo = false;
  int _loadToken = 0;

  /// True while a HEIC/TIFF conversion or a video thumbnail is being produced for the
  /// current attachment. The file is on disk, so this is "downloaded, not yet processed":
  /// a loader is shown rather than nothing. Cleared on completion, success or not.
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _resolve(rebuild: false);
  }

  @override
  void didUpdateWidget(AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.guid != widget.attachment.guid ||
        oldWidget.generateVideoThumbnail != widget.generateVideoThumbnail) {
      _resolve(rebuild: true);
    }
  }

  String? _existingImagePath(Attachment attachment) {
    if (File(attachment.path).existsSync()) return attachment.path;
    if (File(attachment.convertedPath).existsSync()) return attachment.convertedPath;
    if (File(attachment.legacyConvertedPath).existsSync()) return attachment.legacyConvertedPath;
    return null;
  }

  void _resolve({required bool rebuild}) {
    _loadToken++;
    final token = _loadToken;
    _imagePath = null;
    _processing = false;
    _isVideo = widget.attachment.mimeStart == 'video';

    if (kIsWeb || !AttachmentsSvc.hasLocalFile(widget.attachment)) {
      if (rebuild && mounted) setState(() {});
      return;
    }

    if (widget.attachment.mimeStart == 'image') {
      final mimeType = widget.attachment.mimeType ?? '';
      if (mimeType.contains('image/hei') || mimeType.contains('image/tif')) {
        _processing = true;
        _applyWhenDone(token, AttachmentsSvc.ensureImageCompatibility(widget.attachment));
      } else {
        _imagePath = _existingImagePath(widget.attachment);
      }
    } else if (_isVideo) {
      final cached = AttachmentsSvc.getCachedVideoThumbnailSync(widget.attachment.path);
      if (cached != null) {
        _imagePath = cached;
      } else if (widget.generateVideoThumbnail && File(widget.attachment.path).existsSync()) {
        _processing = true;
        _applyWhenDone(token, AttachmentsSvc.getVideoThumbnail(widget.attachment.path));
      }
    }

    if (rebuild && mounted) setState(() {});
  }

  /// Stores the processed path once [pending] completes, unless the widget was disposed or
  /// re-resolved for another attachment in the meantime. A failure still ends the loader.
  void _applyWhenDone(int token, Future<String?> pending) {
    pending.then<String?>((path) => path, onError: (Object e, StackTrace s) {
      Logger.warn('Failed to prepare attachment preview', error: e, trace: s, tag: 'AttachmentPreview');
      return null;
    }).then((path) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _imagePath = path;
        _processing = false;
      });
    });
  }

  /// The thumbnail-sized tile the loader and the unavailable marker sit in. Same look as the
  /// message view's image placeholder, so the pin grid reads as a miniature of the thread.
  Widget _tile(BuildContext context, BorderRadius radius, Widget child) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  double get _glyphSize => (widget.size * 0.4).clamp(10.0, 20.0);

  /// Shown while the file is being converted or thumbnailed.
  Widget _loader(BuildContext context, BorderRadius radius) {
    return _tile(
      context,
      radius,
      SizedBox(
        width: _glyphSize,
        height: _glyphSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.outline),
        ),
      ),
    );
  }

  /// Shown when the file is on disk but cannot be rendered (conversion or thumbnailing
  /// failed, or the decoder rejected it). The thread's `MediaUnavailablePlaceholder` is too
  /// large for a pin thumbnail, so this is just its icon, and it stays compact rather than
  /// falling back to the wider text label.
  Widget _unavailable(BuildContext context, BorderRadius radius) {
    return _tile(
      context,
      radius,
      Icon(
        iOS ? CupertinoIcons.photo : Icons.broken_image_outlined,
        size: _glyphSize,
        color: context.theme.colorScheme.outline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (AttachmentPreview._hidePreview()) {
        return const SizedBox.shrink();
      }
      final radius = widget.borderRadius ?? BorderRadius.circular(widget.size * 0.15);
      final path = _imagePath;
      if (path == null) {
        // The parent only builds this once the file is on disk, so a missing path after
        // processing means the file can't be shown, not that it hasn't arrived.
        return _processing ? _loader(context, radius) : _unavailable(context, radius);
      }

      final cacheWidth = (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 512);

      return IgnorePointer(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: widget.size,
                  height: widget.size,
                  gaplessPlayback: true,
                  cacheWidth: cacheWidth,
                  // The decode itself is async too; keep the loader up until the first frame.
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                      wasSynchronouslyLoaded || frame != null ? child : _loader(context, radius),
                  errorBuilder: (context, _, _) => _unavailable(context, radius),
                ),
                if (_isVideo)
                  Center(
                    child: Icon(
                      iOS ? CupertinoIcons.play_circle_fill : Icons.play_circle_filled,
                      color: Colors.white,
                      size: (widget.size * 0.42).clamp(10.0, 24.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
