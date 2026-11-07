import 'dart:math';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show StickerPlacement;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

/// A placed sticker as [StickerHolder.space] lays it out: where its sender put it, and its image's size in pixels
@immutable
class PlacedSticker {
  const PlacedSticker(this.placement, this.pixels);

  final StickerPlacement placement;
  final Size pixels;

  /// [attachment] as placed, or null when it has no placement. [decoded] is its image's size once that has loaded,
  /// which wins over the attachment's dimensions: it's what draws.
  static PlacedSticker? of(Attachment attachment, [Size? decoded]) {
    final placement = StickerPlacement.tryParse(attachment.stickerPlacement);
    if (placement == null) return null;
    return PlacedSticker(placement, decoded ?? Size(_known(attachment.width), _known(attachment.height)));
  }

  // The server sends 0 for dimensions it didn't read, and sync doesn't ask for them
  static double _known(int? pixels) =>
      pixels != null && pixels > 0 ? pixels.toDouble() : StickerHolder._fallbackPixels;

  @override
  bool operator ==(Object other) => other is PlacedSticker && other.placement == placement && other.pixels == pixels;

  @override
  int get hashCode => Object.hash(placement, pixels);
}

class StickerHolder extends StatefulWidget {
  const StickerHolder({
    super.key,
    required this.stickerMessages,
    required this.controller,
    this.placed = false,
    this.hidden = false,
    this.isFromMe = false,
    this.tailGutter = true,
  });
  final Iterable<Message> stickerMessages;
  final ConversationViewController controller;

  /// Which side of the parent bubble its tail is on
  final bool isFromMe;

  /// Draw each sticker where its sender put it, relative to the parent bubble this fills
  final bool placed;

  /// Shrink the stickers out of view, e.g. while the message's details menu is open
  final bool hidden;

  /// Whether the parent bubble keeps a gutter for its tail. Media collections aren't clipped by [TailClipper], so
  /// they don't.
  final bool tailGutter;

  /// Where a sticker placed at [p] has its center, relative to a [bubble] of that size
  static Offset placedCenter(StickerPlacement p, Size bubble, bool isFromMe, bool tailGutter) {
    // The bubble's body: not the gutter its tail draws in (see TailClipper), and inset a little on the other side
    final gutter = tailGutter ? _tailGutter : 0.0;
    final left = isFromMe ? _bodyInset : gutter;
    return Offset(left + p.xScalar * (bubble.width - gutter - _bodyInset), p.yScalar * bubble.height);
  }

  /// Where a placed sticker draws (its rotated bounding box) relative to a [bubble] of that size
  static Rect placedRect(PlacedSticker sticker, Size bubble, bool isFromMe, bool tailGutter) {
    final p = sticker.placement;
    final scale = p.scale / _stickerPixelRatio;
    final w = sticker.pixels.width * scale;
    final h = sticker.pixels.height * scale;
    final cosA = cos(p.rotation).abs(), sinA = sin(p.rotation).abs();
    return Rect.fromCenter(
      center: placedCenter(p, bubble, isFromMe, tailGutter),
      width: w * cosA + h * sinA,
      height: w * sinA + h * cosA,
    );
  }

  /// Room [StickerSpace] adds around a [bubble] so it covers all of its placed [stickers]. On the column-edge side
  /// this moves the bubble inward (as Messages does), as far as the column allows.
  static EdgeInsets space(
      Iterable<PlacedSticker> stickers, Size bubble, bool isFromMe, bool tailGutter, double columnWidth) {
    double left = 0, top = 0, right = 0, bottom = 0;
    for (final sticker in stickers) {
      final rect = placedRect(sticker, bubble, isFromMe, tailGutter);
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
  static const double _fallbackPixels = 300;

  /// Pixels per point of a sticker image at scale 1, as Messages draws it on an iPhone
  static const double _stickerPixelRatio = 3;

  /// Kept clear on the tail side of a bubble: [TailClipper] draws its tail in the outer 10, and 2 more matched by eye
  /// against an iPhone's placement of the same stickers
  static const double _tailGutter = 12;

  /// Matched by eye against an iPhone's placement of the same stickers
  static const double _bodyInset = 4;

  @override
  State<StickerHolder> createState() => _StickerHolderState();
}

class _StickerHolderState extends State<StickerHolder> {
  /// This holder's sticker attachments, in the order their messages were sent, so later stickers draw on top
  List<Attachment> _stickers = const [];

  /// Guids of the stickers whose image is on disk, ready to draw
  final Set<String> _ready = {};

  /// Guids being downloaded, so an update doesn't add another callback to the same download
  final Set<String> _downloading = {};

  /// Where [_measure] reports each placed sticker's decoded size, for [StickerSpace]
  MessageState? _state;

  /// Guids of the placed stickers whose image size is being or has been read
  final Set<String> _measured = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = MessageStateScope.maybeOf(context);
  }

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
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final messages = widget.stickerMessages.toList()
      ..sort((a, b) {
        final byDate = (a.dateCreated ?? epoch).compareTo(b.dateCreated ?? epoch);
        return byDate != 0 ? byDate : (a.id ?? 0).compareTo(b.id ?? 0);
      });
    // Rebuilt from the current messages each time, so a sticker that left (unsent, or moved to the other holder once
    // its placement arrived) stops drawing here
    _stickers = [
      for (final message in messages)
        for (final attachment in message.dbAttachments)
          if (attachment.guid != null &&
              (!widget.placed || StickerPlacement.tryParse(attachment.stickerPlacement) != null))
            attachment,
    ];
    final guids = _stickers.map((a) => a.guid!).toSet();
    _ready.retainAll(guids);

    for (final attachment in List.of(_stickers)) {
      final guid = attachment.guid!;
      if (_ready.contains(guid) || _downloading.contains(guid)) continue;
      final exists = await FileSystemEntity.type(attachment.path) != FileSystemEntityType.notFound;
      if (!mounted || _ready.contains(guid) || _downloading.contains(guid)) continue;
      if (exists) {
        _markReady(guid, attachment);
      } else {
        _downloading.add(guid);
        AttachmentDownloader.startDownload(
          attachment,
          onComplete: (_) {
            _downloading.remove(guid);
            _markReady(guid, attachment);
          },
          onError: () => _downloading.remove(guid),
        );
      }
    }
  }

  void _markReady(String guid, Attachment attachment) {
    if (!mounted) return;
    setState(() => _ready.add(guid));
    _measure(attachment);
  }

  /// Reports a placed sticker's decoded size, so the room [StickerSpace] keeps for it matches what draws even when
  /// the attachment has no dimensions. It resolves the same provider [_image] draws, so it shares the decode.
  void _measure(Attachment attachment) {
    final state = _state;
    final guid = attachment.guid;
    if (!widget.placed || state == null || guid == null || !_measured.add(guid)) return;
    final stream = _provider(attachment, StickerHolder._stickerPixelRatio).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        state.updateStickerSizeInternal(guid, Size(info.image.width.toDouble(), info.image.height.toDouble()));
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
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
    final ready = _stickers.where((a) => _ready.contains(a.guid)).toList();
    if (ready.isEmpty) return const SizedBox.shrink();
    if (widget.placed) return _buildPlaced(ready);

    return _shrinkable(
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: NavigationSvc.width(context) * 0.6),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: ready
              .map(
                (attachment) => ConstrainedBox(
                  key: ValueKey(attachment.guid),
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
  Widget _buildPlaced(List<Attachment> ready) {
    return LayoutBuilder(builder: (context, constraints) {
      final bubble = constraints.biggest;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final attachment in ready)
            if (StickerPlacement.tryParse(attachment.stickerPlacement) case final p?) _placed(attachment, p, bubble),
        ],
      );
    });
  }

  Widget _placed(Attachment attachment, StickerPlacement p, Size bubble) {
    final center = StickerHolder.placedCenter(p, bubble, widget.isFromMe, widget.tailGutter);
    return Positioned(
      key: ValueKey(attachment.guid),
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: p.rotation,
          child: _shrinkable(
            Transform.scale(
              scale: p.scale,
              child: _image(attachment, FilterQuality.medium, StickerHolder._stickerPixelRatio),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider _provider(Attachment attachment, double scale) => FileImage(File(attachment.path), scale: scale);

  Widget _image(Attachment attachment, [FilterQuality quality = FilterQuality.none, double scale = 1]) => Image(
        image: _provider(attachment, scale),
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
