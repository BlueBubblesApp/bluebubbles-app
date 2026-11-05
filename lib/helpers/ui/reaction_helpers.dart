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

  // Servers send these as IMCore's raw type ids, with the emoji in associatedMessageEmoji
  // ignore: non_constant_identifier_names
  static const String EMOJI = "2006";
  // ignore: non_constant_identifier_names
  static const String REMOVED_EMOJI = "3006";

  // The sticker is the tapback message's attachment
  // ignore: non_constant_identifier_names
  static const String STICKER = "2007";
  // ignore: non_constant_identifier_names
  static const String REMOVED_STICKER = "3007";

  static bool isEmojiTapback(String? type) => type == EMOJI || type == REMOVED_EMOJI;

  /// What `/message/react` takes for [type]: emoji tapbacks are `emoji` / `-emoji` with the emoji sent beside it.
  static String wireReaction(String type) => !isEmojiTapback(type) ? type : (type == EMOJI ? "emoji" : "-emoji");

  static bool isStickerTapback(String? type) => type == STICKER || type == REMOVED_STICKER;

  static bool isRemoval(String? type) =>
      type != null && (type.startsWith("-") || type == REMOVED_EMOJI || type == REMOVED_STICKER);

  static bool isTapbackType(String? type) =>
      isEmojiTapback(type) || isStickerTapback(type) || toList().contains(type?.replaceAll("-", ""));

  /// Whether [message] is a tapback we can draw. Emoji tapbacks synced before the client stored the emoji stay hidden
  /// until the backfill fills it in. Pick each sender's latest with [isTapbackType] first, so a hidden one still
  /// replaces their earlier tapback.
  static bool isTapback(Message message) {
    final type = message.associatedMessageType;
    if (isEmojiTapback(type)) return message.associatedMessageEmoji?.isNotEmpty ?? false;
    return isTapbackType(type);
  }

  static String emojiFor(Message message) =>
      message.associatedMessageEmoji ?? reactionToEmoji[message.associatedMessageType] ?? "X";

  static String? verbFor(Message message) {
    final type = message.associatedMessageType;
    if (isStickerTapback(type)) return type == STICKER ? "reacted with a sticker to" : "removed a sticker from";
    if (!isEmojiTapback(type)) return reactionToVerb[type];
    // Synced before the server sent the emoji; the backfill fills it in
    final emoji = message.associatedMessageEmoji;
    if (emoji == null) return type == EMOJI ? "reacted to" : "removed a reaction from";
    return type == EMOJI ? "reacted $emoji to" : "removed $emoji from";
  }

  /// Every associated message type that's a reaction to another message: the tapbacks and their removals by name,
  /// IMCore's raw ids for those (tapbacks 2000-2007, removals 3000-3007, including emoji and sticker tapbacks) and
  /// the legacy sticker. Other types, like the iMessage app session links (2 and 3), are messages in their own right.
  static final List<String> associatedTypes = [
    ...toList(),
    ...toList().map((e) => "-$e"),
    for (int i = 0; i <= 7; i++) ...["${2000 + i}", "${3000 + i}"],
    "sticker",
    "1000",
  ];

  static bool isReactionType(String? type) => associatedTypes.contains(type);
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
      if (!ReactionTypes.isRemoval(msg.associatedMessageType) && ReactionTypes.isTapback(msg)) {
        output.add(msg);
      }
    } else if (kIsWeb && !ReactionTypes.isRemoval(msg.associatedMessageType) && ReactionTypes.isTapback(msg)) {
      output.add(msg);
    }
  }

  return output;
}
