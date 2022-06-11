final effectMap = {
  "slam": "com.apple.MobileSMS.expressivesend.impact",
  "loud": "com.apple.MobileSMS.expressivesend.loud",
  "gentle": "com.apple.MobileSMS.expressivesend.gentle",
  "invisible ink": "com.apple.MobileSMS.expressivesend.invisibleink",
  "echo": "com.apple.messages.effect.CKEchoEffect",
  "spotlight": "com.apple.messages.effect.CKSpotlightEffect",
  "balloons": "com.apple.messages.effect.CKHappyBirthdayEffect",
  "confetti": "com.apple.messages.effect.CKConfettiEffect",
  "love": "com.apple.messages.effect.CKHeartEffect",
  "lasers": "com.apple.messages.effect.CKLasersEffect",
  "fireworks": "com.apple.messages.effect.CKFireworksEffect",
  "celebration": "com.apple.messages.effect.CKSparklesEffect",
};

final stringToMessageEffect = {
  null: MessageEffect.none,
  "slam": MessageEffect.slam,
  "loud": MessageEffect.loud,
  "gentle": MessageEffect.gentle,
  "invisible ink": MessageEffect.invisibleInk,
  "echo": MessageEffect.echo,
  "spotlight": MessageEffect.spotlight,
  "balloons": MessageEffect.balloons,
  "confetti": MessageEffect.confetti,
  "love": MessageEffect.love,
  "lasers": MessageEffect.lasers,
  "fireworks": MessageEffect.fireworks,
  "celebration": MessageEffect.celebration,
};

enum MessageEffect {
  none,
  slam,
  loud,
  gentle,
  invisibleInk,
  echo,
  spotlight,
  balloons,
  confetti,
  love,
  lasers,
  fireworks,
  celebration,
}

extension EffectHelper on MessageEffect {
  bool get isBubble => this == MessageEffect.slam || this == MessageEffect.loud || this == MessageEffect.gentle || this == MessageEffect.invisibleInk;

  bool get isScreen => !isBubble && this != MessageEffect.none;
}

enum Skins {
  iOS,
  Material,
  Samsung,
}

enum SwipeDirection {
  LEFT,
  RIGHT,
}

enum MaterialSwipeAction {
  pin,
  alerts,
  delete,
  mark_read,
  archive,
}

enum SecurityLevel {
  locked,
  locked_and_secured,
}

enum Monet {
  none,
  harmonize,
  full,
}

final urlRegex = RegExp(
    r"(?:^| )(((((H|h)(T|t)|(F|f))(T|t)(P|p)((S|s)?))\://)|www.)[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,6}(\:[0-9]{1,5})*(/($|[a-zA-Z0-9\.\,\;\?\'\\\+&amp;%\$#@!^*()\=~_\/-]+))*");
