import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// [emoji] sized and centered by what it draws, filling the largest square it's given. Its text box is wider than the
/// drawing, and off center when a fallback font sets the line's ascent, so each emoji's drawing is measured once.
class InkFittedEmoji extends StatefulWidget {
  const InkFittedEmoji(this.emoji, {super.key});
  final String emoji;

  @override
  State<InkFittedEmoji> createState() => _InkFittedEmojiState();
}

class _InkFittedEmojiState extends State<InkFittedEmoji> {
  static const double _measureSize = 100;

  /// Where each emoji draws relative to its text box at [_measureSize]. Emptied when fonts change (a font loaded at
  /// runtime, like the Apple emoji font, finishing its load), so no measurement outlives the fonts it was taken with.
  static final Map<String, Future<Rect?>> _inkCache = {};
  static bool _clearsOnFontChange = false;
  Rect? _ink;

  static TextStyle _style(double fontSize) => TextStyle(
        fontSize: fontSize,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
        fontFamily: 'Apple Color Emoji',
      );

  @override
  void initState() {
    super.initState();
    // Added before any widget's own listener, so the cache is empty by the time they measure again
    if (!_clearsOnFontChange) {
      _clearsOnFontChange = true;
      PaintingBinding.instance.systemFonts.addListener(_inkCache.clear);
    }
    PaintingBinding.instance.systemFonts.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_load);
    super.dispose();
  }

  @override
  void didUpdateWidget(InkFittedEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji != widget.emoji) _load();
  }

  void _load() {
    final emoji = widget.emoji;
    _inkCache.putIfAbsent(emoji, () => _measure(emoji)).then((ink) {
      if (mounted && widget.emoji == emoji) setState(() => _ink = ink);
    });
  }

  static Future<Rect?> _measure(String emoji) async {
    final painter = TextPainter(
      text: TextSpan(text: emoji, style: _style(_measureSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    // Drawn with room around the box, since the drawing can overflow it
    const double margin = _measureSize / 2;
    final width = (painter.width + 2 * margin).ceil();
    final height = (painter.height + 2 * margin).ceil();
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(margin, margin));
    painter.dispose();
    final image = await recorder.endRecording().toImage(width, height);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (pixels == null) return null;
    int left = width, top = height, right = -1, bottom = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (pixels.getUint8((y * width + x) * 4 + 3) == 0) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < 0) return null;
    return Rect.fromLTRB(left - margin, top - margin, right + 1 - margin, bottom + 1 - margin);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final ink = _ink;
        // Close enough until it's measured
        if (ink == null) {
          return SizedBox.square(
            dimension: side,
            child: FittedBox(fit: BoxFit.fitHeight, child: Text(widget.emoji, style: _style(14))),
          );
        }
        final fontSize = _measureSize * side / ink.longestSide;
        final scale = fontSize / _measureSize;
        return SizedBox.square(
          dimension: side,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(side / 2, side / 2) - ink.center * scale,
              child: Text(widget.emoji, style: _style(fontSize)),
            ),
          ),
        );
      });
}
