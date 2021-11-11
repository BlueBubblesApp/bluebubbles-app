import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/animations/love_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Love extends LeafRenderObjectWidget {
  Love({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final LoveController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLove(
      controller: controller,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLove renderObject) {
    renderObject.controller = controller;
  }
}

class RenderLove extends RenderBox {
  RenderLove({
    required LoveController controller,
  })   : _controller = controller;

  LoveController get controller => _controller;
  LoveController _controller;

  set controller(LoveController value) {
    if (controller == value) return;

    // Detach old controller.
    _controller.removeListener(_handleControllerUpdate);
    _controller = value;

    // Attach new controller.
    controller.addListener(_handleControllerUpdate);
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);

    controller.addListener(_handleControllerUpdate);
  }

  @override
  void detach() {
    controller.removeListener(_handleControllerUpdate);

    super.detach();
  }

  void _handleControllerUpdate() {
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) {
    return size.contains(position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size)
      ..translate(offset.dx, offset.dy);

    _drawHeart(canvas);

    canvas.restore();
  }

  void _drawHeart(Canvas canvas) {
    if (controller.heart != null) {
      double d = controller.heart!.size;
      double x = controller.heart!.position.x;
      double y = controller.heart!.position.y;
      final Path p = Path();
      p.moveTo(x, y + d / 4);
      p.quadraticBezierTo(x, y, x + d / 4, y);
      p.quadraticBezierTo(x + d / 2, y, x + d / 2, y + d / 4);
      p.quadraticBezierTo(x + d / 2, y, x + d * 3/4, y);
      p.quadraticBezierTo(x + d, y, x + d, y + d / 4);
      p.quadraticBezierTo(x + d, y + d / 2, x + d * 3/4, y + d * 3/4);
      p.lineTo(x + d / 2, y + d);
      p.lineTo(x + d / 4, y + d * 3/4);
      p.quadraticBezierTo(x, y + d / 2, x, y + d / 4);

      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
            colors: [
              Colors.red.darkenAmount(0.2).withOpacity(0.7),
              Colors.red.lightenAmount(0.1).withOpacity(0.7)
            ],
            stops: [0, 0.7]
        ).createShader(Rect.fromCircle(center: Offset(x + d * 3/4, y + d / 4), radius: d * 1.5))
      );
    }
  }
}