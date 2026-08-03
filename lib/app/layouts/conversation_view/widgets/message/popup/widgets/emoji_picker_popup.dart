import 'dart:ui';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmojiPickerPopup extends StatelessWidget {
  const EmojiPickerPopup({
    super.key,
    required this.onEmojiSelected,
  });

  final Function(String emoji) onEmojiSelected;

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EmojiPickerPopup(
        onEmojiSelected: (emoji) => Navigator.of(context).pop(emoji),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = SettingsSvc.settings.skin.value;
    final isMaterial = skin == Skins.Material;
    final isIOS = skin == Skins.iOS;
    final isSamsung = skin == Skins.Samsung;

    final colorScheme = context.theme.colorScheme;
    final double sheetHeight = context.height * 0.45;

    Widget sheetContent = Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isIOS
            ? colorScheme.surface.withOpacity(0.85)
            : (isMaterial
                ? (colorScheme.surfaceContainer ?? colorScheme.surface)
                : colorScheme.surface),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isMaterial ? 28 : (isSamsung ? 24 : 16)),
        ),
        boxShadow: isIOS
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                onEmojiSelected(emoji.emoji);
              },
              config: Config(
                height: sheetHeight - 20,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: Colors.transparent,
                  columns: 8,
                  noRecents: Text(
                    "No Recents",
                    style: context.textTheme.bodyMedium!.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.searchBar,
                ),
                skinToneConfig: const SkinToneConfig(enabled: true),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: Colors.transparent,
                  dividerColor: isIOS
                      ? colorScheme.outline.withOpacity(0.2)
                      : Colors.transparent,
                  indicatorColor: colorScheme.primary,
                  iconColor: colorScheme.onSurfaceVariant,
                  iconColorSelected: colorScheme.primary,
                  categoryIcons: isIOS
                      ? const CategoryIcons(
                          recentIcon: CupertinoIcons.clock,
                          smileyIcon: CupertinoIcons.smiley,
                          animalIcon: CupertinoIcons.paw,
                          foodIcon: CupertinoIcons.heart,
                          activityIcon: CupertinoIcons.sportscourt,
                          travelIcon: CupertinoIcons.car_fill,
                          objectIcon: CupertinoIcons.lightbulb,
                          symbolIcon: CupertinoIcons.number,
                          flagIcon: CupertinoIcons.flag,
                        )
                      : const CategoryIcons(
                          recentIcon: Icons.access_time_filled_rounded,
                          smileyIcon: Icons.sentiment_satisfied_alt_rounded,
                          animalIcon: Icons.pets_rounded,
                          foodIcon: Icons.fastfood_rounded,
                          activityIcon: Icons.sports_soccer_rounded,
                          travelIcon: Icons.directions_car_rounded,
                          objectIcon: Icons.lightbulb_rounded,
                          symbolIcon: Icons.emoji_symbols_rounded,
                          flagIcon: Icons.flag_rounded,
                        ),
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  customBottomActionBar: (config, state, showSearchView) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: GestureDetector(
                        onTap: showSearchView,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isMaterial
                                ? (colorScheme.surfaceContainerHigh ?? colorScheme.surfaceContainerHighest)
                                : colorScheme.surfaceContainerHighest.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(isMaterial ? 22 : 12),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isIOS ? CupertinoIcons.search : Icons.search_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Search emojis",
                                style: context.textTheme.bodyMedium!.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: isMaterial
                      ? (colorScheme.surfaceContainer ?? colorScheme.surface)
                      : colorScheme.surface,
                  buttonIconColor: colorScheme.primary,
                  hintText: "Search emojis...",
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isIOS) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: sheetContent,
        ),
      );
    }

    return sheetContent;
  }
}
