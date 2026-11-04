import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/widgets.dart';

/// The emoji pickers' typed-emoji recents (emoji_picker_flutter's own list in prefs), fed from outside the pickers
/// too: emoji typed or pasted into a sent message. Tapbacks keep their own list (PrefsSvc.messaging).
class RecentEmojis {
  // From the set the composer's picker shows, so an emoji added here keeps the name its search matches on
  static final Map<String, emoji_picker.Emoji> _byChar = {
    for (final category in emoji_picker.emojiSetEnglish)
      for (final emoji in category.emoji) emoji.emoji: emoji,
  };

  // Each update reads, changes and rewrites the whole list, so overlapping ones would drop entries
  static Future<void> _queue = Future.value();

  /// Moves [emojis] to the front of the recents, the first of them frontmost.
  static Future<void> add(Iterable<String> emojis) {
    final ordered = emojis.toSet().toList().reversed.toList();
    if (ordered.isEmpty) return _queue;
    return _queue = _queue.then((_) async {
      for (final emoji in ordered) {
        // With no picker on screen the throwaway key has nothing to refresh; the prefs write still happens
        await emoji_picker.EmojiPickerUtils().addEmojiToRecentlyUsed(
          key: GlobalKey<emoji_picker.EmojiPickerState>(),
          emoji: _byChar[emoji] ?? emoji_picker.Emoji(emoji, ''),
        );
      }
    }).catchError((Object e) => Logger.warn("Couldn't update recent emojis: $e", tag: "RecentEmojis"));
  }

  static Future<void> addFromText(String text) => add(emojiRegex.allMatches(text).map((m) => m[0]!));
}
