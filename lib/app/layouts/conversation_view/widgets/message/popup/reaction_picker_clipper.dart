import 'dart:math';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

class ReactionPickerClipper extends CustomClipper<Path>{
  final Size messageSize;
  final bool isFromMe;
  const ReactionPickerClipper({required this.messageSize, required this.isFromMe});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width - 20, 0);
    path.arcToPoint(Offset(size.width, 20), radius: const Radius.circular(20));
    path.lineTo(size.width, size.height - 35);
    path.arcToPoint(Offset(size.width - 20, size.height - 15), radius: const Radius.circular(20));
    path.lineTo(20, size.height - 15);
    path.arcToPoint(Offset(0, size.height - 35), radius: const Radius.circular(20));
    path.lineTo(0, 20);
    path.arcToPoint(const Offset(20, 0), radius: const Radius.circular(20));
    path.lineTo(size.width - 20, 0);
    if (size.width > messageSize.width && ss.settings.skin.value == Skins.iOS) {
      if (isFromMe) {
        path.addArc(Rect.fromLTWH(size.width - messageSize.width, size.height - 22.5, 17.5, 17.5), 0, 2*pi);
        path.addArc(Rect.fromLTWH(size.width - messageSize.width - 5, size.height - 7.5, 7, 7), 0, 2*pi);
      } else {
        path.addArc(Rect.fromLTWH(messageSize.width - 20, size.height - 22.5, 17.5, 17.5), 0, 2*pi);
        path.addArc(Rect.fromLTWH(messageSize.width - 5, size.height - 7.5, 7, 7), 0, 2*pi);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant ReactionPickerClipper oldClipper) {
    return false;
  }
}