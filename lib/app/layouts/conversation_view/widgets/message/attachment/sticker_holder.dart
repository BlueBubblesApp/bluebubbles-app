import 'dart:async';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

class StickerHolder extends StatefulWidget {
  StickerHolder({super.key, required this.stickerMessages, required this.controller});
  final Iterable<Message> stickerMessages;
  final ConversationViewController controller;

  @override
  State<StickerHolder> createState() => _StickerHolderState();
}

class _StickerHolderState extends OptimizedState<StickerHolder> with AutomaticKeepAliveClientMixin {
  Iterable<Message> get messages => widget.stickerMessages;
  ConversationViewController get controller => widget.controller;
  
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    updateObx(() {
      loadStickers();
    });
  }

  Future<void> loadStickers() async {
    for (Message msg in messages) {
      for (Attachment? attachment in msg.attachments) {
        // If we've already loaded it, don't try again
        if (controller.stickerData.keys.contains(attachment!.guid)) continue;

        final pathName = attachment.path;
        if (await FileSystemEntity.type(pathName) == FileSystemEntityType.notFound) {
          attachmentDownloader.startDownload(attachment, onComplete: (_) async {
            await checkImage(msg, attachment);
          });
        } else {
          await checkImage(msg, attachment);
        }
      }
    }
  }

  Future<void> checkImage(Message message, Attachment attachment) async {
    final pathName = attachment.path;
    // Check via the image package to make sure this is a valid, render-able image
    final image = await compute(decodeIsolate, PlatformFile(
        path: pathName,
        name: attachment.transferName!,
        bytes: attachment.bytes,
        size: attachment.totalBytes ?? 0,
      ),
    );
    if (image != null) {
      final bytes = await File(pathName).readAsBytes();
      controller.stickerData[message.guid!] = {
        attachment.guid!: bytes
      };
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final guids = messages.map((e) => e.guid!);
    final stickers = controller.stickerData.entries.where((element) => guids.contains(element.key)).map((e) => e.value);
    if (stickers.isEmpty) return const SizedBox.shrink();

    final data = stickers.map((e) => e.values).expand((element) => element);
    return GestureDetector(
      onTap: () {
        setState(() {
          _visible = !_visible;
        });
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _visible ? 1.0 : 0.25,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ns.width(context) * 0.6,
            maxHeight: 100,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: ts.scrollPhysics,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: data.map((e) => Image.memory(
                e,
                gaplessPlayback: true,
                cacheHeight: 200,
                filterQuality: FilterQuality.none,
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
