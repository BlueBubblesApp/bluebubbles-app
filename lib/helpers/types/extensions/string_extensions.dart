import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

extension PlatformSpecificCapitalize on String {
  String get psCapitalize {
    if (ss.settings.skin.value == Skins.iOS) {
      return toUpperCase();
    } else {
      return this;
    }
  }
}

extension LastChars on String {
  String lastChars(int n) => substring(length - n);
}

extension IsEmoji on String {
  bool get hasEmoji {
    RegExp darkSunglasses = RegExp('\u{1F576}');
    return RegExp("${emojiRegex.pattern}|${darkSunglasses.pattern}").hasMatch(this);
  }
}

extension UrlParsing on String {
  bool get hasUrl => urlRegex.hasMatch(this) && !kIsWeb;
}