abstract class ThemeColors {
  static const String Headline1 = "Headline1";
  static const String Headline2 = "Headline2";
  static const String Bodytext1 = "Bodytext1";
  static const String Bodytext2 = "BodyText2";
  static const String Subtitle1 = "Subtitle1";
  static const String Subtitle2 = "Subtitle2";
  static const String AccentColor = "AccentColor";
  static const String DividerColor = "DividerColor";
  static const String BackgroundColor = "BackgroundColor";
  static const String PrimaryColor = "PrimaryColor";

  static const List<String> Colors = [
    Headline1,
    Headline2,
    Bodytext1,
    Bodytext2,
    Subtitle1,
    Subtitle2,
    AccentColor,
    DividerColor,
    BackgroundColor,
    PrimaryColor
  ];
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

final urlRegex = RegExp(
    r"(?:^| )(((((H|h)(T|t)|(F|f))(T|t)(P|p)((S|s)?))\://)|www.)[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,6}(\:[0-9]{1,5})*(/($|[a-zA-Z0-9\.\,\;\?\'\\\+&amp;%\$#@!^*()\=~_\/-]+))*");
