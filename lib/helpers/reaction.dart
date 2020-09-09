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
}

class Reaction {
  final String reactionType;

  List<Message> messages = [];

  Reaction({this.reactionType});

  static List<Message> getUniqueReactionMessages(List<Message> messages) {
    List<int> handleCache = [];
    List<Message> current = messages;
    List<Message> output = [];

    // Sort the messages, putting the latest at the top
    current.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));

    // Iterate over the messages and insert the latest reaction for each user
    for (Message msg in current) {
      if (!handleCache.contains(msg.handleId)) {
        handleCache.add(msg.handleId);

        // Only add the reaction if it's not a "negative"
        if (!msg.associatedMessageType.startsWith("-"))
          output.add(msg);
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
      reactions[msg.associatedMessageType].addMessage(msg);
    }

    return reactions;
  }

  bool hasReactions() {
    return this.messages.length > 0;
  }

  void addMessage(Message message) {
    this.messages.add(message);
  }

  bool hasMyReaction({List<Message> messages}) {
    for (Message msg in messages ?? this.messages) {
      if (msg.isFromMe) return true;
    }

    return false;
  }

  List<Message> getUniqueReactions({List<Message> messages}) {
    List<int> cache = [];
    List<Message> msgs = [];
    List<Message> current = messages ?? this.messages;
    current.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
    for (Message msg in current) {
      if (!cache.contains(msg.handleId)) {
        cache.add(msg.handleId);

        // Only add the reaction if it's not a "negative"
        if (!msg.associatedMessageType.startsWith("-"))
          msgs.add(msg);
      }
    }

    return msgs;
  }

  Widget getSmallWidget(BuildContext context) {
    List<Message> added = this.getUniqueReactions();
    if (added.length == 0) return null;
    bool hasMyReaction = this.hasMyReaction(messages: added);

    Color iconColor = Colors.white;
    if (!hasMyReaction && Theme.of(context).accentColor.computeLuminance() >= 0.179) {
      iconColor = Colors.black.withAlpha(95);
    }

    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: hasMyReaction
          ? Colors.blue
          : Theme.of(context).accentColor,
        boxShadow: [
          new BoxShadow(
            blurRadius: 1.0,
            color: Colors.black.withOpacity(0.7),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0),
        child: SvgPicture.asset(
          'assets/reactions/$reactionType-black.svg',
          color: reactionType == "love" ? Colors.pink : iconColor,
        ),
      ),
    );
  }
}