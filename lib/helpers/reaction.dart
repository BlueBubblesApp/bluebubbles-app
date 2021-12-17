import 'package:bluebubbles/repository/models/models.dart';
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
      } else if (msg.associatedMessageType != null && !msg.associatedMessageType!.startsWith("-")) {
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

  Widget? getSmallWidget(BuildContext context, {Message? message, bool bigPin = false, bool isReactionPicker = true}) {
    if (messages.isEmpty && message == null) return null;
    if (messages.isEmpty && message != null) messages = [message];

    List<Widget> reactionList = [];

    for (int i = 0; i < messages.length; i++) {
      Color iconColor = Colors.white;
      if (!messages[i].isFromMe! && context.theme.colorScheme.secondary.computeLuminance() >= 0.179) {
        iconColor = Colors.black.withAlpha(95);
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
                  left: -6,
                  top: 24,
                  child: Container(
                    height: 5.5,
                    width: 5.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: context.theme.colorScheme.secondary,
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
                  top: 15.5,
                  left: -1.5,
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: context.theme.colorScheme.secondary,
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
                height: bigPin ? 25 : 28,
                width: bigPin ? 25 : 28,
                margin: EdgeInsets.only(right: bigPin ? 10 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: messages[i].isFromMe! ? context.theme.primaryColor : context.theme.colorScheme.secondary,
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
                  padding: bigPin
                      ? const EdgeInsets.only(
                          top: 6.0,
                          left: 5.0,
                          right: 5.0,
                          bottom: 5.0,
                        )
                      : const EdgeInsets.only(
                          top: 8.0,
                          left: 7.0,
                          right: 7.0,
                          bottom: 7.0,
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

  static Widget getReactionIcon(String? reactionType, Color iconColor) {
    return SvgPicture.asset(
      'assets/reactions/$reactionType-black.svg',
      color: reactionType == "love" ? Colors.pink : iconColor,
    );
  }
}
