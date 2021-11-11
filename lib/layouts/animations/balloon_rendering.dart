import 'dart:math';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/animations/balloon_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Balloons extends LeafRenderObjectWidget {
  Balloons({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final BalloonController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBalloons(
      controller: controller,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBalloons renderObject) {
    renderObject.controller = controller;
  }
}

class RenderBalloons extends RenderBox {
  RenderBalloons({
    required BalloonController controller,
  })   : _controller = controller;

  BalloonController get controller => _controller;
  BalloonController _controller;

  set controller(BalloonController value) {
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

    _drawBalloons(canvas);

    canvas.restore();
  }

  void _drawBalloons(Canvas canvas) {
    for (final balloon in controller.balloons) {
      double centerX = balloon.position.x;
      double centerY = balloon.position.y;
      double radius = balloon.radius;

      var handleLength = kappa * radius;

      var widthDiff = (radius * WIDTH_FACTOR);
      var heightDiff = (radius * HEIGHT_FACTOR);

      var balloonBottomY = centerY + radius + heightDiff;

      // Begin balloon path

      Path p = Path();

      // Top Left Curve

      var topLeftCurveStartX = centerX - radius;
      var topLeftCurveStartY = centerY;

      double topLeftCurveEndX = centerX;
      double topLeftCurveEndY = centerY - radius;

      p.moveTo(topLeftCurveStartX, topLeftCurveStartY);
      p.cubicTo(topLeftCurveStartX, topLeftCurveStartY - handleLength - widthDiff,
          topLeftCurveEndX - handleLength, topLeftCurveEndY,
          topLeftCurveEndX, topLeftCurveEndY);

      // Top Right Curve

      var topRightCurveStartX = centerX;
      var topRightCurveStartY = centerY - radius;

      var topRightCurveEndX = centerX + radius;
      var topRightCurveEndY = centerY;

      p.cubicTo(topRightCurveStartX + handleLength + widthDiff, topRightCurveStartY,
          topRightCurveEndX, topRightCurveEndY - handleLength,
          topRightCurveEndX, topRightCurveEndY);

      // Bottom Right Curve

      var bottomRightCurveStartX = centerX + radius;
      var bottomRightCurveStartY = centerY;

      var bottomRightCurveEndX = centerX;
      var bottomRightCurveEndY = balloonBottomY;

      p.cubicTo(bottomRightCurveStartX, bottomRightCurveStartY + handleLength,
          bottomRightCurveEndX + handleLength, bottomRightCurveEndY,
          bottomRightCurveEndX, bottomRightCurveEndY);

      // Bottom Left Curve

      var bottomLeftCurveStartX = centerX;
      var bottomLeftCurveStartY = balloonBottomY;

      var bottomLeftCurveEndX = centerX - radius;
      var bottomLeftCurveEndY = centerY;

      p.cubicTo(bottomLeftCurveStartX - handleLength, bottomLeftCurveStartY,
          bottomLeftCurveEndX, bottomLeftCurveEndY + handleLength,
          bottomLeftCurveEndX, bottomLeftCurveEndY);

      // Create balloon gradient

      var gradientOffset = (radius/3);

      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
            colors: [
              balloon.color.darkenAmount(0.2).withOpacity(0.7),
              balloon.color.lightenAmount(0.1).withOpacity(0.7)
            ],
            stops: [0, 0.7]
        ).createShader(Rect.fromCircle(center: Offset(centerX + gradientOffset, centerY - gradientOffset), radius: radius * 8))
      );

      // End balloon path

      // Create balloon tie

      var halfTieWidth = (radius * TIE_WIDTH_FACTOR)/2;
      var tieHeight = (radius * TIE_HEIGHT_FACTOR);
      var tieCurveHeight = (radius * TIE_CURVE_FACTOR);

      Path p2 = Path();
      p2.moveTo(centerX - 1, balloonBottomY);
      p2.lineTo(centerX - halfTieWidth, balloonBottomY + tieHeight);
      p2.quadraticBezierTo(centerX, balloonBottomY + tieCurveHeight,
          centerX + halfTieWidth, balloonBottomY + tieHeight);
      p2.lineTo(centerX + 1, balloonBottomY);

      canvas.drawPath(p2, Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
            colors: [
              balloon.color.darkenAmount(0.2).withOpacity(0.7),
              balloon.color.lightenAmount(0.1).withOpacity(0.7)
            ],
            stops: [0, 0.7]
        ).createShader(Rect.fromCircle(center: Offset(centerX + gradientOffset, centerY - gradientOffset), radius: radius * 8))
      );

      // Create balloon string

      Path p3 = Path();
      p3.moveTo(centerX, balloonBottomY);
      p3.lineTo(centerX, balloonBottomY + radius * 3);

      canvas.drawPath(p3, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..blendMode = BlendMode.screen
        ..color = Colors.grey
      );
    }
  }
}

final kappa = (4 * (sqrt(2) - 1))/3;
const WIDTH_FACTOR = 0.0333;
const HEIGHT_FACTOR = 0.4;
const TIE_WIDTH_FACTOR = 0.12;
const TIE_HEIGHT_FACTOR = 0.10;
const TIE_CURVE_FACTOR = 0.13;
const GRADIENT_FACTOR = 0.3;
const GRADIENT_CIRCLE_RADIUS = 3;