import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class ImageViewer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;

  ImageViewer({
    Key? key,
    required this.file,
    required this.attachment,
    this.controller,
  }) : super(key: key);

  final ConversationViewController? controller;

  @override
  OptimizedState createState() => _ImageViewerState();
}

class _ImageViewerState extends OptimizedState<ImageViewer> with AutomaticKeepAliveClientMixin {
  Attachment get attachment => widget.attachment;
  PlatformFile get file => widget.file;
  ConversationViewController? get controller => widget.controller;

  Uint8List? data;

  @override
  void initState() {
    super.initState();
    if (attachment.guid!.contains("demo") || controller == null) return;
    data = controller!.imageData[attachment.guid];
    updateObx(() {
      initBytes();
    });
  }

  void initBytes() async {
    if (data != null) return;
    // Try to get the image data from the "cache"
    Uint8List? tmpData = controller!.imageData[attachment.guid];
    if (tmpData == null) {
      final completer = Completer<Uint8List>();
      controller!.queueImage(Tuple4(attachment, file, context, completer));
      final newData = await completer.future;
      if (newData.isEmpty) return;
      setState(() {
        data = newData;
      });
    } else {
      setState(() {
        data = tmpData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (attachment.guid!.contains("demo")) {
      return Image.asset(attachment.transferName!, fit: BoxFit.cover);
    }
    if (data == null) {
      return SizedBox(
        width: min((attachment.width?.toDouble() ?? ns.width(context) * 0.5), ns.width(context) * 0.5),
        height: min((attachment.height?.toDouble() ?? ns.width(context) * 0.5 / attachment.aspectRatio), ns.width(context) * 0.5 / attachment.aspectRatio),
      );
    }
    return Image.memory(
      data!,
      // prevents the image widget from "refreshing" when the provider changes
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      cacheWidth: (min((attachment.width ?? 0), ns.width(context) * 0.5) * Get.pixelRatio / 2).round().abs().nonZero,
      cacheHeight: (min((attachment.height ?? 0), ns.width(context) * 0.5 / attachment.aspectRatio) * Get.pixelRatio / 2).round().abs().nonZero,
      fit: BoxFit.cover,
      frameBuilder: (context, widget, frame, wasSyncLoaded) {
        return AnimatedCrossFade(
          crossFadeState: frame == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          alignment: Alignment.center,
          duration: const Duration(milliseconds: 150),
          secondChild: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 40,
              minWidth: 100,
            ),
            child: widget,
          ),
          firstChild: SizedBox(
            width: min((attachment.width?.toDouble() ?? ns.width(context) * 0.5), ns.width(context) * 0.5),
            height: min((attachment.height?.toDouble() ?? ns.width(context) * 0.5 / attachment.aspectRatio), ns.width(context) * 0.5 / attachment.aspectRatio),
          )
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
