import 'dart:math' as math;

import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/widgets.dart';

/// Draws a circular animated progress bar.
class CircleProgressBar extends StatefulWidget {
  final Duration? animationDuration;
  final Color backgroundColor;
  final Color foregroundColor;
  final double value;

  const CircleProgressBar({
    Key? key,
    this.animationDuration,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.value,
  }) : super(key: key);

  @override
  CircleProgressBarState createState() {
    return CircleProgressBarState();
  }
}

class CircleProgressBarState extends State<CircleProgressBar> with SingleTickerProviderStateMixin {
  // Used in tweens where a backgroundColor isn't given.
  static const TRANSPARENT = Color(0x00000000);
  late AnimationController _controller;

  late Animation<double> curve;
  Tween<double>? valueTween;
  Tween<Color?>? backgroundColorTween;
  Tween<Color?>? foregroundColorTween;

  @override
  void initState() {
    super.initState();
    int duration = SettingsManager().settings.chunkSize.value;

    // Don't go lower than 200 ms or higher than 800
    // These are arbitrary, but just what I found worked best
    // What works best may vary depending on network speeds
    duration = duration.clamp(200, 800);

    _controller = AnimationController(
      duration: widget.animationDuration ?? Duration(milliseconds: duration),
      vsync: this,
    );

    curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Build the initial required tweens.
    valueTween = Tween<double>(
      begin: 0,
      end: widget.value,
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(CircleProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != oldWidget.value) {
      // Try to start with the previous tween's end value. This ensures that we
      // have a smooth transition from where the previous animation reached.
      double beginValue = valueTween?.evaluate(curve) ?? oldWidget.value;

      // Update the value tween.
      valueTween = Tween<double>(
        begin: beginValue,
        end: widget.value,
      );

      // Clear cached color tweens when the color hasn't changed.
      if (oldWidget.backgroundColor != widget.backgroundColor) {
        backgroundColorTween = ColorTween(
          begin: oldWidget.backgroundColor,
          end: widget.backgroundColor,
        );
      } else {
        backgroundColorTween = null;
      }

      if (oldWidget.foregroundColor != widget.foregroundColor) {
        foregroundColorTween = ColorTween(
          begin: oldWidget.foregroundColor,
          end: widget.foregroundColor,
        );
      } else {
        foregroundColorTween = null;
      }

      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: curve,
        child: Container(),
        builder: (context, child) {
          final backgroundColor = backgroundColorTween?.evaluate(curve) ?? widget.backgroundColor;
          final foregroundColor = foregroundColorTween?.evaluate(curve) ?? widget.foregroundColor;

          return CustomPaint(
            child: child,
            foregroundPainter: CircleProgressBarPainter(
              strokeWidth: 4,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              percentage: valueTween!.evaluate(curve),
            ),
          );
        },
      ),
    );
  }
}

// Draws the progress bar.
class CircleProgressBarPainter extends CustomPainter {
  final double percentage;
  final double strokeWidth;
  final Color backgroundColor;
  final Color foregroundColor;

  CircleProgressBarPainter({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.percentage,
    double? strokeWidth,
  }) : strokeWidth = strokeWidth ?? 6;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Size constrainedSize = size - Offset(strokeWidth, strokeWidth) as Size;
    final shortestSide = math.min(constrainedSize.width, constrainedSize.height);
    final foregroundPaint = Paint()
      ..color = foregroundColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final radius = (shortestSide / 2);

    // Start at the top. 0 radians represents the right edge
    final double startAngle = -(2 * math.pi * 0.25);
    final double sweepAngle = (2 * math.pi * percentage);

    // Don't draw the background if we don't have a background color
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    final oldPainter = (oldDelegate as CircleProgressBarPainter);
    return oldPainter.percentage != percentage ||
        oldPainter.backgroundColor != backgroundColor ||
        oldPainter.foregroundColor != foregroundColor ||
        oldPainter.strokeWidth != strokeWidth;
  }
}
