import 'dart:typed_data';

import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class GamePigeon extends StatefulWidget {
  final iMessageAppData data;

  /// The picture to show instead of the message's attachment, for a game that isn't a message yet
  final Uint8List? image;

  const GamePigeon({
    super.key,
    required this.data,
    this.image,
  });

  @override
  State<StatefulWidget> createState() => _GamePigeonState();
}

class _GamePigeonState extends State<GamePigeon> with AutomaticKeepAliveClientMixin {
  iMessageAppData get data => widget.data;
  dynamic get file => File(content.path!);
  dynamic content;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.image != null) content = PlatformFile(name: "game.jpg", size: widget.image!.length, bytes: widget.image);
    // A turn still uploading comes back with its progress
    if (content is AttachmentWithProgress) content = (content as AttachmentWithProgress).file;
    if (content == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final attachment = MessageStateScope.messageOf(context).dbAttachments.firstOrNull;
        if (attachment != null) {
          content = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (file) {
            if (mounted) {
              setState(() {
                content = file;
              });
            }
          });
          if (content != null && mounted) setState(() {});
        }
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (content is PlatformFile && content.bytes != null)
          Image.memory(
            content.bytes!,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        if (content is PlatformFile && content.bytes == null && content.path != null)
          Image.file(
            file,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, object, stacktrace) => Center(
              heightFactor: 1,
              child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
            ),
          ),
        if (data.userInfo?.caption != null)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Center(
              child: Text(
                data.userInfo!.caption!.toUpperCase(),
                style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Obx(() => !OpenPigeon.installed.value && OpenPigeon.supported
            ? const Center(child: TextButton(onPressed: OpenPigeon.openStore, child: Text("Play with OpenPigeon")))
            : const SizedBox.shrink()),
      ],
    );
  }
}
