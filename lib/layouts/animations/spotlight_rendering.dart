
import 'dart:math';

import 'package:bluebubbles/layouts/animations/spotlight_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Spotlight extends LeafRenderObjectWidget {
  Spotlight({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final SpotlightController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSpotlight(
      controller: controller,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSpotlight renderObject) {
    renderObject.controller = controller;
  }
}

class RenderSpotlight extends RenderBox {
  RenderSpotlight({
    required SpotlightController controller,
  })   : _controller = controller;

  SpotlightController get controller => _controller;
  SpotlightController _controller;

  set controller(SpotlightController value) {
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

    _drawSpotlight(canvas);

    canvas.restore();
  }

  void _drawSpotlight(Canvas canvas) {
    if (controller.spotlight != null) {
      final Path p = Path();
      double centerX = controller.spotlight!.position.x;
      double centerY = controller.spotlight!.position.y;
      double size = controller.spotlight!.size;
      double stop = controller.spotlight!.stop;
      double screenWidth = controller.windowSize.width;
      p.addArc(Rect.fromCenter(
        center: Offset(centerX, centerY),
        height: size,
        width: size,
      ), 0, 2 * pi);
      if (stop == 1) {
        canvas.drawPath(p, Paint()
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
              colors: [
                Colors.white.withOpacity(0.5),
                Colors.white.withOpacity(0.3)
              ],
              stops: [0, 0.7]
          ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: size))
        );
      }
      double pointX = screenWidth - (controller.spotlight!.originalPosition.y - controller.spotlight!.position.y);
      double pointY = 0;
      double dx = pointX - centerX;
      double dy = pointY - centerY;
      double dxr = -dy;
      double dyr = dx;
      double d = sqrt(pow(dx, 2) + pow(dy, 2));
      double rho = size / 2 / d;
      double ad = pow(rho, 2).toDouble();
      double bd = rho * sqrt(1 - pow(rho, 2));
      double tangent1X = centerX + ad * dx + bd * dxr;
      double tangent1Y = centerY + ad * dy + bd * dyr;
      double tangent2X = centerX + ad * dx - bd * dxr;
      double tangent2Y = centerY + ad * dy - bd * dyr;
      final Path p2 = Path();
      p2.moveTo(pointX, 0);
      p2.lineTo(min(tangent1X, tangent2X), min(tangent1Y, tangent2Y));
      p2.arcToPoint(Offset(centerX, centerY + size / 2), radius: Radius.circular(size / 2), largeArc: false, clockwise: false);
      p2.arcToPoint(Offset(max(tangent1X, tangent2X), max(tangent1Y, tangent2Y)), radius: Radius.circular(size / 2), largeArc: false, clockwise: false);
      p2.lineTo(pointX, 0);
      canvas.drawPath(p2, Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.white.withOpacity(0.3),
              if (stop != 1)
                Colors.transparent,
            ],
            stops: [0, stop == 1 ? 0.7 : stop - 0.1, if (stop != 1) stop]
        ).createShader(Rect.fromCircle(center: Offset(screenWidth, 0), radius: controller.spotlight!.position.y))
      );
    }
  }
}