import 'package:bluebubbles/database/models.dart' hide Entity;
import 'package:flutter/foundation.dart';

class ReactionTypes {
  // ignore: non_constant_identifier_names
  static const String LOVE = "love";
  // ignore: non_constant_identifier_names
  static const String LIKE = "like";
  // ignore: non_constant_identifier_names
  static const String DISLIKE = "dislike";
  // ignore: non_constant_identifier_names
  static const String LAUGH = "laugh";
  // ignore: non_constant_identifier_names
  static const String EMPHASIZE = "emphasize";
  // ignore: non_constant_identifier_names
  static const String QUESTION = "question";

  static List<String> toList() {
    return [
      LOVE,
      LIKE,
      DISLIKE,
      LAUGH,
      EMPHASIZE,
      QUESTION,
    ];
  }

  static final Map<String, String> reactionToVerb = {
    LOVE: "loved",
    LIKE: "liked",
    DISLIKE: "disliked",
    LAUGH: "laughed at",
    EMPHASIZE: "emphasized",
    QUESTION: "questioned",
    "-$LOVE": "removed a heart from",
    "-$LIKE": "removed a like from",
    "-$DISLIKE": "removed a dislike from",
    "-$LAUGH": "removed a laugh from",
    "-$EMPHASIZE": "removed an exclamation from",
    "-$QUESTION": "removed a question mark from",
  };

  static final Map<String, String> reactionToEmoji = {
    LOVE: "❤️",
    LIKE: "👍",
    DISLIKE: "👎",
    LAUGH: "😂",
    EMPHASIZE: "❗",
    QUESTION: "❓",
  };

  static final Map<String, String> emojiToReaction = {
    "❤️": LOVE,
    "👍": LIKE,
    "👎": DISLIKE,
    "😂": LAUGH,
    "❗": EMPHASIZE,
    "❓": QUESTION,
  };

  static bool isValidReaction(String? type, {String? emoji}) {
    if (emoji != null && emoji.isNotEmpty) return true;
    if (type == null || type.isEmpty) return false;
    final cleaned = type.startsWith("-") ? type.substring(1) : type;
    return toList().contains(cleaned);
  }

  static bool isEmojiReaction(String? emoji) {
    return emoji != null && emoji.isNotEmpty;
  }

  static String getReactionEmoji(String? type, {String? emoji}) {
    if (emoji != null && emoji.isNotEmpty) return emoji;
    if (type == null || type.isEmpty) return "";
    return reactionToEmoji[type] ?? type;
  }

  static String getReactionVerb(String? type, {String? emoji}) {
    if (emoji != null && emoji.isNotEmpty) {
      if (type != null && type.startsWith("-")) return "removed a $emoji reaction from";
      return "reacted $emoji to";
    }
    if (type == null || type.isEmpty) return "reacted to";
    if (reactionToVerb.containsKey(type)) return reactionToVerb[type]!;
    if (type.startsWith("-")) return "removed a ${type.substring(1)} reaction from";
    return "reacted to";
  }
}

List<Message> getUniqueReactionMessages(List<Message> messages) {
  List<int> handleCache = [];
  List<Message> output = [];
  // Sort the messages, putting the latest at the top
  final ids = messages.map((e) => e.guid).toSet();
  messages.retainWhere((element) => ids.remove(element.guid));
  messages.sort(Message.sort);
  // Iterate over the messages and insert the latest reaction for each user
  for (Message msg in messages) {
    int cache = msg.isFromMe! ? 0 : msg.handleId ?? 0;
    if (!handleCache.contains(cache) && !kIsWeb) {
      handleCache.add(cache);
      // Only add the reaction if it's not a "negative"
      if (!msg.associatedMessageType!.startsWith("-")) {
        output.add(msg);
      }
    } else if (kIsWeb && !msg.associatedMessageType!.startsWith("-")) {
      output.add(msg);
    }
  }

  return output;
}
