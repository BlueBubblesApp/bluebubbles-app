import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/run_text_effects.dart';
import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Animates the composer's text effect runs on top of the field, which draws those runs transparent.
///
/// An editable field can't be repainted per glyph the way [RunTextEffects] repaints a paragraph, so this draws
/// each effect glyph itself, at the box the field's own [RenderEditable] reports for it. Wrapping, scrolling and
/// padding therefore always match the field.
class TextEffectOverlay extends StatefulWidget {
  const TextEffectOverlay({super.key, required this.controller, required this.fieldKey, required this.style});

  final MentionTextEditingController controller;

  /// Wraps the field whose [RenderEditable] is drawn over.
  final GlobalKey fieldKey;

  /// The field's text style.
  final TextStyle style;

  @override
  State<TextEffectOverlay> createState() => _TextEffectOverlayState();
}

class _TextEffectOverlayState extends State<TextEffectOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(TextEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _animation.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final effects = RunTextEffects.orderedRuns(widget.controller.runs);
    if (effects.isNotEmpty && TickerMode.valuesOf(context).enabled && !MediaQuery.disableAnimationsOf(context)) {
      final duration = RunTextEffects.durationFor(effects);
      if (_animation.duration != duration || !_animation.isAnimating) {
        _animation.duration = duration;
        _animation.repeat();
      }
    } else if (_animation.isAnimating) {
      _animation.stop();
      _animation.value = 0;
    }
    return IgnorePointer(
      child: _EffectGlyphs(
        controller: widget.controller,
        fieldKey: widget.fieldKey,
        style: widget.style,
        mentionColor: Theme.of(context).colorScheme.primary,
        animation: _animation,
      ),
    );
  }
}

class _EffectGlyphs extends LeafRenderObjectWidget {
  const _EffectGlyphs({
    required this.controller,
    required this.fieldKey,
    required this.style,
    required this.mentionColor,
    required this.animation,
  });

  final MentionTextEditingController controller;
  final GlobalKey fieldKey;
  final TextStyle style;
  final Color mentionColor;
  final Animation<double> animation;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEffectGlyphs(controller, fieldKey, style, mentionColor, animation);

  @override
  void updateRenderObject(BuildContext context, _RenderEffectGlyphs renderObject) {
    renderObject.update(controller, fieldKey, style, mentionColor, animation);
  }
}

class _RenderEffectGlyphs extends RenderBox {
  _RenderEffectGlyphs(this._controller, this._fieldKey, this._style, this._mentionColor, this._animation);

  MentionTextEditingController _controller;
  GlobalKey _fieldKey;
  TextStyle _style;
  Color _mentionColor;
  Animation<double> _animation;
  final Map<String, (TextPainter, Offset)> _painters = {};

  void update(
    MentionTextEditingController controller,
    GlobalKey fieldKey,
    TextStyle style,
    Color mentionColor,
    Animation<double> animation,
  ) {
    if (animation != _animation) {
      if (attached) _animation.removeListener(markNeedsPaint);
      _animation = animation;
      if (attached) _animation.addListener(markNeedsPaint);
    }
    if (style != _style || mentionColor != _mentionColor) _clearPainters();
    _controller = controller;
    _fieldKey = fieldKey;
    _style = style;
    _mentionColor = mentionColor;
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
    _clearPainters();
    super.dispose();
  }

  void _clearPainters() {
    for (final (painter, _) in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  static RenderEditable? _findEditable(RenderObject? node) {
    if (node is RenderEditable) return node;
    RenderEditable? found;
    node?.visitChildren((child) => found ??= _findEditable(child));
    return found;
  }

  /// A painter for [glyph], and where its tight glyph box sits relative to the painter's origin.
  (TextPainter, Offset) _painterFor(String glyph, Attributes attributes, TextScaler textScaler) {
    final decorations = [
      if (attributes.isUnderlined) TextDecoration.underline,
      if (attributes.isStrikethrough) TextDecoration.lineThrough,
    ];
    final key = '$glyph|${attributes.isBold}|${attributes.isItalic}|$decorations|${attributes.mention != null}';
    return _painters.putIfAbsent(key, () {
      final style = _style.copyWith(
        fontWeight: attributes.isBold || attributes.mention != null ? FontWeight.bold : null,
        fontStyle: attributes.isItalic ? FontStyle.italic : null,
        decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
        color: attributes.mention != null ? _mentionColor : null,
      );
      final painter = TextPainter(
        text: TextSpan(children: _controller.buildAppleEmojiTextSpans(text: glyph, style: style)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: glyph.length));
      return (painter, boxes.isEmpty ? Offset.zero : boxes.first.toRect().topLeft);
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final runs = RunTextEffects.orderedRuns(_controller.runs);
    final editable = _findEditable(_fieldKey.currentContext?.findRenderObject());
    if (runs.isEmpty || editable == null || !editable.attached || !editable.hasSize) return;
    final text = _controller.text;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.transform(editable.getTransformTo(this).storage);
    canvas.clipRect(Offset.zero & editable.size);
    for (final (index, run) in runs.indexed) {
      final effect = run.attributes!.textEffect!;
      final phase = RunTextEffects.phaseFor(_animation.value, index, runs.length);
      final start = run.range[0].clamp(0, text.length);
      final end = (run.range[0] + run.range[1]).clamp(start, text.length);
      final lines = editable
          .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
          .map((b) => b.toRect())
          .toList();
      if (lines.isEmpty) continue;
      final runCenterX = lines.fold(0.0, (sum, r) => sum + r.center.dx) / lines.length;
      final glyphs = <(String, Rect)>[];
      var i = start;
      for (final g in text.substring(start, end).characters) {
        if (g.trim().isNotEmpty) {
          final boxes = editable.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + g.length));
          if (boxes.isNotEmpty) glyphs.add((g, boxes.first.toRect()));
        }
        i += g.length;
      }
      for (final (n, (glyph, rect)) in glyphs.indexed) {
        final TextEffectPose pose;
        if (phase <= 0 || phase >= 1) {
          pose = (transform: Matrix4.identity(), alpha: 1, bold: 0);
        } else if (RunTextEffects.perGlyph(effect)) {
          final frac = glyphs.length > 1 ? n / (glyphs.length - 1) : 0.5;
          pose = RenderRunTextEffects.glyphPose(effect, phase, n, frac, rect, runCenterX);
        } else {
          final line = lines.firstWhere((l) => l.contains(rect.center), orElse: () => rect);
          pose = RenderRunTextEffects.runPose(effect, phase, line);
        }
        if (pose.alpha <= 0) continue;
        final (painter, ownBoxTopLeft) = _painterFor(glyph, run.attributes!, editable.textScaler);
        // The field reports tight glyph boxes; lining up the painter's own tight box keeps baselines equal
        final origin = rect.topLeft - ownBoxTopLeft;
        for (final dx in [0.0, if (pose.bold >= 0.05) ...[pose.bold / 2, pose.bold]]) {
          canvas.save();
          canvas.transform((Matrix4.translationValues(dx, 0, 0)..multiply(pose.transform)).storage);
          if (pose.alpha < 1) {
            canvas.saveLayer(rect.inflate(rect.height), Paint()..color = Color.fromRGBO(0, 0, 0, pose.alpha));
          }
          painter.paint(canvas, origin);
          if (pose.alpha < 1) canvas.restore();
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }
}
