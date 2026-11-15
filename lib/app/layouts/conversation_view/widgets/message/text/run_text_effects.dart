import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Paints animated runs from the original paragraph so wrapping, emoji, and link hit testing stay intact.
class RunTextEffects extends SingleChildRenderObjectWidget {
  const RunTextEffects({
    super.key,
    required this.runs,
    required this.animation,
    this.textOffset = 0,
    required super.child,
  });

  final List<Run> runs;
  final Animation<double> animation;
  final int textOffset;

  // IDs from issue #3447.
  static bool supports(int? effect) => const [5, 11, 9, 8, 4, 10, 12, 6].contains(effect);
  static bool perGlyph(int effect) => const [4, 12, 6].contains(effect);

  // Native picker footage at https://www.youtube.com/watch?v=7Om3ktMJcjc (52–64 s):
  // size/position traces repeat after about 49 frames at 24 fps (~2.04 s).
  // This calibrates the preview cadence, not every OS version's received-message timing.
  // Ripple, Bloom, Jitter, and Explode: https://www.youtube.com/shorts/-BWjuKBMEr8 (16-24 s).
  static const effectDuration = Duration(milliseconds: 2050);
  static const stagger = Duration(milliseconds: 180);

  static List<Run> orderedRuns(List<Run> runs) =>
      runs
          .where(
            (run) =>
                supports(run.attributes?.textEffect) && run.range.length == 2 && run.range[0] >= 0 && run.range[1] > 0,
          )
          .toList()
        ..sort((a, b) => a.range[0].compareTo(b.range[0]));

  static Duration durationFor(List<Run> runs) => effectDuration + stagger * math.max(0, orderedRuns(runs).length - 1);

  /// Where the [index]th of [count] staggered runs is in its own cycle at [progress] through the shared one.
  static double phaseFor(double progress, int index, int count) {
    final elapsed = progress * (effectDuration + stagger * math.max(0, count - 1)).inMilliseconds;
    return ((elapsed - index * stagger.inMilliseconds) / effectDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  RenderObject createRenderObject(BuildContext context) => RenderRunTextEffects(runs, animation, textOffset);

  @override
  void updateRenderObject(BuildContext context, covariant RenderRunTextEffects renderObject) {
    renderObject.update(runs, animation, textOffset);
  }
}

class RenderRunTextEffects extends RenderProxyBox {
  RenderRunTextEffects(this._runs, this._animation, this._textOffset);

  List<Run> _runs;
  Animation<double> _animation;
  int _textOffset;
  // Selection boxes only change with layout, so they're measured once rather than every frame.
  _Geometry? _geometry;

  void _dropGeometry() {
    _geometry?.dispose();
    _geometry = null;
  }

  void update(List<Run> runs, Animation<double> animation, int textOffset) {
    if (animation != _animation) {
      if (attached) _animation.removeListener(markNeedsPaint);
      _animation = animation;
      if (attached) _animation.addListener(markNeedsPaint);
    }
    _runs = runs;
    _textOffset = textOffset;
    _dropGeometry();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _dropGeometry();
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    _dropGeometry();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paragraph = child;
    final progress = _animation.value;
    if (paragraph is! RenderParagraph || progress <= 0 || progress >= 1) {
      super.paint(context, offset);
      return;
    }
    // Reusing a composited inline widget's layer under several clips reparents that layer.
    // Keep these paragraphs intact until inline images have their own animation path.
    if (paragraph.childCount > 0) {
      super.paint(context, offset);
      return;
    }
    final cut = <Rect>[];
    final pieces = <(Rect, Matrix4, double)>[];
    final glyphs = <(_Glyph, Matrix4, double)>[];
    void add(Rect rect, TextEffectPose pose) {
      // Resting fragments stay in the single untransformed paint.
      if (pose.alpha >= 1 && pose.bold < 0.05 && pose.transform.isIdentity()) return;
      cut.add(rect);
      if (pose.alpha <= 0) return;
      pieces.add((rect, pose.transform, pose.alpha));
      // Shifted overdraws fake a heavier weight without re-laying out the paragraph.
      if (pose.bold < 0.05) return;
      pieces.add((rect, Matrix4.translationValues(pose.bold / 2, 0, 0)..multiply(pose.transform), pose.alpha));
      pieces.add((rect, Matrix4.translationValues(pose.bold, 0, 0)..multiply(pose.transform), pose.alpha));
    }

    void addGlyph(_Glyph glyph, TextEffectPose pose) {
      if (pose.alpha <= 0) return;
      glyphs.add((glyph, pose.transform, pose.alpha));
      if (pose.bold < 0.05) return;
      glyphs.add((glyph, Matrix4.translationValues(pose.bold / 2, 0, 0)..multiply(pose.transform), pose.alpha));
      glyphs.add((glyph, Matrix4.translationValues(pose.bold, 0, 0)..multiply(pose.transform), pose.alpha));
    }

    final geometry = _geometry ??= _measure(paragraph);
    for (final (index, run) in geometry.runs.indexed) {
      final phase = RunTextEffects.phaseFor(progress, index, geometry.runs.length);
      final glyphsOfRun = run.glyphs;
      if (glyphsOfRun == null) {
        if (phase <= 0 || phase >= 1) continue;
        for (final rect in run.lines) {
          add(rect, runPose(run.effect, phase, rect));
        }
        continue;
      }
      // These runs are blank in the base paint for the whole animation, so their glyphs paint even at rest.
      final last = run.glyphCount - 1;
      for (final glyph in glyphsOfRun) {
        addGlyph(
          glyph,
          phase <= 0 || phase >= 1
              ? _pose(Matrix4.identity())
              : glyphPose(run.effect, phase, glyph.index, last > 0 ? glyph.index / last : 0.5, glyph.rect, run.centerX),
        );
      }
    }
    final hidden = geometry.hidden;
    if (cut.isEmpty && hidden == null) {
      super.paint(context, offset);
      return;
    }
    void paintBase(PaintingContext context, Offset offset) =>
        hidden == null ? context.paintChild(paragraph, offset) : hidden.paint(context.canvas, offset);
    // Paint the unaffected text once, then each affected fragment under its own transform.
    // Cut rects don't overlap, so even-odd filling subtracts them without path boolean ops.
    if (cut.isEmpty) {
      paintBase(context, offset);
    } else {
      final remaining = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size);
      for (final rect in cut) {
        remaining.addRect(rect);
      }
      context.pushClipPath(needsCompositing, offset, Offset.zero & size, remaining, paintBase,
          clipBehavior: Clip.hardEdge);
    }
    for (final (rect, transform, alpha) in pieces) {
      context.pushTransform(needsCompositing, offset, transform, (context, offset) {
        // A canvas layer rather than an OpacityLayer, so the bubble's canvas clip still applies.
        if (alpha < 1) context.canvas.saveLayer(rect.shift(offset), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
        context.pushClipRect(
          needsCompositing,
          offset,
          rect,
          (context, offset) => context.paintChild(paragraph, offset),
          clipBehavior: Clip.hardEdge,
        );
        if (alpha < 1) context.canvas.restore();
      });
    }
    // Each glyph paints by itself rather than as a slice of the paragraph: a glyph's ink spills past its box
    // (side bearings, italics, kerning), so a slice carries a neighbor's edge and leaves its own overhang behind.
    for (final (glyph, transform, alpha) in glyphs) {
      context.pushTransform(needsCompositing, offset, transform, (context, offset) {
        final origin = offset + glyph.origin;
        if (alpha < 1) {
          context.canvas.saveLayer(
              (origin & glyph.painter.size).inflate(glyph.rect.height), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
        }
        glyph.painter.paint(context.canvas, origin);
        if (alpha < 1) context.canvas.restore();
      });
    }
  }

  _Geometry _measure(RenderParagraph paragraph) {
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final runs = [
      for (final run in RunTextEffects.orderedRuns(_runs))
        _measureRun(paragraph, text, run.attributes!.textEffect!, run.range[0], run.range[1]),
    ];
    final perGlyph = [
      for (final run in runs)
        if (run.glyphs != null) (run.start, run.end),
    ];
    return (runs: runs, hidden: perGlyph.isEmpty ? null : _hiddenPainter(paragraph, perGlyph));
  }

  _RunGeometry _measureRun(RenderParagraph paragraph, String text, int effect, int location, int length) {
    final start = math.min(_textOffset + location, text.length);
    final end = math.min(start + length, text.length);
    final lines = _rects(paragraph, start, end);
    if (!RunTextEffects.perGlyph(effect) || lines.isEmpty) {
      return (effect: effect, start: start, end: end, lines: lines, glyphs: null, glyphCount: 0, centerX: 0);
    }
    final glyphs = <_Glyph>[];
    var count = 0;
    var i = start;
    for (final g in text.substring(start, end).characters) {
      if (g.trim().isNotEmpty) {
        final selection = TextSelection(baseOffset: i, extentOffset: i + g.length);
        final tight = paragraph.getBoxesForSelection(selection).map((box) => box.toRect()).firstOrNull;
        final rect = _rects(paragraph, i, i + g.length).firstOrNull;
        if (tight != null && rect != null) {
          final painter = TextPainter(
            text: TextSpan(text: g, style: _styleAt(paragraph.text, i)),
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            locale: paragraph.locale,
          )..layout();
          final own = painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: g.length)).firstOrNull;
          // Line its glyph box up with the one the paragraph laid out.
          glyphs.add((
            index: count,
            rect: rect,
            painter: painter,
            origin: tight.topLeft - (own?.toRect().topLeft ?? Offset.zero),
          ));
        }
        count++;
      }
      i += g.length;
    }
    final centerX = lines.fold(0.0, (sum, r) => sum + r.center.dx) / lines.length;
    return (effect: effect, start: start, end: end, lines: lines, glyphs: glyphs, glyphCount: count, centerX: centerX);
  }

  /// The style the paragraph paints [offset] with, inherited down its spans.
  static TextStyle? _styleAt(InlineSpan root, int offset) {
    var position = 0;
    TextStyle? found;
    bool visit(InlineSpan span, TextStyle? inherited) {
      if (span is! TextSpan) {
        position++;
        return false;
      }
      final style = inherited == null ? span.style : inherited.merge(span.style);
      final text = span.text;
      if (text != null) {
        if (offset < position + text.length) {
          found = style;
          return true;
        }
        position += text.length;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (visit(child, style)) return true;
      }
      return false;
    }

    visit(root, null);
    return found;
  }

  /// The paragraph laid out as it is, with the [ranges] painted transparent: the base under per-glyph effects.
  static TextPainter _hiddenPainter(RenderParagraph paragraph, List<(int, int)> ranges) {
    const clear = TextStyle(color: Color(0x00000000));
    bool hides(int offset) => ranges.any((r) => offset >= r.$1 && offset < r.$2);
    var position = 0;
    InlineSpan hide(InlineSpan span) {
      if (span is! TextSpan) {
        position++;
        return span;
      }
      final text = span.text;
      final pieces = <InlineSpan>[];
      if (text != null && text.isNotEmpty) {
        final from = position;
        position += text.length;
        final cuts = {0, text.length};
        for (final (a, b) in ranges) {
          if (b <= from || a >= position) continue;
          cuts
            ..add((a - from).clamp(0, text.length))
            ..add((b - from).clamp(0, text.length));
        }
        final sorted = cuts.toList()..sort();
        for (var k = 0; k + 1 < sorted.length; k++) {
          pieces.add(TextSpan(
            text: text.substring(sorted[k], sorted[k + 1]),
            style: hides(from + sorted[k]) ? clear : null,
          ));
        }
      }
      return TextSpan(style: span.style, children: [...pieces, ...?span.children?.map(hide)]);
    }

    final widthMatters = paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis;
    return TextPainter(
      text: hide(paragraph.text),
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(
        minWidth: paragraph.constraints.minWidth,
        maxWidth: widthMatters ? paragraph.constraints.maxWidth : double.infinity,
      );
  }

  static List<Rect> _rects(RenderParagraph paragraph, int start, int end) => paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end), boxHeightStyle: ui.BoxHeightStyle.max)
      .map((box) => box.toRect())
      .where((rect) => !rect.isEmpty)
      .toList();

  static TextEffectPose _pose(Matrix4 transform, {double alpha = 1, double bold = 0}) =>
      (transform: transform, alpha: alpha, bold: bold);

  static Matrix4 _about(Offset center, Offset translation, double scale, {double rotation = 0, double stretch = 1}) =>
      Matrix4.identity()
        ..translateByDouble(center.dx + translation.dx, center.dy + translation.dy, 0, 1)
        ..rotateZ(rotation)
        ..scaleByDouble(scale * stretch, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

  static TextEffectPose runPose(int effect, double phase, Rect rect) {
    if (effect == 10) {
      // Jitter: the whole fragment hops and tilts every 40 ms for ~0.8 s, then rests.
      if (phase >= 0.4) return _pose(Matrix4.identity());
      final amplitude = math.sin(math.pi * phase / 0.4);
      final step = (phase * RunTextEffects.effectDuration.inMilliseconds / 40).floor();
      return _pose(
        _about(
          rect.center,
          Offset(_noise(step, 0), _noise(step, 1)) * (0.12 * rect.height * amplitude),
          1,
          rotation: 0.05 * amplitude * _noise(step, 2),
        ),
      );
    }
    // Size effects expand/shrink, hold, return, and rest. Motion effects have a
    // short burst followed by a longer idle interval instead of moving continuously.
    final envelope = switch (phase) {
      < 0.16 => Curves.easeOutCubic.transform(phase / 0.16),
      < 0.52 => 1.0,
      < 0.68 => 1 - Curves.easeInOutCubic.transform((phase - 0.52) / 0.16),
      _ => 0.0,
    };
    final motionProgress = (phase / 0.44).clamp(0.0, 1.0);
    final oscillation = motionProgress >= 1
        ? 0.0
        : math.sin(math.pi * 6 * motionProgress) * math.sin(math.pi * motionProgress);
    final scale = switch (effect) {
      5 => 1 + 0.35 * envelope,
      11 => 1 - 0.3 * envelope,
      _ => 1.0,
    };
    final translation = switch (effect) {
      9 => Offset(4 * oscillation, 0),
      8 => Offset(0, 4 * oscillation),
      _ => Offset.zero,
    };
    // Nod thickens while it moves.
    final bold = effect == 8 ? 0.9 * math.sin(math.pi * motionProgress) : 0.0;
    return _pose(_about(rect.center, translation, scale), bold: bold);
  }

  /// [frac] is the glyph's position in its run, 0 (first) to 1 (last).
  static TextEffectPose glyphPose(int effect, double phase, int index, double frac, Rect rect, double runCenterX) {
    if (effect == 12) return _explode(phase, index, frac, rect, runCenterX);
    // Ripple and Bloom: one crest sweeps left to right, then the run rests.
    final (sweep, width) = effect == 4 ? (0.3, 0.5) : (0.45, 0.6);
    final u = (phase / sweep * (1 + width) - frac) / width;
    if (u <= 0 || u >= 1) return _pose(Matrix4.identity());
    final crest = math.sin(math.pi * u);
    if (effect == 6) return _pose(_about(rect.center, Offset.zero, 1, stretch: 1 + 0.12 * crest), bold: crest);
    // Ripple glyphs lift and tilt along the wave's slope.
    return _pose(
      _about(
        rect.center,
        Offset(0, -0.35 * rect.height * crest),
        1 + 0.08 * crest,
        rotation: 0.2 * math.sin(2 * math.pi * u),
      ),
    );
  }

  // Traced from picker footage: glyphs shake loose for 0.1 s, then launch ballistically from below the run. Middle
  // glyphs shoot up and toward the viewer, falling back through the bubble several times larger; end glyphs fly out
  // sideways, turning to follow their path. The run then stays blank and fades back in.
  static TextEffectPose _explode(double phase, int index, double frac, Rect rect, double runCenterX) {
    final h = rect.height;
    final seconds = phase * RunTextEffects.effectDuration.inMilliseconds / 1000;
    const shake = 0.45;
    if (seconds < shake) {
      // The run squeezes toward its center while each glyph jostles to a new spot every frame.
      final squeeze = Curves.easeIn.transform(seconds / shake);
      final step = (seconds * 30).floor();
      return _pose(
        _about(
          rect.center,
          Offset((runCenterX - rect.center.dx) * 0.1 * squeeze, 0) +
              Offset(_noise(index, step * 3), _noise(index, step * 3 + 1)) * (0.07 * h * (0.4 + 0.6 * squeeze)),
          1 - 0.08 * squeeze,
          rotation: 0.1 * (0.4 + 0.6 * squeeze) * _noise(index, step * 3 + 2),
        ),
      );
    }
    final t = seconds - shake;
    if (t >= 0.65) return _pose(Matrix4.identity(), alpha: ((phase - 0.855) / 0.075).clamp(0.0, 1.0));
    final side = frac * 2 - 1;
    final centered = 1 - side * side;
    // The middle shoots off the top within 0.1 s and drops back at ~0.5 s; the ends rise a little and hang near
    // the top edge while flying out sideways, already tilted ~30 degrees by 0.1 s.
    final rise = (6 + 18 * centered) * h * t;
    final fall = (5 + 43 * centered) * h * t * t;
    final scale = 1 / math.max(0.2, 1 - 3 * (0.4 + 0.6 * centered) * t * t);
    // The last of the shake and squeeze carries into the launch instead of snapping to rest.
    final carry = math.max(0.0, 1 - t / 0.06);
    final step = (seconds * 30).floor();
    return _pose(
      _about(
        rect.center,
        Offset((runCenterX - rect.center.dx) * 0.1 + side * 8 * h * t, fall - rise) +
            Offset(_noise(index, step * 3), _noise(index, step * 3 + 1)) * (0.07 * h * carry),
        scale * (1 - 0.08 * carry),
        rotation: side * math.min(1.9, 7 * t),
      ),
      // Glyphs thin out as they swell toward the viewer, then fade before the blank interval.
      alpha: math.min(1, 1.5 / scale) * (1 - ((t - 0.5) / 0.15).clamp(0.0, 1.0)),
    );
  }

  static double _noise(int a, int b) {
    final v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return (v - v.floorToDouble()) * 2 - 1;
  }
}

typedef TextEffectPose = ({Matrix4 transform, double alpha, double bold});
// [rect] is the glyph's line-height box, which poses move about; [origin] is where [painter] paints it.
typedef _Glyph = ({int index, Rect rect, TextPainter painter, Offset origin});
// [glyphs] is null for effects that transform whole line fragments.
typedef _RunGeometry = ({
  int effect,
  int start,
  int end,
  List<Rect> lines,
  List<_Glyph>? glyphs,
  int glyphCount,
  double centerX,
});
// [hidden] paints the paragraph with the per-glyph runs blank, or is null when there are none.
typedef _Geometry = ({List<_RunGeometry> runs, TextPainter? hidden});

extension on _Geometry {
  void dispose() {
    hidden?.dispose();
    for (final run in runs) {
      for (final glyph in run.glyphs ?? const <_Glyph>[]) {
        glyph.painter.dispose();
      }
    }
  }
}
