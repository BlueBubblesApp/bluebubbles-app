enum MessageError { NO_ERROR, TIMEOUT, NO_CONNECTION, BAD_REQUEST, SERVER_ERROR }

extension MessageErrorExtension on MessageError {
  static const codes = {
    MessageError.NO_ERROR: 0,
    MessageError.TIMEOUT: 4,
    MessageError.NO_CONNECTION: 1000,
    MessageError.BAD_REQUEST: 1001,
    MessageError.SERVER_ERROR: 1002,
  };

  int get code => codes[this];
}

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
  IOS,
  Material,
  Samsung,
}
