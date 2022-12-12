import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsLeadingIcon extends StatelessWidget {
  final IconData iosIcon;
  final IconData materialIcon;
  final Color? containerColor;

  const SettingsLeadingIcon({
    required this.iosIcon,
    required this.materialIcon,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Obx(() => Material(
          shape: ss.settings.skin.value == Skins.Samsung ? SquircleBorder(
            side: BorderSide(
                color: containerColor ?? context.theme.colorScheme.outline,
                width: 3.0
            ),
          ) : null,
          color: ss.settings.skin.value != Skins.Material
              ? containerColor ?? context.theme.colorScheme.outline
              : Colors.transparent,
          borderRadius: ss.settings.skin.value == Skins.iOS
              ? BorderRadius.circular(5) : null,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(ss.settings.skin.value == Skins.iOS ? iosIcon : materialIcon,
                  color: ss.settings.skin.value != Skins.Material ? Colors.white : context.theme.colorScheme.outline,
                  size: ss.settings.skin.value != Skins.Material ? 23 : 30),
            ),
          ),
        )),
      ],
    );
  }
}

class SquircleBorder extends ShapeBorder {
  final BorderSide side;
  final double superRadius;

  const SquircleBorder({
    this.side = BorderSide.none,
    this.superRadius = 5.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return SquircleBorder(
      side: side.scale(t),
      superRadius: superRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _squirclePath(rect.deflate(side.width), superRadius);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _squirclePath(rect, superRadius);
  }

  static Path _squirclePath(Rect rect, double superRadius) {
    final c = rect.center;
    final dx = c.dx * (1.0 / superRadius);
    final dy = c.dy * (1.0 / superRadius);
    return Path()
      ..moveTo(c.dx, 0.0)
      ..relativeCubicTo(c.dx - dx, 0.0, c.dx, dy, c.dx, c.dy)
      ..relativeCubicTo(0.0, c.dy - dy, -dx, c.dy, -c.dx, c.dy)
      ..relativeCubicTo(-(c.dx - dx), 0.0, -c.dx, -dy, -c.dx, -c.dy)
      ..relativeCubicTo(0.0, -(c.dy - dy), dx, -c.dy, c.dx, -c.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        var path = getOuterPath(rect.deflate(side.width / 2.0), textDirection: textDirection);
        canvas.drawPath(path, side.toPaint());
    }
  }
}
