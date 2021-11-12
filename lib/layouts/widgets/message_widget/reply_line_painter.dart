import 'dart:math';

import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Here's where the magic happens for drawing the reply lines between messages
class LinePainter extends CustomPainter {
  final BuildContext context;
  final Message msg;
  final Message? olderMsg;
  final Message? newerMsg;
  final Message threadOriginator;
  final Size upperSize;
  final Size size;
  // if there's a timestamp above and we need a connecting line, account for its size
  final bool extendPastTimestampAbove;
  // if there's a timestamp below and we need a connecting line, account for its size
  final bool extendPastTimestampBelow;
  // if theres a sender text and we need a connecting line, account for its size
  final bool extendPastSender;
  final double offset;

  LinePainter(
      this.context,
      this.msg,
      this.olderMsg,
      this.newerMsg,
      this.threadOriginator,
      this.upperSize,
      this.size,
      this.extendPastTimestampAbove,
      this.extendPastTimestampBelow,
      this.extendPastSender,
      this.offset,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = context.theme.dividerColor;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;

    final path = Path();
    final upperIsOriginator = msg.upperIsThreadOriginatorBubble(olderMsg);
    final connectUpper = msg.shouldConnectUpper(olderMsg, threadOriginator);
    final connectLower = msg.shouldConnectLower(olderMsg, newerMsg, threadOriginator);
    final lineType = msg.getLineType(olderMsg, threadOriginator);
    // draws a C shaped line
    if (lineType == LineType.meToMe) {
      // the upper portion can have a different width if the message is bigger
      // or smaller
      final topMaxWidth = min(CustomNavigator.width(context) - upperSize.width - 125, 150).toDouble() - offset;
      // if we are drawing to an originator bubble
      if (upperIsOriginator) {
        // draw the top line of the C
        path.moveTo(topMaxWidth, -upperSize.height / 2 - 8);
        path.lineTo(size.height / 2, -upperSize.height / 2 - 8);
        // add a rounded corner
        path.addArc(Rect.fromCenter(
          center: Offset(size.height / 2, -upperSize.height / 2 - 8 + size.height / 2),
          height: size.height,
          width: size.height,
        ), pi, pi / 2);
        // draw the vertical portion of the C
        path.moveTo(0, -upperSize.height / 2 - 8 + size.height / 2);
        path.lineTo(0, size.height / 2);
        // add a rounded corner
        path.addArc(Rect.fromCenter(
          center: Offset(size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), pi / 2, pi / 2);
        // draw the bottom part of the C
        path.moveTo(size.height / 2, size.height);
        path.lineTo(size.width, size.height);
        // if we are just drawing a connecting line, it will look like an L
      } else if (connectUpper) {
        // draw the vertical part of the L
        path.moveTo(0, -upperSize.height * 2 / 3 - 12 - (extendPastTimestampAbove ? 40 : 0));
        path.lineTo(0, size.height / 2);
        // add a rounded corner
        path.addArc(Rect.fromCenter(
          center: Offset(size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), pi / 2, pi / 2);
        // draw the bottom part of the L
        path.moveTo(size.height / 2, size.height);
        path.lineTo(size.width, size.height);
      }
      // if we are drawing a connecting line to a lower message
      if (connectLower) {
        // draw a straight line down from the left side of the C or the L
        path.moveTo(0, size.height / 2);
        path.lineTo(0, size.height * 2 + 8 + (extendPastTimestampBelow ? 40 : 0));
      }
      // draws a flipped C shape, same general method as the above but with
      // slightly different coordinates
    } else if (lineType == LineType.otherToOther) {
      final topMaxWidth = min(CustomNavigator.width(context) - upperSize.width - 125, 150).toDouble() - offset;
      if (upperIsOriginator) {
        path.moveTo(size.width - topMaxWidth, -upperSize.height / 2 - 8 - (extendPastSender ? 20 : 0));
        path.lineTo(size.width - size.height / 2, -upperSize.height / 2 - 8 - (extendPastSender ? 20 : 0));
        path.addArc(Rect.fromCenter(
          center: Offset(size.width - size.height / 2, -upperSize.height / 2 - 8 - (extendPastSender ? 20 : 0) + size.height / 2),
          height: size.height,
          width: size.height,
        ), 3 * pi / 2, pi / 2);
        path.moveTo(size.width, -upperSize.height / 2 - 8 - (extendPastSender ? 20 : 0) + size.height / 2);
        path.lineTo(size.width, size.height / 2);
        path.addArc(Rect.fromCenter(
          center: Offset(size.width - size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), 0, pi / 2);
        path.moveTo(size.width - size.height / 2, size.height);
        path.lineTo(0, size.height);
      } else if (connectUpper) {
        path.moveTo(size.width, -upperSize.height / 2 - 12 - (extendPastTimestampAbove ? 40 : 0) - (extendPastSender ? 20 : 0));
        path.lineTo(size.width, size.height / 2);
        path.addArc(Rect.fromCenter(
          center: Offset(size.width - size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), 0, pi / 2);
        path.moveTo(size.width - size.height / 2, size.height);
        path.lineTo(0, size.height);
      }
      if (connectLower) {
        path.moveTo(size.width, size.height / 2);
        path.lineTo(size.width, size.height * 2 + 8 + (extendPastTimestampBelow ? 40 : 0));
      }
      // draws an L shaped line from a message not from me, to a message from me
    } else if (lineType == LineType.otherToMe) {
      // if the bubble above is the originator or we just need to connect, it
      // should look the same
      if (upperIsOriginator || connectUpper) {
        // draw the vertical portion of the L
        path.moveTo(0, (extendPastTimestampAbove ? -40 : 0));
        path.lineTo(0, size.height / 2);
        // add a rounded corner
        path.addArc(Rect.fromCenter(
          center: Offset(size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), pi / 2, pi / 2);
        // add the bottom portion of the L
        path.moveTo(size.height / 2, size.height);
        path.lineTo(size.width, size.height);
      }
      // if we are drawing a connecting line to a lower message
      if (connectLower) {
        // draw straight down from the left side of the L
        path.moveTo(0, size.height / 2);
        path.lineTo(0, size.height * 2 + 8);
      }
      // draws a flipped L shape, same general method as the above but with
      // slightly different coordinates
    } else if (lineType == LineType.meToOther) {
      if (upperIsOriginator || connectUpper) {
        path.moveTo(size.width, (extendPastTimestampAbove ? -40 : 0)- (extendPastSender ? 20 : 0));
        path.lineTo(size.width, size.height / 2);
        path.addArc(Rect.fromCenter(
          center: Offset(size.width - size.height / 2, size.height / 2),
          height: size.height,
          width: size.height,
        ), 0, pi / 2);
        path.moveTo(size.width - size.height / 2, size.height);
        path.lineTo(0, size.height);
      }
      if (connectLower) {
        path.moveTo(size.width, size.height / 2);
        path.lineTo(size.width, size.height * 2 + 8);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}