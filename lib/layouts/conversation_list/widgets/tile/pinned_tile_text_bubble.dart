import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PinnedTileTextBubble extends StatelessWidget {
  PinnedTileTextBubble({
    Key? key,
    required this.chat,
    required this.size,
  }) : super(key: key);

  final Chat chat;
  final double size;
  final bool leftSide = Random().nextBool();

  bool get showTail => !chat.isGroup();

  List<Color> getBubbleColors(Message message, BuildContext context) {
    List<Color> bubbleColors = [context.theme.colorScheme.properSurface, context.theme.colorScheme.properSurface];
    if (SettingsManager().settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColors = toColorGradient(message.handle?.address);
      } else {
        bubbleColors = [
          HexColor(message.handle!.color!),
          HexColor(message.handle!.color!).lightenAmount(0.075),
        ];
      }
    }
    return bubbleColors;
  }

  @override
  Widget build(BuildContext context) {

    final hideInfo = SettingsManager().settings.redactedMode.value
        && SettingsManager().settings.hideMessageContent.value;
    final generateContent = SettingsManager().settings.redactedMode.value
        && SettingsManager().settings.generateFakeMessageContent.value;

    if (hideInfo || !(chat.hasUnreadMessage ?? false)) return const SizedBox.shrink();

    final lastMessage = chat.latestMessageGetter;
    String messageText = lastMessage == null ? '' : MessageHelper.getNotificationText(lastMessage);
    if (generateContent) messageText = chat.fakeLatestMessageText ?? "";

    if (lastMessage?.associatedMessageGuid != null
        || (lastMessage?.isFromMe ?? false)
        || isNullOrEmpty(messageText, trimString: true)!) {
      return const SizedBox.shrink();
    }

    final background = SettingsManager().settings.colorfulBubbles.value && lastMessage != null
        ? getBubbleColors(lastMessage, context).first.withOpacity(0.7)
        : context.theme.colorScheme.bubble(context, chat.isIMessage).withOpacity(0.6);

    return Align(
      alignment: showTail
          ? leftSide
          ? Alignment.centerLeft
          : Alignment.centerRight
          : Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(
          left: showTail
              ? leftSide
              ? size * 0.06
              : size * 0.02
              : size * 0.04,
          right: showTail
              ? leftSide
              ? size * 0.02
              : size * 0.06
              : size * 0.04,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (showTail)
              Positioned(
                top: -size * 0.08,
                right: leftSide ? null : size * 0.08,
                left: leftSide ? size * 0.08 : null,
                child: CustomPaint(
                  size: Size(size * 0.21, size * 0.105),
                  painter: TailPainter(leftSide: leftSide, background: background),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: showTail ? size * 0.5 : 0),
              child: ClipRRect(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(10.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3.0,
                      horizontal: 6.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      color: background,
                    ),
                    child: Text(
                      messageText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: size ~/ 30,
                      textAlign: TextAlign.center,
                      style: context.theme.textTheme.bodySmall!.copyWith(
                          color: context.theme.colorScheme.onBubble(context, chat.isIMessage)
                              .withOpacity(SettingsManager().settings.colorfulBubbles.value ? 1 : 0.85)
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TailPainter extends CustomPainter {
  TailPainter({
    Key? key,
    required this.leftSide,
    required this.background,
  });

  final bool leftSide;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = background;
    Path path = Path();

    if (leftSide) {
      path.moveTo(size.width * 0.9355556, size.height * 0.1489091);
      path.cubicTo(size.width, size.height * 0.3262727, size.width * 0.6313889, size.height * 0.5667273,
          size.width * 0.7722222, size.height * 0.8181818);
      path.cubicTo(size.width * 0.8054444, size.height * 0.8875455, size.width * 0.9209444, size.height, size.width,
          size.height);
      path.cubicTo(size.width * 0.7504167, size.height, size.width * 0.2523611, size.height, 0, size.height);
      path.cubicTo(size.width * 0.2253889, size.height * 0.9245455, size.width * 0.2102778, size.height * 0.6476364,
          size.width * 0.5255556, size.height * 0.3018182);
      path.cubicTo(size.width * 0.7247778, size.height * 0.0966364, size.width * 0.8862222, size.height * 0.0308182,
          size.width * 0.9355556, size.height * 0.1489091);
      path.close();
    } else {
      path.moveTo(size.width * 0.0644444, size.height * 0.1489091);
      path.cubicTo(0, size.height * 0.3262727, size.width * 0.3686111, size.height * 0.5667273, size.width * 0.2277778,
          size.height * 0.8181818);
      path.cubicTo(
          size.width * 0.1945556, size.height * 0.8875455, size.width * 0.0790556, size.height, 0, size.height);
      path.cubicTo(size.width * 0.2495833, size.height, size.width * 0.7476389, size.height, size.width, size.height);
      path.cubicTo(size.width * 0.7746111, size.height * 0.9245455, size.width * 0.7987222, size.height * 0.6476364,
          size.width * 0.4744444, size.height * 0.3018182);
      path.cubicTo(size.width * 0.2752222, size.height * 0.0966364, size.width * 0.1137778, size.height * 0.0308182,
          size.width * 0.0644444, size.height * 0.1489091);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    final oldPainter = oldDelegate as TailPainter;
    return leftSide != oldPainter.leftSide || background != oldPainter.background;
  }
}
