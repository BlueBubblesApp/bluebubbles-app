import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

extension MessageErrorExtension on MessageError {
  static const codes = {
    MessageError.NO_ERROR: 0,
    MessageError.TIMEOUT: 4,
    MessageError.NO_CONNECTION: 1000,
    MessageError.BAD_REQUEST: 1001,
    MessageError.SERVER_ERROR: 1002,
  };

  int get code => codes[this]!;
}

extension EffectHelper on MessageEffect {
  bool get isBubble => this == MessageEffect.slam || this == MessageEffect.loud || this == MessageEffect.gentle || this == MessageEffect.invisibleInk;

  bool get isScreen => !isBubble && this != MessageEffect.none;
}

extension WidgetLocation on GlobalKey {
  Rect? globalPaintBounds(BuildContext context) {
    double difference = context.width - ns.width(context);
    final renderObject = currentContext?.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      final tempRect = renderObject!.paintBounds.shift(offset);
      return Rect.fromLTRB(tempRect.left - difference, tempRect.top, tempRect.right - difference, tempRect.bottom);
    } else {
      return null;
    }
  }
}