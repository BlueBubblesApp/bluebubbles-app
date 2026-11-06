import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// The sticker a sticker tapback (type 2007) carries as its attachment, downloaded on first show.
class StickerTapbackImage extends StatefulWidget {
  const StickerTapbackImage({super.key, required this.reaction});
  final Message reaction;

  @override
  State<StickerTapbackImage> createState() => _StickerTapbackImageState();
}

class _StickerTapbackImageState extends State<StickerTapbackImage> {
  String? _path;
  String? _loadedGuid;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StickerTapbackImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The reaction can arrive before its attachment is linked
    _load();
  }

  Future<void> _load() async {
    final attachment = widget.reaction.dbAttachments.firstOrNull;
    if (attachment == null || attachment.guid == _loadedGuid) return;
    _loadedGuid = attachment.guid;
    if (await FileSystemEntity.type(attachment.path) == FileSystemEntityType.notFound) {
      AttachmentDownloader.startDownload(
        attachment,
        onComplete: (_) => _show(attachment),
        onError: () {
          if (mounted) setState(() => _failed = true);
        },
      );
    } else {
      await _show(attachment);
    }
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
    if (_path == null) return const SizedBox.shrink();
    return Image.file(
      File(_path!),
      gaplessPlayback: true,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
