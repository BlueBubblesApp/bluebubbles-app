import 'dart:math';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/animations/laser_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Laser extends LeafRenderObjectWidget {
  Laser({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final LaserController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLaser(
      controller: controller,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLaser renderObject) {
    renderObject.controller = controller;
  }
}

class RenderLaser extends RenderBox {
  RenderLaser({
    required LaserController controller,
  })   : _controller = controller;

  LaserController get controller => _controller;
  LaserController _controller;

  set controller(LaserController value) {
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

    _drawLasers(canvas);

    canvas.restore();
  }

  void _drawLasers(Canvas canvas) {
    if (controller.laser != null) {
      final Path p = Path();
      double centerX = controller.laser!.position.x;
      double centerY = controller.laser!.position.y;
      double screenHeight = max(controller.windowSize.height, controller.windowSize.width) * sqrt(2);
      Color color = HSVColor.fromAHSV(1, controller.globalHue % 360, 1, 1).toColor();
      p.addArc(Rect.fromCenter(
        center: Offset(centerX, centerY),
        height: screenHeight * 2 - 100,
        width: screenHeight * 2 - 100,
      ), 0, 2 * pi);
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
            colors: [
              color.withOpacity(0.8),
              Colors.transparent,
            ],
            stops: [0, 0.9]
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: screenHeight * 2 - 100))
      );
      for (LaserBeam b in controller.beams) {
        final Path p2 = Path();
        p2.moveTo(centerX, centerY);
        p2.lineTo(centerX + screenHeight * cos(b.globalAngle) - b.internalWidth * sin(b.globalAngle), centerY + screenHeight * sin(b.globalAngle) + b.internalWidth * cos(b.globalAngle));
        p2.lineTo(centerX + screenHeight * cos(b.globalAngle) + b.internalWidth * sin(b.globalAngle), centerY + screenHeight * sin(b.globalAngle) - b.internalWidth * cos(b.globalAngle));
        p2.lineTo(centerX, centerY);
        canvas.drawPath(p2, Paint()
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
              colors: [
                color,
                Colors.transparent,
              ],
              stops: [0, 0.9]
          ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: screenHeight * 2 - 100))
        );
        canvas.drawPath(p2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.lightenAmount(0.1)
        );
      }
    }
  }
}