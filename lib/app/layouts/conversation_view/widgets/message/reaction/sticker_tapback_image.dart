import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

/// The sticker a sticker tapback (type 2007) carries as its attachment, downloaded on first show.
class StickerTapbackImage extends StatefulWidget {
  const StickerTapbackImage({super.key, required this.reaction});
  final Message reaction;

  @override
  State<StickerTapbackImage> createState() => _StickerTapbackImageState();
}

class _StickerTapbackImageState extends State<StickerTapbackImage> {
  Attachment? _attachment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attachment = widget.reaction.dbAttachments.firstOrNull;
    if (attachment == null) return;
    if (await FileSystemEntity.type(attachment.path) == FileSystemEntityType.notFound) {
      AttachmentDownloader.startDownload(
        attachment,
        onComplete: (_) {
          if (mounted) setState(() => _attachment = attachment);
        },
      );
    } else if (mounted) {
      setState(() => _attachment = attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_attachment == null) return const SizedBox.shrink();
    return Image.file(File(_attachment!.path), gaplessPlayback: true, fit: BoxFit.contain);
  }
}
