import 'dart:math';
import 'package:flutter/material.dart';

class TypingClipper extends CustomClipper<Path>{
  const TypingClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width - 20, 0);
    path.arcToPoint(Offset(size.width - 20, 40), radius: const Radius.circular(20));
    path.lineTo(size.width * 0.2 + 20, 40);
    path.arcToPoint(Offset(size.width * 0.2 + 20, 0), radius: const Radius.circular(20));
    path.lineTo(size.width - 20, 0);
    path.addArc(Rect.fromLTWH(15, 24, size.height * 0.3, size.height * 0.3), 0, 2*pi);
    path.addArc(Rect.fromLTWH(7.5, size.height * 0.7, size.height * 0.15, size.height * 0.15), 0, 2*pi);
    return path;
  }

  @override
  bool shouldReclip(covariant TypingClipper oldClipper) {
    return false;
  }
}