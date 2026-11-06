import 'dart:math';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

class StickerHolder extends StatefulWidget {
  const StickerHolder({
    super.key,
    required this.stickerMessages,
    required this.controller,
    this.placed = false,
    this.hidden = false,
    this.isFromMe = false,
  });
  final Iterable<Message> stickerMessages;
  final ConversationViewController controller;

  /// Which side of the parent bubble its tail is on
  final bool isFromMe;

  /// Draw each sticker where its sender put it, relative to the parent bubble this fills
  final bool placed;

  /// Shrink the stickers out of view, e.g. while the message's details menu is open
  final bool hidden;

  /// Where a placed sticker draws (its rotated bounding box) relative to a [bubble] of that size
  static Rect placedRect(Attachment attachment, Size bubble, bool isFromMe) {
    final p = attachment.stickerPlacement!;
    double v(String key) => (p[key] as num).toDouble();
    // The bubble's body: not the gutter its tail draws in (see TailClipper), and inset a little on the other side
    final left = isFromMe ? _bodyInset : _tailGutter;
    final center = Offset(
      left + v('xScalar') * (bubble.width - _tailGutter - _bodyInset),
      v('yScalar') * bubble.height,
    );
    final scale = v('scale') / _stickerPixelRatio;
    final w = (attachment.width ?? _fallbackPixels) * scale;
    final h = (attachment.height ?? _fallbackPixels) * scale;
    final cosA = cos(v('rotation')).abs(), sinA = sin(v('rotation')).abs();
    return Rect.fromCenter(center: center, width: w * cosA + h * sinA, height: w * sinA + h * cosA);
  }

  /// Room [StickerSpace] adds around a [bubble] so it covers all of its placed [stickers]. On the column-edge side
  /// this moves the bubble inward (as Messages does), as far as the column allows.
  static EdgeInsets space(Iterable<Attachment> stickers, Size bubble, bool isFromMe, double columnWidth) {
    double left = 0, top = 0, right = 0, bottom = 0;
    for (final sticker in stickers) {
      final rect = placedRect(sticker, bubble, isFromMe);
      left = max(left, -rect.left);
      top = max(top, -rect.top);
      right = max(right, rect.right - bubble.width);
      bottom = max(bottom, rect.bottom - bubble.height);
    }
    final room = max(0.0, columnWidth - bubble.width);
    if (isFromMe) {
      right = min(right, room);
      left = min(left, room - right);
    } else {
      left = min(left, room);
      right = min(right, room - left);
    }
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  /// Size assumed for a sticker image whose dimensions the server didn't send
  static const int _fallbackPixels = 300;

  /// Pixels per point of a sticker image at scale 1, as Messages draws it on an iPhone
  static const double _stickerPixelRatio = 3;

  /// Width [TailClipper] keeps for the tail on that side of every bubble
  static const double _tailGutter = 12;

  /// Matched by eye against an iPhone's placement of the same stickers
  static const double _bodyInset = 4;

  @override
  State<StickerHolder> createState() => _StickerHolderState();
}

class _StickerHolderState extends State<StickerHolder> {
  Iterable<Message> get messages => widget.stickerMessages;

  final Map<String, Attachment> _stickerPaths = {};

  @override
  void initState() {
    super.initState();
    loadStickers();
  }

  @override
  void didUpdateWidget(StickerHolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    loadStickers();
  }

  Future<void> loadStickers() async {
    for (Message msg in messages) {
      for (Attachment attachment in msg.dbAttachments) {
        final pathName = attachment.path;
        if (_stickerPaths.containsKey(pathName)) continue;

        if (await FileSystemEntity.type(pathName) == FileSystemEntityType.notFound) {
          AttachmentDownloader.startDownload(attachment, onComplete: (_) {
            if (mounted) setState(() => _stickerPaths[pathName] = attachment);
          });
        } else {
          if (mounted) setState(() => _stickerPaths[pathName] = attachment);
        }
      }
    }
  }

  // Stickers never take input, so they can't block interaction with the message under them
  Widget _shrinkable(Widget child) => IgnorePointer(
        child: AnimatedScale(
          scale: widget.hidden ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_stickerPaths.isEmpty) return const SizedBox.shrink();
    if (widget.placed) return _buildPlaced();

    return _shrinkable(
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: NavigationSvc.width(context) * 0.6),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _stickerPaths.values
              .map(
                (attachment) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100, maxHeight: 100),
                  child: _image(attachment),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // The position is a fraction of the parent's size, so it's scaled by ours. `scale` applies to the sticker's own size.
  Widget _buildPlaced() {
    return LayoutBuilder(builder: (context, constraints) {
      final bubble = constraints.biggest;
      return Stack(
        clipBehavior: Clip.none,
        children: _stickerPaths.values.map((attachment) {
          final p = attachment.stickerPlacement!;
          final rect = StickerHolder.placedRect(attachment, bubble, widget.isFromMe);
          return Positioned(
            left: rect.center.dx,
            top: rect.center.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Transform.rotate(
                angle: (p['rotation'] as num).toDouble(),
                child: _shrinkable(
                  Transform.scale(
                    scale: (p['scale'] as num).toDouble(),
                    child: _image(attachment, FilterQuality.medium, StickerHolder._stickerPixelRatio),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _image(Attachment attachment, [FilterQuality quality = FilterQuality.none, double scale = 1]) => Image.file(
        File(attachment.path),
        scale: scale,
        gaplessPlayback: true,
        filterQuality: quality,
        // Pops in once it has loaded; a sticker already in the image cache is just drawn, so scrolling doesn't replay it
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedScale(
            scale: frame == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: child,
          );
        },
      );
}
