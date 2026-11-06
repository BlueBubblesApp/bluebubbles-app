import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// A small image attachment (sticker tapback or inline Genmoji), downloaded on first show when auto-download allows,
/// or on a tap otherwise.
class StickerTapbackImage extends StatefulWidget {
  const StickerTapbackImage({super.key, required this.attachment});
  final Attachment? attachment;

  @override
  State<StickerTapbackImage> createState() => _StickerTapbackImageState();
}

class _StickerTapbackImageState extends State<StickerTapbackImage> {
  String? _path;
  String? _loadedGuid;
  bool _failed = false;
  // Not on disk, and auto-download is off (or waiting for wifi): a tap downloads it
  bool _awaitingTap = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StickerTapbackImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The attachment can be linked after the first build
    _load();
  }

  Future<void> _load() async {
    final attachment = widget.attachment;
    if (attachment == null || attachment.guid == _loadedGuid) return;
    _loadedGuid = attachment.guid;
    _awaitingTap = false;
    if (await FileSystemEntity.type(attachment.path) == FileSystemEntityType.notFound) {
      if (await AttachmentsSvc.canAutoDownload(requestStoragePermission: false)) {
        _download(attachment);
      } else if (mounted) {
        setState(() => _awaitingTap = true);
      }
    } else {
      await _show(attachment);
    }
  }

  void _download(Attachment attachment) {
    AttachmentDownloader.startDownload(
      attachment,
      onComplete: (_) => _show(attachment),
      onError: () {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  // Stickers are HEIC, which only iOS and macOS decode natively
  Future<void> _show(Attachment attachment) async {
    final path = await AttachmentsSvc.ensureImageCompatibility(attachment);
    if (mounted) setState(() => path == null ? _failed = true : _path = path);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.broken_image_outlined, color: context.theme.colorScheme.outline);
    if (_failed) return fallback;
    if (_awaitingTap && widget.attachment != null) {
      return GestureDetector(
        onTap: () {
          setState(() => _awaitingTap = false);
          _download(widget.attachment!);
        },
        child: FittedBox(child: Icon(Icons.download_outlined, color: context.theme.colorScheme.outline)),
      );
    }
    if (_path == null) return const SizedBox.shrink();
    return Image.file(
      File(_path!),
      gaplessPlayback: true,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
