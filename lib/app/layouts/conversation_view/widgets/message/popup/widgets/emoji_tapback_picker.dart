import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Emoji;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Picks the emoji for an emoji tapback. Resolves to null when dismissed.
Future<String?> showEmojiTapbackPicker(BuildContext context) {
  final colors = context.theme.colorScheme;
  // Same surface as the app's dialogs (showBBDialog)
  final background = colors.surfaceContainerHighest;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        height: 420,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.of(dialogContext).pop(emoji.emoji),
          config: Config(
            height: 420,
            emojiSet: (_) => emojiSetEnglish,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28,
              backgroundColor: background,
              columns: 8,
              noRecents: Text("No Recents", style: context.textTheme.bodyLarge!.copyWith(color: colors.outline)),
            ),
            viewOrderConfig: const ViewOrderConfig(
              top: EmojiPickerItem.categoryBar,
              middle: EmojiPickerItem.emojiView,
              bottom: EmojiPickerItem.searchBar,
            ),
            skinToneConfig: const SkinToneConfig(enabled: false),
            // Its picks are tapbacks: they go to the reaction recents, not the typed-emoji ones this tab shows
            categoryViewConfig: CategoryViewConfig(
              recentTabBehavior: RecentTabBehavior.NONE,
              backgroundColor: background,
              dividerColor: colors.outline.withValues(alpha: 0.2),
              indicatorColor: colors.primary,
              iconColor: colors.outline,
              iconColorSelected: colors.primary,
              backspaceColor: colors.outline,
            ),
            // Search only: there's no text to backspace
            bottomActionBarConfig: BottomActionBarConfig(
              showBackspaceButton: false,
              backgroundColor: background,
              buttonColor: background,
              buttonIconColor: colors.outline,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: background,
              buttonIconColor: colors.outline,
              hintText: "Search emoji",
              hintTextStyle: context.textTheme.bodyLarge!.copyWith(color: colors.outline),
              inputTextStyle: context.textTheme.bodyLarge!.copyWith(color: colors.onSurface),
            ),
          ),
        ),
      ),
    ),
  );
}
