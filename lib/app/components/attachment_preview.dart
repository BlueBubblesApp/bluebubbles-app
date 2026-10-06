import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Compact square thumbnail for an image or video that is already on disk.
///
/// Never starts a download. Renders [SizedBox.shrink] when nothing can be shown
/// so the parent can keep its text fallback (e.g. "1 Photo").
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
    if (_hidePreview(generateVideoThumbnail: generateVideoThumbnail)) return false;
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

  static bool _hidePreview({required bool generateVideoThumbnail}) {
    // Read each Rx unconditionally so Obx subscriptions don't depend on short-circuiting.
    final redacted = SettingsSvc.settings.redactedMode.value;
    final hideAttachments = SettingsSvc.settings.hideAttachments.value;
    final highPerf = SettingsSvc.settings.highPerfMode.value;
    // High Performance Mode skips decoding on the conversation list (pin grid),
    // where [generateVideoThumbnail] is false. In-conversation surfaces may still
    // generate a video thumb.
    return (redacted && hideAttachments) || (!generateVideoThumbnail && highPerf);
  }

  @override
  State<AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<AttachmentPreview> with ThemeHelpers {
  String? _imagePath;
  bool _isVideo = false;
  int _loadToken = 0;

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
    _isVideo = widget.attachment.mimeStart == 'video';

    if (kIsWeb || !AttachmentsSvc.hasLocalFile(widget.attachment)) {
      if (rebuild && mounted) setState(() {});
      return;
    }

    if (widget.attachment.mimeStart == 'image') {
      final mimeType = widget.attachment.mimeType ?? '';
      if (mimeType.contains('image/hei') || mimeType.contains('image/tif')) {
        AttachmentsSvc.ensureImageCompatibility(widget.attachment).then((path) {
          if (!mounted || token != _loadToken) return;
          setState(() => _imagePath = path);
        });
      } else {
        _imagePath = _existingImagePath(widget.attachment);
      }
    } else if (_isVideo) {
      final cached = AttachmentsSvc.getCachedVideoThumbnailSync(widget.attachment.path);
      if (cached != null) {
        _imagePath = cached;
      } else if (widget.generateVideoThumbnail && File(widget.attachment.path).existsSync()) {
        AttachmentsSvc.getVideoThumbnail(widget.attachment.path).then((path) {
          if (!mounted || token != _loadToken) return;
          setState(() => _imagePath = path);
        });
      }
    }

    if (rebuild && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (AttachmentPreview._hidePreview(generateVideoThumbnail: widget.generateVideoThumbnail)) {
        return const SizedBox.shrink();
      }
      final path = _imagePath;
      if (path == null) {
        return const SizedBox.shrink();
      }

      final cacheWidth = (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 512);
      final radius = widget.borderRadius ?? BorderRadius.circular(widget.size * 0.15);

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
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
