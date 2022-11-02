import 'package:bluebubbles/models/models.dart';
import 'package:emojis/emojis.dart';

class ReactionHelpers {
  static ReactionType emojiToReaction(String reaction) {
    switch (reaction) {
      case Emojis.redHeart:
        return ReactionType.love;
      case Emojis.thumbsUp:
        return ReactionType.like;
      case Emojis.thumbsDown:
        return ReactionType.dislike;
      case Emojis.faceWithTearsOfJoy:
        return ReactionType.laugh;
      case Emojis.redExclamationMark:
        return ReactionType.emphasize;
      case Emojis.redQuestionMark:
        return ReactionType.question;
      default:
        return ReactionType.love;
    }
  }
}