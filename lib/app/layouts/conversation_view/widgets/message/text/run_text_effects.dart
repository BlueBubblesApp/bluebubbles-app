import 'dart:math' as math;

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

  static bool supports(int? effect) => const [5, 11, 9, 8].contains(effect);

  // Native picker footage at https://www.youtube.com/watch?v=7Om3ktMJcjc (52–64 s):
  // size/position traces repeat after about 49 frames at 24 fps (~2.04 s).
  // This calibrates the preview cadence, not every OS version's received-message timing.
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

  void update(List<Run> runs, Animation<double> animation, int textOffset) {
    if (animation != _animation) {
      if (attached) _animation.removeListener(markNeedsPaint);
      _animation = animation;
      if (attached) _animation.addListener(markNeedsPaint);
    }
    _runs = runs;
    _textOffset = textOffset;
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
    final boxes = <({Rect rect, int effect, double progress})>[];
    final runs = RunTextEffects.orderedRuns(_runs);
    final elapsed = progress * RunTextEffects.durationFor(runs).inMilliseconds;
    for (final (index, run) in runs.indexed) {
      final effect = run.attributes?.textEffect;
      final phase =
          ((elapsed - index * RunTextEffects.stagger.inMilliseconds) / RunTextEffects.effectDuration.inMilliseconds)
              .clamp(0.0, 1.0);
      if (phase <= 0 || phase >= 1) continue;
      final selection = TextSelection(
        baseOffset: _textOffset + run.range[0],
        extentOffset: _textOffset + run.range[0] + run.range[1],
      );
      for (final box in paragraph.getBoxesForSelection(selection)) {
        if (!box.toRect().isEmpty) boxes.add((rect: box.toRect(), effect: effect!, progress: phase));
      }
    }
    if (boxes.isEmpty) {
      super.paint(context, offset);
      return;
    }
    // Paint the unaffected text once, then each affected line fragment under its own transform.
    var remaining = Path()..addRect(Offset.zero & size);
    for (final box in boxes) {
      remaining = Path.combine(PathOperation.difference, remaining, Path()..addRect(box.rect));
    }
    context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      remaining,
      (context, offset) => context.paintChild(paragraph, offset),
      clipBehavior: Clip.hardEdge,
    );
    for (final box in boxes) {
      // Size effects expand/shrink, hold, return, and rest. Motion effects have a
      // short burst followed by a longer idle interval instead of moving continuously.
      final envelope = switch (box.progress) {
        < 0.16 => Curves.easeOutCubic.transform(box.progress / 0.16),
        < 0.52 => 1.0,
        < 0.68 => 1 - Curves.easeInOutCubic.transform((box.progress - 0.52) / 0.16),
        _ => 0.0,
      };
      final motionProgress = (box.progress / 0.44).clamp(0.0, 1.0);
      final oscillation = motionProgress >= 1
          ? 0.0
          : math.sin(math.pi * 6 * motionProgress) * math.sin(math.pi * motionProgress);
      final scale = switch (box.effect) {
        5 => 1 + 0.35 * envelope,
        11 => 1 - 0.3 * envelope,
        _ => 1.0,
      };
      final translation = switch (box.effect) {
        9 => Offset(4 * oscillation, 0),
        8 => Offset(0, 4 * oscillation),
        _ => Offset.zero,
      };
      final center = box.rect.center;
      final transform = Matrix4.identity()
        ..translateByDouble(center.dx + translation.dx, center.dy + translation.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
      context.pushTransform(needsCompositing, offset, transform, (context, offset) {
        context.pushClipRect(
          needsCompositing,
          offset,
          box.rect,
          (context, offset) => context.paintChild(paragraph, offset),
          clipBehavior: Clip.hardEdge,
        );
      });
    }
  }
}
