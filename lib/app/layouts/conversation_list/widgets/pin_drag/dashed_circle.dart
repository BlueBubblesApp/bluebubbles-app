import 'dart:math';

import 'package:flutter/material.dart';

class DashedCirclePainter extends CustomPainter {
  const DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashes = 24;
    const sweep = 2 * pi / dashes;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter old) => old.color != color;
}
