import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Emoji;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The app's emoji picker: categories on top, emoji, then a "Search..." row, themed from [context] over
/// [background]. The composer's popover and the tapback picker differ only in these parameters.
///
/// [showRecents] shows the Recents tab (`RecentEmojis`' typed-emoji recents); tapbacks keep their own recents, so the
/// tapback picker leaves it off.
Widget buildBBEmojiPicker(
  BuildContext context, {
  required double height,
  required Color background,
  required int columns,
  required ValueChanged<String> onPicked,
  bool showRecents = true,
}) {
  final colors = context.theme.colorScheme;
  final outline = colors.outline;
  final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
  return EmojiPicker(
    onEmojiSelected: (_, emoji) => onPicked(emoji.emoji),
    config: Config(
      height: height,
      emojiSet: (_) => emojiSetEnglish,
      checkPlatformCompatibility: true,
      emojiViewConfig: EmojiViewConfig(
        emojiSizeMax: 28,
        backgroundColor: background,
        columns: columns,
        noRecents: Text("No Recents", style: context.textTheme.bodyLarge!.copyWith(color: outline)),
      ),
      viewOrderConfig: const ViewOrderConfig(
        top: EmojiPickerItem.categoryBar,
        middle: EmojiPickerItem.emojiView,
        bottom: EmojiPickerItem.searchBar,
      ),
      skinToneConfig: const SkinToneConfig(enabled: false),
      categoryViewConfig: CategoryViewConfig(
        recentTabBehavior: showRecents ? RecentTabBehavior.RECENT : RecentTabBehavior.NONE,
        backgroundColor: background,
        dividerColor: outline.withValues(alpha: 0.2),
        indicatorColor: colors.primary,
        iconColor: outline,
        iconColorSelected: colors.primary,
        backspaceColor: outline,
      ),
      // Search only: the picker never edits text itself, so there's nothing to backspace
      bottomActionBarConfig: BottomActionBarConfig(
        customBottomActionBar: (config, state, showSearchView) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showSearchView,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(iOS ? CupertinoIcons.search : Icons.search, color: outline),
                  const SizedBox(width: 8),
                  Text("Search...", style: context.theme.textTheme.bodyLarge!.copyWith(color: outline)),
                ],
              ),
            ),
          ),
        ),
      ),
      searchViewConfig: SearchViewConfig(
        backgroundColor: background,
        buttonIconColor: outline,
        hintText: "Search emoji",
        hintTextStyle: context.textTheme.bodyLarge!.copyWith(color: outline),
        inputTextStyle: context.textTheme.bodyLarge!.copyWith(color: colors.onSurface),
      ),
    ),
  );
}
