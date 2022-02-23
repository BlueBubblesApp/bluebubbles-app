import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

enum DarkThemes {
  OLED,
  Nord,
}

enum LightThemes {
  Bright_White,
}

class Themes {
  static List<ThemeObject> get themes => [
        ThemeObject.fromData(oledDarkTheme, "OLED Dark"),
        ThemeObject.fromData(whiteLightTheme, "Bright White"),
        ThemeObject.fromData(nordDarkTheme, "Nord Theme"),
        ThemeObject.fromData(whiteLightTheme, "Music Theme (Light)", gradientBg: true),
        ThemeObject.fromData(oledDarkTheme, "Music Theme (Dark)", gradientBg: true),
      ];
}

bool isEqual(ThemeData one, ThemeData two) {
  return one.colorScheme.secondary == two.colorScheme.secondary && one.backgroundColor == two.backgroundColor;
}

ThemeData oledDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('919191'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('7d7d7d'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: Colors.black,
    accentColor: HexColor('26262a'),
  ),
  dividerColor: HexColor('27272a'),
  backgroundColor: Colors.black,
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData nordDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: HexColor('ECEFF4'),
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: HexColor('E5E9F0'),
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: HexColor('ECEFF4'),
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: HexColor('E5E9F0'),
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('a5a5a5'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('b9b9b9'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: HexColor('2E3440'),
    accentColor: HexColor('4C566A'),
  ),
  dividerColor: HexColor('4C566A'),
  backgroundColor: HexColor('2E3440'),
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData whiteLightTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 18,
    ),
    headline2: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 14,
    ),
    bodyText1: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    bodyText2: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
    subtitle1: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 11,
      fontWeight: FontWeight.normal,
    ),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: Colors.white,
    accentColor: HexColor('e5e5ea'),
  ),
  dividerColor: HexColor('e5e5ea').withOpacity(0.5),
  backgroundColor: Colors.white,
);

void loadTheme(BuildContext? context, {ThemeObject? lightOverride, ThemeObject? darkOverride}) {
  if (context == null) return;

  // Set the theme to match those of the settings
  ThemeObject light = lightOverride ?? ThemeObject.getLightTheme();
  ThemeObject dark = darkOverride ?? ThemeObject.getDarkTheme();
  AdaptiveTheme.of(context).setTheme(
    light: light.themeData,
    dark: dark.themeData,
  );
}

ThemeObject revertToPreviousDarkTheme() {
  List<ThemeObject> allThemes = ThemeObject.getThemes();
  ThemeObject? previous = allThemes.firstWhereOrNull((e) => e.previousDarkTheme);

  previous ??= Themes.themes.firstWhereOrNull((element) => element.name == "OLED Dark");

  // Remove the previous flags
  previous!.previousDarkTheme = false;

  // Save the theme and set it accordingly
  return previous.save();
}

ThemeObject revertToPreviousLightTheme() {
  List<ThemeObject> allThemes = ThemeObject.getThemes();
  ThemeObject? previous = allThemes.firstWhereOrNull((e) => e.previousDarkTheme);

  previous ??= Themes.themes.firstWhereOrNull((element) => element.name == "Bright White");

  // Remove the previous flags
  previous!.previousDarkTheme = false;

  // Save the theme and set it accordingly
  return previous.save();
}
