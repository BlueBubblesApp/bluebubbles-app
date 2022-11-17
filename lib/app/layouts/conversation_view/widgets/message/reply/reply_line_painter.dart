import 'dart:math';

import 'package:flutter/material.dart';

class ReplyLinePainter extends CustomPainter {
  final bool isFromMe;
  final bool connectUpper;
  final Color color;

  const ReplyLinePainter({
    required this.isFromMe,
    required this.connectUpper,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;

    final path = Path();
    if (connectUpper) {
      if (!isFromMe) {
        path.moveTo(0, size.height);
        path.lineTo(size.width - min(size.height, 30), size.height);
        path.arcToPoint(Offset(size.width, size.height - min(size.height, 30)), clockwise: false, radius: Radius.circular(min(size.height, 30)));
        path.lineTo(size.width, 0);
      } else {
        path.moveTo(size.width, size.height);
        path.lineTo(min(size.height, 30), size.height);
        path.arcToPoint(Offset(0, size.height - min(size.height, 30)), clockwise: true, radius: Radius.circular(min(size.height, 30)));
        path.lineTo(0, 0);
      }
    } else {
      if (!isFromMe) {
        path.moveTo(0, 0);
        path.lineTo(size.width - min(size.height, 30), 0);
        path.arcToPoint(Offset(size.width, min(size.height, 30)), clockwise: true, radius: Radius.circular(min(size.height, 30)));
        path.lineTo(size.width, size.height);
      } else {
        path.moveTo(0, size.height);
        path.lineTo(0, min(size.height, 30));
        path.arcToPoint(Offset(min(size.height, 30), 0), clockwise: true, radius: Radius.circular(min(size.height, 30)));
        path.lineTo(size.width, 0);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}