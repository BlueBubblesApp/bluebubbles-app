import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Buttons shown to the left of the conversation text field.
///
/// Order and visibility are user-configurable via
/// `SettingsSvc.settings.textFieldButtons` (see `settings.dart`), rendered by
/// [TextFieldIconBar]. When adding a button, add an entry to
/// [_buttonPlatformSupport] and [_buttonToText], plus the builder in the icon bar.
/// The attachment (+) button is deliberately not here — it is always shown, always
/// first, and is not configurable.
enum TextFieldButton { Gif, Emoji, Location }

/// (android, windows, linux, web)
const Map<TextFieldButton, (bool, bool, bool, bool)> _buttonPlatformSupport = {
  TextFieldButton.Gif: (false, true, true, false),
  TextFieldButton.Emoji: (false, true, true, true),
  TextFieldButton.Location: (false, true, false, false),
};

const Map<TextFieldButton, String> _buttonToText = {
  TextFieldButton.Gif: "GIF Picker",
  TextFieldButton.Emoji: "Emoji Picker",
  TextFieldButton.Location: "Send Location",
};

/// (iOS skin, other skins) — must match the icons the real buttons use
const Map<TextFieldButton, (IconData, IconData)> _buttonToIcon = {
  TextFieldButton.Gif: (Icons.gif, Icons.gif),
  TextFieldButton.Emoji: (CupertinoIcons.smiley_fill, Icons.emoji_emotions),
  TextFieldButton.Location: (CupertinoIcons.location_solid, Icons.location_on_outlined),
};

extension TextFieldButtonExtension on TextFieldButton {
  String get label => _buttonToText[this]!;

  /// Follows the current skin, like the real buttons do
  IconData get icon =>
      SettingsSvc.settings.skin.value == Skins.iOS ? _buttonToIcon[this]!.$1 : _buttonToIcon[this]!.$2;

  bool get isPlatformSupported {
    final (android, windows, linux, web) = _buttonPlatformSupport[this]!;
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isWindows) return windows;
    return linux;
  }
}

extension TextFieldButtonListExtension on List<TextFieldButton> {
  List<TextFieldButton> get platformSupportedButtons => where((b) => b.isPlatformSupported).toList();
}
