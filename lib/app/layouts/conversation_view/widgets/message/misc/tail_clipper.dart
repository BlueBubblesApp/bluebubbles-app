import 'dart:math';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Whether a part's bubble visually joins the bubbles above / below it: the Material and Samsung multi-part
/// styling, where the author-edge corners between neighbouring parts tighten. The iOS skin never connects part
/// bubbles.
///
/// One rule for every bubble shape: [TailClipper] callers (text, attachments, edits) and the media collection
/// grid's silhouette. Position is decided by [MessageState.isLeadingMessagePart] /
/// [MessageState.isTrailingMessagePart], so a collapsed collection counts as covering its whole span.
abstract final class BubbleConnect {
  /// [part] joins the bubble below it (it isn't the message's trailing part).
  static bool lower(MessageState state, MessagePart part) => !CurrentSkin.iOS && !state.isTrailingMessagePart(part);

  /// [part] joins the bubble above it (it isn't the message's leading part).
  static bool upper(MessageState state, MessagePart part) => !CurrentSkin.iOS && !state.isLeadingMessagePart(part);
}

class TailClipper extends CustomClipper<Path> {
  final bool isFromMe;
  final bool showTail;
  final bool connectUpper;
  final bool connectLower;

  TailClipper({
    required this.isFromMe,
    required this.showTail,
    required this.connectUpper,
    required this.connectLower,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double r = min(size.height / 2, 22.0);
    final double start = isFromMe ? 0 : 10;
    final double end = isFromMe ? size.width - 10 : size.width;
    path.moveTo(start, r);
    if (!isFromMe && (showTail && SettingsSvc.settings.skin.value == Skins.iOS)) {
      path.lineTo(start, size.height - 10);
      path.arcToPoint(Offset(0, size.height), radius: const Radius.circular(10));
      // intersect slightly more than 45 deg on the arc
      path.arcToPoint(Offset(start + 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(start + 20, size.height), radius: const Radius.circular(20), clockwise: false);
    } else {
      if (connectLower && !isFromMe) {
        path.lineTo(start, size.height - 5);
        path.arcToPoint(Offset(start + 5, size.height), radius: const Radius.circular(5), clockwise: false);
      } else {
        path.lineTo(start, size.height - r);
        path.arcToPoint(Offset(start + r, size.height), radius: Radius.circular(r), clockwise: false);
      }
    }
    if (isFromMe && (showTail && SettingsSvc.settings.skin.value == Skins.iOS)) {
      path.lineTo(end - 20, size.height);
      // intersect slightly more than 45 deg on the arc
      path.arcToPoint(Offset(end - 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(size.width, size.height + 1), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(end, size.height - 10), radius: const Radius.circular(10));
    } else {
      if (connectLower && isFromMe) {
        path.lineTo(end - 5, size.height);
        path.arcToPoint(Offset(end, size.height - 5), radius: const Radius.circular(5), clockwise: false);
      } else {
        path.lineTo(end - r, size.height);
        path.arcToPoint(Offset(end, size.height - r), radius: Radius.circular(r), clockwise: false);
      }
    }
    if (connectUpper && SettingsSvc.settings.skin.value != Skins.iOS) {
      if (isFromMe) {
        path.lineTo(end, 5);
        path.arcToPoint(Offset(end - 5, 0), radius: const Radius.circular(5), clockwise: false);
        path.lineTo(start + r, 0);
        path.arcToPoint(Offset(start, r), radius: Radius.circular(r), clockwise: false);
      } else {
        path.lineTo(end, r);
        path.arcToPoint(Offset(end - r, 0), radius: Radius.circular(r), clockwise: false);
        path.lineTo(start + 5, 0);
        path.arcToPoint(Offset(start, 5), radius: const Radius.circular(5), clockwise: false);
      }
    } else {
      path.lineTo(end, r);
      path.arcToPoint(Offset(end - r, 0), radius: Radius.circular(r), clockwise: false);
      path.lineTo(start + r, 0);
      path.arcToPoint(Offset(start, r), radius: Radius.circular(r), clockwise: false);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TailClipper oldClipper) {
    return showTail != oldClipper.showTail;
  }
}

class TailPainter extends CustomPainter {
  final bool isFromMe;
  final bool showTail;
  final Color color;
  final double? width;

  TailPainter({
    required this.isFromMe,
    required this.showTail,
    required this.color,
    this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = width ?? 3;

    final path = Path();
    final double r = min(size.height / 2, 22.0);
    final double start = isFromMe ? 0 : 10;
    final double end = isFromMe ? size.width - 10 : size.width;
    path.moveTo(start, r);
    if (!isFromMe && (showTail && SettingsSvc.settings.skin.value == Skins.iOS)) {
      path.lineTo(start, size.height - 10);
      path.arcToPoint(Offset(0, size.height), radius: const Radius.circular(10));
      path.arcToPoint(Offset(start + 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(start + 20, size.height), radius: const Radius.circular(20), clockwise: false);
    } else {
      path.lineTo(start, size.height - r);
      path.arcToPoint(Offset(start + r, size.height), radius: Radius.circular(r), clockwise: false);
    }
    final bool isFromMeTail = isFromMe && showTail && SettingsSvc.settings.skin.value == Skins.iOS;
    if (isFromMeTail) {
      path.lineTo(end - 20, size.height);
      path.arcToPoint(Offset(end - 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(size.width, size.height + 1), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(end, size.height - 10), radius: const Radius.circular(10));
    } else {
      path.lineTo(end - r, size.height);
      path.arcToPoint(Offset(end, size.height - r), radius: Radius.circular(r), clockwise: false);
    }
    path.lineTo(end, r);
    path.arcToPoint(Offset(end - r, 0), radius: Radius.circular(r), clockwise: false);
    path.lineTo(start + r, 0);
    path.arcToPoint(Offset(start, r), radius: Radius.circular(r), clockwise: false);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TailPainter oldDelegate) {
    return showTail != oldDelegate.showTail;
  }
}
