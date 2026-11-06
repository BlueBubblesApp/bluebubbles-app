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
  /// IMCore's raw ids for those (tapbacks 2000-2007, removals 3000-3007, including emoji and sticker tapbacks), the
  /// legacy sticker and a poll vote, which has no bubble of its own and was kept with the reactions before app turns
  /// were told apart. Other types, like the iMessage app session links ([AppSessionTypes.UPDATE] and
  /// [AppSessionTypes.SUPERSEDED]), are messages in their own right.
  static final List<String> associatedTypes = [
    ...toList(),
    ...toList().map((e) => "-$e"),
    for (int i = 0; i <= 7; i++) ...["${2000 + i}", "${3000 + i}"],
    "sticker",
    "1000",
    AppSessionTypes.POLL_VOTE,
  ];

  static bool isReactionType(String? type) => associatedTypes.contains(type);
}

/// How iMessage apps link the messages of one session (a game, a poll) through the associated message columns.
/// Every turn after the first is [UPDATE], pointing at the session's first message; Messages rewrites a turn a newer
/// one replaced to [SUPERSEDED], the first turn pointing at itself.
class AppSessionTypes {
  // ignore: non_constant_identifier_names
  static const String UPDATE = "2";
  // ignore: non_constant_identifier_names
  static const String SUPERSEDED = "3";

  /// One participant's vote on a poll, pointing at the poll's latest state
  // ignore: non_constant_identifier_names
  static const String POLL_VOTE = "4000";

  /// In the balloon bundle id of every iMessage app message, and of no built-in balloon
  static const String extensionBalloonPlugin = "MSMessageExtensionBalloonPlugin";

  /// Matched on the suffix: the team id in the middle belongs to the developer and can change.
  static const String _gamePigeonSuffix = ":com.gamerdelights.gamepigeon.ext";

  static bool isAppBalloon(String? balloonBundleId) => balloonBundleId?.contains(extensionBalloonPlugin) ?? false;

  static bool isGamePigeon(String? balloonBundleId) => balloonBundleId?.endsWith(_gamePigeonSuffix) ?? false;

  /// Whether [turn] replaces the earlier turns of its session, which are then [isReplacedBy] it. GamePigeon only: a
  /// poll keeps every state it was re-sent in as an [UPDATE] (its votes name the latest), and other apps are unmeasured.
  static bool replacesEarlierTurns(Message turn) =>
      isGamePigeon(turn.balloonBundleId) &&
      turn.associatedMessageType == UPDATE &&
      turn.associatedMessageGuid != null &&
      turn.guid != null &&
      turn.dateCreated != null;

  /// Whether [earlier] is a turn of [turn]'s session that [turn] replaced: the session's first message or another
  /// [UPDATE] to it, from the same app and sent before. Never a reaction (a tapback or sticker on the first message
  /// points at it too) and never one already [SUPERSEDED].
  static bool isReplacedBy(Message earlier, Message turn) {
    final first = turn.associatedMessageGuid;
    if (earlier.guid == null || earlier.guid == turn.guid) return false;
    if (earlier.guid != first && earlier.associatedMessageGuid != first) return false;
    final type = earlier.associatedMessageType;
    if (type != null && type != UPDATE) return false;
    if (earlier.guid != first && type != UPDATE) return false;
    final sameApp = earlier.balloonBundleId == turn.balloonBundleId ||
        (isGamePigeon(earlier.balloonBundleId) && isGamePigeon(turn.balloonBundleId));
    if (!sameApp) return false;
    return earlier.dateCreated != null && earlier.dateCreated!.isBefore(turn.dateCreated!);
  }

  /// The type to keep when a message typed [current] is replaced by one typed [incoming]. Messages never takes a
  /// replaced app turn back, so a [SUPERSEDED] turn stays one when a stale copy still says [UPDATE] (or nothing).
  static String? mergedType(String? balloonBundleId, String? current, String? incoming) {
    if (current == SUPERSEDED && isAppBalloon(balloonBundleId) && (incoming == null || incoming == UPDATE)) {
      return current;
    }
    return incoming ?? current;
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
      if (!ReactionTypes.isRemoval(msg.associatedMessageType) && ReactionTypes.isTapback(msg)) {
        output.add(msg);
      }
    } else if (kIsWeb && !ReactionTypes.isRemoval(msg.associatedMessageType) && ReactionTypes.isTapback(msg)) {
      output.add(msg);
    }
  }

  return output;
}
