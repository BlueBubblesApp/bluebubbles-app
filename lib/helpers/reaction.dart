import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

class ReactionTypes {
  // ignore: non_constant_identifier_names
  static final String LIKE = "like";

  // ignore: non_constant_identifier_names
  static final String LOVE = "love";

  // ignore: non_constant_identifier_names
  static final String DISLIKE = "dislike";

  // ignore: non_constant_identifier_names
  static final String QUESTION = "question";

  // ignore: non_constant_identifier_names
  static final String EMPHASIZE = "emphasize";

  // ignore: non_constant_identifier_names
  static final String LAUGH = "laugh";

  static List<String> toList() {
    return [
      "love",
      "like",
      "dislike",
      "laugh",
      "emphasize",
      "question",
    ];
  }
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
      if (!handleCache.contains(cache)) {
        handleCache.add(cache);

        // Only add the reaction if it's not a "negative"
        if (msg.associatedMessageType != null && !msg.associatedMessageType!.startsWith("-")) output.add(msg);
      }
    }

    return output;
  }

  static Map<String, Reaction> getLatestReactionMap(List<Message> messages) {
    Map<String, Reaction> reactions = {};
    reactions[ReactionTypes.LIKE] = new Reaction(reactionType: ReactionTypes.LIKE);
    reactions[ReactionTypes.LOVE] = new Reaction(reactionType: ReactionTypes.LOVE);
    reactions[ReactionTypes.DISLIKE] = new Reaction(reactionType: ReactionTypes.DISLIKE);
    reactions[ReactionTypes.QUESTION] = new Reaction(reactionType: ReactionTypes.QUESTION);
    reactions[ReactionTypes.EMPHASIZE] = new Reaction(reactionType: ReactionTypes.EMPHASIZE);
    reactions[ReactionTypes.LAUGH] = new Reaction(reactionType: ReactionTypes.LAUGH);

    // Iterate over the messages and insert the latest reaction for each user
    for (Message msg in Reaction.getUniqueReactionMessages(messages)) {
      reactions[msg.associatedMessageType!]!.addMessage(msg);
    }

    return reactions;
  }

  bool hasReactions() {
    return this.messages.length > 0;
  }

  void addMessage(Message message) {
    this.messages.add(message);
  }

  Widget? getSmallWidget(BuildContext context, {Message? message, bool isReactionPicker = true}) {
    if (this.messages.isEmpty && message == null) return null;
    if (this.messages.isEmpty && message != null) this.messages = [message];

    List<Widget> reactionList = [];

    for (int i = 0; i < this.messages.length; i++) {
      Color iconColor = Colors.white;
      if (!this.messages[i].isFromMe! && Theme.of(context).accentColor.computeLuminance() >= 0.179) {
        iconColor = Colors.black.withAlpha(95);
      }

      reactionList.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            (this.messages[i].isFromMe! && isReactionPicker ? 5.0 : 0.0) + i.toDouble() * 10.0,
            1.0,
            0,
            0,
          ),
          child: Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: this.messages[i].isFromMe! ? Colors.blue : Theme.of(context).accentColor,
              boxShadow: isReactionPicker ? null : [
                new BoxShadow(
                  blurRadius: 1.0,
                  color: Colors.black.withOpacity(0.8),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0),
              child: getReactionIcon(reactionType, iconColor),
            ),
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
