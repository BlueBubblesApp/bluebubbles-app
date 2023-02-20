import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverDecoration extends SingleChildRenderObjectWidget {
  const SliverDecoration({
    super.key,
    required this.color,
    required this.borderRadius,
    Widget? sliver,
  }) : super(child: sliver);

  final Color color;
  final BorderRadius borderRadius;

  @override
  RenderSliverDecoration createRenderObject(BuildContext context) {
    return RenderSliverDecoration(
      color: color,
      borderRadius: borderRadius,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverDecoration renderObject) {
    renderObject.color = color;
  }
}

class RenderSliverDecoration extends RenderProxySliver {
  RenderSliverDecoration({
    required Color color,
    required BorderRadius borderRadius,
    RenderSliver? sliver,
  }) {
    _color = color;
    _borderRadius = borderRadius;
    child = sliver;
  }

  Color get color => _color;
  late Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  BorderRadiusGeometry get borderRadius => _borderRadius;
  late BorderRadiusGeometry _borderRadius;
  set borderRadius(BorderRadiusGeometry value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  RRect? _clipRRect;
  Offset? _offset;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void performLayout() {
    if (child == null) {
      geometry = const SliverGeometry();
      return;
    }
    child!.layout(constraints, parentUsesSize: true);
    final SliverGeometry childLayoutGeometry = child!.geometry!;
    geometry = childLayoutGeometry;
    double headerPosition = child!.constraints.viewportMainAxisExtent - child!.constraints.remainingPaintExtent;
    BorderRadius borderRadius = this.borderRadius.resolve(TextDirection.ltr);
    _clipRRect = borderRadius.toRRect(Rect.fromLTRB(0, 0, constraints.crossAxisExtent, child!.paintBounds.bottom));
    _offset = Offset(0, headerPosition);
    _clipRRect = _clipRRect!.shift(_offset!);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry!.visible && _clipRRect != null) {
      context.canvas.drawRRect(_clipRRect!, Paint()..color = color..style = PaintingStyle.fill);
    }
    if (child != null && child!.geometry!.visible) {
      assert(needsCompositing);
      if (_clipRRect != null && _clipRRect != RRect.zero) {
        context.pushClipRRect(
          needsCompositing,
          offset + (child!.parentData! as SliverPhysicalParentData).paintOffset,
          _clipRRect!.outerRect,
          RRect.fromRectAndRadius(child!.paintBounds, _clipRRect!.blRadius),
          super.paint,
        );
      } else {
        super.paint(context, offset);
      }
    }
  }
}