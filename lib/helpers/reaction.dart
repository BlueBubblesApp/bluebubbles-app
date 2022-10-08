import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:emojis/emojis.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ReactionTypes {
  // ignore: non_constant_identifier_names
  static final String LOVE = "love";

  // ignore: non_constant_identifier_names
  static final String LIKE = "like";

  // ignore: non_constant_identifier_names
  static final String DISLIKE = "dislike";

  // ignore: non_constant_identifier_names
  static final String LAUGH = "laugh";

  // ignore: non_constant_identifier_names
  static final String EMPHASIZE = "emphasize";

  // ignore: non_constant_identifier_names
  static final String QUESTION = "question";

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
    LOVE: Emojis.redHeart,
    LIKE: Emojis.thumbsUp,
    DISLIKE: Emojis.thumbsDown,
    LAUGH: Emojis.faceWithTearsOfJoy,
    EMPHASIZE: Emojis.redExclamationMark,
    QUESTION: Emojis.redQuestionMark,
  };

  static final Map<String, String> emojiToReaction = {
    Emojis.redHeart: LOVE,
    Emojis.thumbsUp: LIKE,
    Emojis.thumbsDown: DISLIKE,
    Emojis.faceWithTearsOfJoy: LAUGH,
    Emojis.redExclamationMark: EMPHASIZE,
    Emojis.redQuestionMark: QUESTION,
  };
}

class Reaction {
  final String reactionType;

  List<Message> messages = [];

  Reaction({required this.reactionType});

  static List<Message> getUniqueReactionMessages(List<Message> messages) {
    List<int> handleCache = [];
    List<Message> current = messages;
    List<Message> output = [];

    // Sort the messages, putting the latest at the top
    current.sort((a, b) => -a.dateCreated!.compareTo(b.dateCreated!));

    // Iterate over the messages and insert the latest reaction for each user
    for (Message msg in current) {
      int cache = msg.isFromMe! ? 0 : msg.handleId ?? 0;
      if (!handleCache.contains(cache) && !kIsWeb) {
        handleCache.add(cache);

        // Only add the reaction if it's not a "negative"
        if (msg.associatedMessageType != null && !msg.associatedMessageType!.startsWith("-")) {
          output.add(msg);
        }
      } else if (kIsWeb && msg.associatedMessageType != null && !msg.associatedMessageType!.startsWith("-")) {
        output.add(msg);
      }
    }

    return output;
  }

  static Map<String, Reaction> getLatestReactionMap(List<Message> messages) {
    Map<String, Reaction> reactions = {};
    reactions[ReactionTypes.LIKE] = Reaction(reactionType: ReactionTypes.LIKE);
    reactions[ReactionTypes.LOVE] = Reaction(reactionType: ReactionTypes.LOVE);
    reactions[ReactionTypes.DISLIKE] = Reaction(reactionType: ReactionTypes.DISLIKE);
    reactions[ReactionTypes.QUESTION] = Reaction(reactionType: ReactionTypes.QUESTION);
    reactions[ReactionTypes.EMPHASIZE] = Reaction(reactionType: ReactionTypes.EMPHASIZE);
    reactions[ReactionTypes.LAUGH] = Reaction(reactionType: ReactionTypes.LAUGH);

    // Iterate over the messages and insert the latest reaction for each user
    for (Message msg in Reaction.getUniqueReactionMessages(messages)) {
      reactions[msg.associatedMessageType!]!.addMessage(msg);
    }

    return reactions;
  }

  bool hasReactions() {
    return messages.isNotEmpty;
  }

  void addMessage(Message message) {
    messages.add(message);
  }

  Widget? getSmallWidget(BuildContext context, {Message? message, bool bigPin = false, bool isReactionPicker = false, bool isSelected = false, double size = 28}) {
    if (messages.isEmpty && message == null) return null;
    if (messages.isEmpty && message != null) messages = [message];

    List<Widget> reactionList = [];

    for (int i = 0; i < messages.length; i++) {
      Color iconColor = isSelected ? context.theme.colorScheme.onBackground : context.theme.colorScheme.onPrimary;
      if (!messages[i].isFromMe!) {
        iconColor = context.theme.colorScheme.properOnSurface;
      }

      reactionList.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            (messages[i].isFromMe! && !isReactionPicker ? 5.0 : 0.0) + i.toDouble() * 10.0,
            bigPin || isReactionPicker ? 0 : 1.0,
            0,
            0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (bigPin)
                Positioned(
                  left: size * -0.24,
                  top: size,
                  child: Container(
                    height: size * 0.2,
                    width: size * 0.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: context.theme.colorScheme.properSurface,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 1.0,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              if (bigPin)
                Positioned(
                  top: size * 0.62,
                  left: size * -0.06,
                  child: Container(
                    height: size * 0.4,
                    width: size * 0.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: context.theme.colorScheme.properSurface,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 1.0,
                          color: Colors.black.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                height: size,
                width: size,
                margin: EdgeInsets.only(right: bigPin ? size * 0.4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: isReactionPicker
                      ? (isSelected ? context.theme.colorScheme.background : context.theme.colorScheme.primary)
                      : messages[i].isFromMe! ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
                  boxShadow: isReactionPicker
                      ? null
                      : [
                          BoxShadow(
                            blurRadius: 1.0,
                            color: Colors.black.withOpacity(0.8),
                          )
                        ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                          top: size * 0.29,
                          left: size * 0.25,
                          right: size * 0.25,
                          bottom: size * 0.25,
                        ),
                  child: getReactionIcon(reactionType, iconColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.passthrough,
      alignment: Alignment.centerLeft,
      children: reactionList,
    );
  }

  static Widget getReactionIcon(String? reactionType, Color iconColor, {bool usePink = true}) {
    return SvgPicture.asset(
      'assets/reactions/$reactionType-black.svg',
      color: reactionType == "love" && usePink ? Colors.pink : iconColor,
    );
  }
}
