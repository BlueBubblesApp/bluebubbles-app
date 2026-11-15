import 'dart:io';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Composer actions that can sit to the left of the conversation text field.
///
/// Order and visibility live in `SettingsSvc.settings.textFieldButtons` (see `settings.dart`), rendered by
/// [TextFieldIconBar]. On desktop, every supported action that isn't in that list goes in the `+` menu
/// (`DesktopAttachmentMenu`) instead. The user arranges them on the composer itself: hold a row button to drag it,
/// drag menu items out onto the row, drop on `+` to move one into the menu. When adding a button, add an entry to
/// each map below, the menu's entry, and its handler in `AttachmentActions.run`.
/// The attachment (+) button is deliberately not here: it is always shown, always
/// first, and is not configurable.
enum TextFieldButton { Files, Genmoji, Stickers, Handwritten, Schedule, Location, Gif, Emoji }

const List<TextFieldButton> defaultTextFieldButtons = [
  TextFieldButton.Gif,
  TextFieldButton.Emoji,
  TextFieldButton.Location,
];

/// (android, windows, linux, web)
const Map<TextFieldButton, (bool, bool, bool, bool)> _buttonPlatformSupport = {
  TextFieldButton.Files: (false, true, true, false),
  TextFieldButton.Genmoji: (false, true, true, false),
  TextFieldButton.Stickers: (false, true, true, false),
  TextFieldButton.Handwritten: (false, true, true, false),
  TextFieldButton.Schedule: (false, true, true, false),
  TextFieldButton.Location: (false, true, false, false),
  TextFieldButton.Gif: (false, true, true, false),
  TextFieldButton.Emoji: (false, true, true, true),
};

const Map<TextFieldButton, String> _buttonToText = {
  TextFieldButton.Files: "Files",
  TextFieldButton.Genmoji: "Genmoji",
  TextFieldButton.Stickers: "Stickers",
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
  TextFieldButton.Stickers: (Icons.sticky_note_2_rounded, Icons.sticky_note_2_outlined),
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
    if (this == TextFieldButton.Stickers && !SettingsSvc.getServerDetails().supportsStickers) return false;
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

/// What follows the pointer while a composer button is dragged: [child], centred on the pointer. Pair it with
/// [pointerDragAnchorStrategy].
Widget centeredDragFeedback(Widget child) => Material(
  color: Colors.transparent,
  child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
);

/// Puts [b] at [index] of the composer row, from elsewhere in the row or from the `+` menu; no [index] appends it.
void moveTextFieldButton(TextFieldButton b, [int? index]) {
  final shown = SettingsSvc.settings.textFieldButtons.platformSupportedButtons;
  final from = shown.indexOf(b);
  var to = index ?? shown.length;
  if (from != -1 && from < to) to--;
  shown.remove(b);
  shown.insert(to.clamp(0, shown.length), b);
  _saveTextFieldButtons(shown);
}

/// Takes [b] out of the composer row, which puts it in the `+` menu.
void removeTextFieldButton(TextFieldButton b) =>
    _saveTextFieldButtons(SettingsSvc.settings.textFieldButtons.platformSupportedButtons..remove(b));

/// Saves [shown] as the row, with the saved buttons that can't show right now put back where they were. Genmoji
/// doesn't show before the server's details load, or on a server without it, and an edit that had nothing to do with
/// it shouldn't take it out of the row.
void _saveTextFieldButtons(List<TextFieldButton> shown) {
  final saved = SettingsSvc.settings.textFieldButtons;
  final out = [...shown];
  for (final (i, b) in saved.indexed) {
    if (b.isPlatformSupported || out.contains(b)) continue;
    // After the button it followed, or first
    final before = saved.take(i).lastWhereOrNull(out.contains);
    out.insert(before == null ? 0 : out.indexOf(before) + 1, b);
  }
  SettingsSvc.settings.setTextFieldButtons(out);
}
