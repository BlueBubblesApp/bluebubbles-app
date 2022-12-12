import 'dart:math';
import 'package:flutter/material.dart';

class ReactionClipper extends CustomClipper<Path>{
  final bool isFromMe;

  ReactionClipper({
    required this.isFromMe,
  });

  @override
  Path getClip(Size size) {
    final square = size.width;
    final path = Path();
    if (!isFromMe) {
      path.addArc(Rect.fromLTWH(0, 0, square * 0.8, square * 0.8), 0, 2*pi);
      path.addArc(Rect.fromLTWH(square * 0.55, square * 0.55, square * 0.3, square * 0.3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(square * 0.825, square * 0.825, square * 0.175, square * 0.175), 0, 2*pi);
    } else {
      path.addArc(Rect.fromLTWH(square * 0.2, 0, square * 0.8, square * 0.8), 0, 2*pi);
      path.addArc(Rect.fromLTWH(square * 0.2, square * 0.55, square * 0.3, square * 0.3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(0, square * 0.825, square * 0.175, square * 0.175), 0, 2*pi);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionClipper oldClipper) {
    return false;
  }
}

class ReactionBorderClipper extends CustomClipper<Path>{
  final bool isFromMe;

  ReactionBorderClipper({
    required this.isFromMe,
  });

  @override
  Path getClip(Size size) {
    final square = size.width - 2;
    final path = Path();
    if (!isFromMe) {
      path.addArc(Rect.fromLTWH(0, 0, square * 0.8 + 3, square * 0.8 + 3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(square * 0.55, square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(square * 0.825 + 0.5, square * 0.825 + 0.5, square * 0.175 + 2.5, square * 0.175 + 2.5), 0, 2*pi);
    } else {
      path.addArc(Rect.fromLTWH(size.width - (square * 0.8 + 3), 0, square * 0.8 + 3, square * 0.8 + 3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(size.width - (square * 0.8 + 3), square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2*pi);
      path.addArc(Rect.fromLTWH(0, square * 0.825 + 1, square * 0.175 + 1.5, square * 0.175 + 1.5), 0, 2*pi);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionBorderClipper oldClipper) {
    return false;
  }
}