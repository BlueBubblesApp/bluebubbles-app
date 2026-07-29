import 'dart:math';
import 'package:flutter/material.dart';

/// Controls which side the reaction bubble's "tail" arcs point toward.
enum ReactionTailDirection { left, right }

/// Outward vs inward tail (inward used on stack cards).
enum ReactionTailType { standard, inside }

class ReactionClipper extends CustomClipper<Path> {
  final ReactionTailDirection tailDirection;
  final ReactionTailType tailType;

  ReactionClipper({
    required this.tailDirection,
    this.tailType = ReactionTailType.standard,
  });

  @override
  Path getClip(Size size) {
    final square = size.width;
    final path = Path();
    if (tailDirection == ReactionTailDirection.right) {
      path.addArc(Rect.fromLTWH(0, 0, square * 0.8, square * 0.8), 0, 2 * pi);
      if (tailType == ReactionTailType.inside) {
        path.addArc(Rect.fromLTWH(0, square * 0.55, square * 0.3, square * 0.3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(square * 0.157, square * 0.879, square * 0.175, square * 0.175), 0, 2 * pi);
      } else {
        path.addArc(Rect.fromLTWH(square * 0.55, square * 0.55, square * 0.3, square * 0.3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(square * 0.825, square * 0.825, square * 0.175, square * 0.175), 0, 2 * pi);
      }
    } else if (tailDirection == ReactionTailDirection.left) {
      path.addArc(Rect.fromLTWH(square * 0.2, 0, square * 0.8, square * 0.8), 0, 2 * pi);
      if (tailType == ReactionTailType.inside) {
        path.addArc(Rect.fromLTWH(square * 0.7, square * 0.55, square * 0.3, square * 0.3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(square * 0.668, square * 0.879, square * 0.175, square * 0.175), 0, 2 * pi);
      } else {
        path.addArc(Rect.fromLTWH(square * 0.2, square * 0.55, square * 0.3, square * 0.3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(0, square * 0.825, square * 0.175, square * 0.175), 0, 2 * pi);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionClipper oldClipper) {
    return oldClipper.tailDirection != tailDirection || oldClipper.tailType != tailType;
  }
}

class ReactionBorderClipper extends CustomClipper<Path> {
  final ReactionTailDirection tailDirection;
  final ReactionTailType tailType;

  ReactionBorderClipper({
    required this.tailDirection,
    this.tailType = ReactionTailType.standard,
  });

  @override
  Path getClip(Size size) {
    final square = size.width - 2;
    final path = Path();
    if (tailDirection == ReactionTailDirection.right) {
      path.addArc(Rect.fromLTWH(0, 0, square * 0.8 + 3, square * 0.8 + 3), 0, 2 * pi);
      if (tailType == ReactionTailType.inside) {
        path.addArc(Rect.fromLTWH(0, square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2 * pi);
        path.addArc(
            Rect.fromLTWH(square * 0.157 + 0.5, square * 0.879 + 0.5, square * 0.175 + 2.5, square * 0.175 + 2.5),
            0,
            2 * pi);
      } else {
        path.addArc(Rect.fromLTWH(square * 0.55, square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(square * 0.825 + 0.5, square * 0.825 + 0.5, square * 0.175 + 2.5, square * 0.175 + 2.5),
            0, 2 * pi);
      }
    } else if (tailDirection == ReactionTailDirection.left) {
      if (tailType == ReactionTailType.inside) {
        path.addArc(Rect.fromLTWH(square * 0.2, 0, square * 0.8 + 3, square * 0.8 + 3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(square * 0.7, square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2 * pi);
        path.addArc(
            Rect.fromLTWH(square * 0.668 + 0.5, square * 0.879 + 0.5, square * 0.175 + 2.5, square * 0.175 + 2.5),
            0,
            2 * pi);
      } else {
        path.addArc(Rect.fromLTWH(size.width - (square * 0.8 + 3), 0, square * 0.8 + 3, square * 0.8 + 3), 0, 2 * pi);
        path.addArc(
            Rect.fromLTWH(size.width - (square * 0.8 + 3), square * 0.55, square * 0.3 + 3, square * 0.3 + 3), 0, 2 * pi);
        path.addArc(Rect.fromLTWH(0, square * 0.825 + 1, square * 0.175 + 1.5, square * 0.175 + 1.5), 0, 2 * pi);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionBorderClipper oldClipper) {
    return oldClipper.tailDirection != tailDirection || oldClipper.tailType != tailType;
  }
}
