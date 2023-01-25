import 'dart:math';

import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

class ReplyLineDecoration extends Decoration {
  final bool isFromMe;
  final bool connectUpper;
  final bool connectLower;
  final Color color;
  final BuildContext context;

  const ReplyLineDecoration({
    required this.isFromMe,
    required this.connectUpper,
    required this.connectLower,
    required this.color,
    required this.context,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return ReplyLinePainter(
      isFromMe: isFromMe,
      connectUpper: connectUpper,
      connectLower: connectLower,
      color: color,
      context: context,
    );
  }
}

class ReplyLinePainter extends BoxPainter {
  final bool isFromMe;
  final bool connectUpper;
  final bool connectLower;
  final Color color;
  final BuildContext context;

  const ReplyLinePainter({
    required this.isFromMe,
    required this.connectUpper,
    required this.connectLower,
    required this.color,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final _offset = offset + Offset(isFromMe ? 35 : 0, 0);
    final double radius = min(size.height / 2, 30);
    final paint = Paint();
    paint.color = color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;

    final path = Path();
    if (connectUpper) {
      if (!isFromMe) {
        path.moveTo(_offset.dx + size.width - 35, _offset.dy);
        path.lineTo(_offset.dx + size.width - 35, _offset.dy + (size.height / 2 - radius).clamp(0, double.infinity));
        final x = _offset.dx + size.width - 35 - radius;
        path.arcToPoint(Offset(x, _offset.dy + size.height / 2), clockwise: true, radius: Radius.circular(radius));
        path.lineTo(min(x, _offset.dx + ns.width(context) * MessageWidgetController.maxBubbleSizeFactor), _offset.dy + size.height / 2);
      } else {
        path.moveTo(_offset.dx, _offset.dy);
        path.lineTo(_offset.dx, _offset.dy + (size.height / 2 - radius).clamp(0, double.infinity));
        final x = _offset.dx + radius;
        path.arcToPoint(Offset(x, _offset.dy + size.height / 2), clockwise: false, radius: Radius.circular(radius));
        path.lineTo(max(x, _offset.dx + size.width - ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30), _offset.dy + size.height / 2);
      }
    }
    if (connectLower) {
      if (!isFromMe) {
        path.moveTo(_offset.dx + size.width - 35, _offset.dy + size.height);
        path.lineTo(_offset.dx + size.width - 35, _offset.dy + size.height - (size.height / 2 - radius).clamp(0, double.infinity));
        path.arcToPoint(Offset(_offset.dx + size.width - 35 - radius, _offset.dy + size.height / 2), clockwise: false, radius: Radius.circular(radius));
        path.lineTo(_offset.dx + ns.width(context) * MessageWidgetController.maxBubbleSizeFactor, _offset.dy + size.height / 2);
      } else {
        path.moveTo(_offset.dx, _offset.dy + size.height);
        path.lineTo(_offset.dx, _offset.dy + size.height - (size.height / 2 - radius).clamp(0, double.infinity));
        path.arcToPoint(Offset(_offset.dx + radius, _offset.dy + size.height / 2), clockwise: true, radius: Radius.circular(radius));
        path.lineTo(_offset.dx + size.width - ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30, _offset.dy + size.height / 2);
      }
    }

    canvas.drawPath(path, paint);
  }
}