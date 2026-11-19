import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/components/bb_emoji_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/sticker_library_dialog.dart';
import 'package:bluebubbles/models/library_sticker.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// What the tapback picker picked: an emoji, or with [stickers] a sticker from the Mac's library.
sealed class TapbackPick {}

class EmojiTapbackPick extends TapbackPick {
  EmojiTapbackPick(this.emoji);
  final String emoji;
}

class StickerTapbackPick extends TapbackPick {
  StickerTapbackPick(this.sticker);
  final LibrarySticker sticker;
}

/// Picks an emoji tapback, or with [stickers] a sticker tapback from a second tab. Resolves to null when dismissed.
Future<TapbackPick?> showEmojiTapbackPicker(BuildContext context, {bool stickers = false}) {
  if (stickers) unawaited(StickerLibrarySvc.sync());
  final colors = context.theme.colorScheme;
  // Same surface as the app's dialogs (showBBDialog)
  final background = colors.surfaceContainerHighest;
  // Fits short screens: the dialog's own insets take 48 of the height
  final height = min(420.0, MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical - 48);
  const tabBarHeight = 46.0;
  return showDialog<TapbackPick>(
    context: context,
    builder: (dialogContext) {
      final emojiPicker = buildBBEmojiPicker(
        context,
        height: stickers ? height - tabBarHeight : height,
        background: background,
        columns: 8,
        // Its picks are tapbacks: they go to the reaction recents, not the typed-emoji ones that tab shows
        showRecents: false,
        onPicked: (emoji) => Navigator.of(dialogContext).pop(EmojiTapbackPick(emoji)),
      );
      return Dialog(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 360,
          height: height,
          child: !stickers
              ? emojiPicker
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      SizedBox(
                        height: tabBarHeight,
                        child: TabBar(
                          indicatorColor: colors.primary,
                          labelColor: colors.primary,
                          unselectedLabelColor: colors.outline,
                          dividerColor: colors.outline.withValues(alpha: 0.2),
                          tabs: const [
                            Tab(icon: Icon(Icons.emoji_emotions_outlined), iconMargin: EdgeInsets.zero),
                            Tab(icon: Icon(Icons.sticky_note_2_outlined), iconMargin: EdgeInsets.zero),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            emojiPicker,
                            StickerLibraryView(
                              title: false,
                              onPicked: (sticker) => Navigator.of(dialogContext).pop(StickerTapbackPick(sticker)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
