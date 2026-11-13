import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Composer actions that can sit to the left of the conversation text field.
///
/// Order and visibility are user-configurable via
/// `SettingsSvc.settings.textFieldButtons` (see `settings.dart`), rendered by
/// [TextFieldIconBar]. On desktop, every supported action that isn't in that list goes in the
/// `+` menu (`DesktopAttachmentMenu`) instead. When adding a button, add an entry to each map
/// below, the menu's entry, and its handler in `AttachmentActions.run`.
/// The attachment (+) button is deliberately not here: it is always shown, always
/// first, and is not configurable.
enum TextFieldButton { Files, Genmoji, Handwritten, Schedule, Location, Gif, Emoji }

const List<TextFieldButton> defaultTextFieldButtons = [
  TextFieldButton.Gif,
  TextFieldButton.Emoji,
  TextFieldButton.Location,
];

/// (android, windows, linux, web)
const Map<TextFieldButton, (bool, bool, bool, bool)> _buttonPlatformSupport = {
  TextFieldButton.Files: (false, true, true, false),
  TextFieldButton.Genmoji: (false, true, true, false),
  TextFieldButton.Handwritten: (false, true, true, false),
  TextFieldButton.Schedule: (false, true, true, false),
  TextFieldButton.Location: (false, true, false, false),
  TextFieldButton.Gif: (false, true, true, false),
  TextFieldButton.Emoji: (false, true, true, true),
};

const Map<TextFieldButton, String> _buttonToText = {
  TextFieldButton.Files: "Files",
  TextFieldButton.Genmoji: "Genmoji",
  TextFieldButton.Handwritten: "Handwritten",
  TextFieldButton.Schedule: "Schedule",
  TextFieldButton.Location: "Location",
  TextFieldButton.Gif: "GIF",
  TextFieldButton.Emoji: "Emoji",
};

/// (iOS skin, other skins)
const Map<TextFieldButton, (IconData, IconData)> _buttonToIcon = {
  TextFieldButton.Files: (CupertinoIcons.folder_fill, Icons.folder_outlined),
  TextFieldButton.Genmoji: (Icons.add_reaction_rounded, Icons.add_reaction_outlined),
  TextFieldButton.Handwritten: (CupertinoIcons.scribble, Icons.draw_outlined),
  TextFieldButton.Schedule: (CupertinoIcons.clock_fill, Icons.schedule),
  TextFieldButton.Location: (CupertinoIcons.location_solid, Icons.location_on_outlined),
  TextFieldButton.Gif: (Icons.gif, Icons.gif),
  TextFieldButton.Emoji: (CupertinoIcons.smiley_fill, Icons.emoji_emotions),
};

extension TextFieldButtonExtension on TextFieldButton {
  String get label => _buttonToText[this]!;

  /// Follows the current skin, like the real buttons do
  IconData get icon =>
      SettingsSvc.settings.skin.value == Skins.iOS ? _buttonToIcon[this]!.$1 : _buttonToIcon[this]!.$2;

  bool get isPlatformSupported {
    if (this == TextFieldButton.Genmoji && !SettingsSvc.getServerDetails().supportsGenmoji) return false;
    final (android, windows, linux, web) = _buttonPlatformSupport[this]!;
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isWindows) return windows;
    return linux;
  }
}

extension TextFieldButtonListExtension on List<TextFieldButton> {
  List<TextFieldButton> get platformSupportedButtons => where((b) => b.isPlatformSupported).toList();

  bool get leavesMenuEmpty => TextFieldButton.values.platformSupportedButtons.every(contains);
}
