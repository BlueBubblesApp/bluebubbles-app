import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class MessageHelper {
  /// Removes duplicate associated message guids from a list of [associatedMessages]
  static List<Message> normalizedAssociatedMessages(List<Message> associatedMessages) {
    Set<String> guids = associatedMessages.map((e) => e.guid!).toSet();
    List<Message> normalized = [];

    for (Message message in associatedMessages.reversed.toList()) {
      if (!ReactionTypes.toList().contains(message.associatedMessageType)) {
        normalized.add(message);
      } else if (guids.remove(message.guid)) {
        normalized.add(message);
      }
    }
    return normalized;
  }

  static bool shouldShowBigEmoji(String text) {
    if (isNullOrEmptyString(text)) return false;
    if (emojiRegex.firstMatch(text) == null) return false;

    List<RegExpMatch> matches = emojiRegex.allMatches(text).toList();
    List<String> items = matches.map((m) => m.toString()).toList();

    String replaced = text.replaceAll(emojiRegex, "").replaceAll(String.fromCharCode(65039), "").trim();
    return items.length <= 3 && replaced.isEmpty;
  }

  static List<TextSpan> buildEmojiText(String text, TextStyle style, {TapGestureRecognizer? recognizer}) {
    if (!FilesystemSvc.fontExistsOnDisk.value) {
      return [
        TextSpan(
          text: text,
          style: style,
          recognizer: recognizer,
        )
      ];
    }

    List<RegExpMatch> matches = emojiRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: style,
          recognizer: recognizer,
        )
      ];
    }

    final children = <TextSpan>[];
    int previousEnd = 0;
    for (int i = 0; i < matches.length; i++) {
      // Before the emoji
      if (previousEnd <= matches[i].start) {
        String chunk = text.substring(previousEnd, matches[i].start);
        children.add(
          TextSpan(
            text: chunk,
            style: style,
            recognizer: recognizer,
          ),
        );
        previousEnd += chunk.length;
      }

      // The emoji
      String chunk = text.substring(matches[i].start, matches[i].end);

      // Add stringed emoji
      while (i + 1 < matches.length && matches[i + 1].start == matches[i].end) {
        chunk += text.substring(matches[++i].start, matches[i].end);
      }
      children.add(
        TextSpan(
          text: chunk,
          style: style.apply(fontFamily: "Apple Color Emoji"),
          recognizer: recognizer,
        ),
      );
      previousEnd += chunk.length;
    }
    if (previousEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(previousEnd),
        style: style,
        recognizer: recognizer,
      ));
    }

    return children;
  }
}
