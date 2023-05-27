import 'package:flutter/material.dart';

class FindMyLocationClipper extends CustomClipper<Path>{
  const FindMyLocationClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height / 2);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant FindMyLocationClipper oldClipper) {
    return true;
  }
}