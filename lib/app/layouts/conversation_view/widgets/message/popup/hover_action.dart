import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// Quick actions shown in the desktop hover bar beside a message (see `HoverReactionBar`).
///
/// Order and visibility are user-configurable via `SettingsSvc.settings.hoverActions` (see `settings.dart`),
/// edited in `HoverActionsPanel`. Each action is only shown on messages where it applies (e.g. tapbacks need
/// Private API and an iMessage chat). The "more" button that opens the full popup is always shown, always last,
/// and is not configurable. When adding an action, add an entry to [_hoverActionToText] and [_hoverActionToIcon],
/// plus its availability check and callback in `MessagePopupHolder`.
enum HoverAction { Tapbacks, Reply, Copy, CopySelection }

const Map<HoverAction, String> _hoverActionToText = {
  HoverAction.Tapbacks: "Tapbacks",
  HoverAction.Reply: "Reply",
  HoverAction.Copy: "Copy",
  HoverAction.CopySelection: "Copy Selection",
};

/// (iOS skin, other skins). Copy Selection uses a different icon than Copy on non-iOS skins (unlike the details
/// menu) because both can sit side by side in the bar.
const Map<HoverAction, (IconData, IconData)> _hoverActionToIcon = {
  HoverAction.Tapbacks: (CupertinoIcons.hand_thumbsup, Icons.add_reaction_outlined),
  HoverAction.Reply: (CupertinoIcons.reply, Icons.reply),
  HoverAction.Copy: (CupertinoIcons.doc_on_clipboard, Icons.content_copy),
  HoverAction.CopySelection: (CupertinoIcons.text_cursor, Icons.select_all),
};

/// Actions enabled by default: tapbacks only, so the bar stays compact unless the user opts into more.
const List<HoverAction> defaultHoverActions = [HoverAction.Tapbacks];

extension HoverActionExtension on HoverAction {
  String get label => _hoverActionToText[this]!;

  /// Follows the current skin
  IconData get icon =>
      SettingsSvc.settings.skin.value == Skins.iOS ? _hoverActionToIcon[this]!.$1 : _hoverActionToIcon[this]!.$2;
}
