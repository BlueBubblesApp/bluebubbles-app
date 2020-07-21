import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:flutter/material.dart';

enum DarkThemes {
  OLED,
  Nord,
}

enum LightThemes {
  Bright_White,
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
    ),
    bodyText2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
    ),
    subtitle1: TextStyle(
      color: HexColor('36363a'),
      fontSize: 13,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('46464a'),
      fontSize: 9,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('26262a'),
  dividerColor: HexColor('27272a'),
  buttonColor: HexColor("666666"),
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
    ),
    bodyText2: TextStyle(
      color: HexColor('E5E9F0'),
      fontWeight: FontWeight.normal,
    ),
    subtitle1: TextStyle(
      color: HexColor('D8DEE9'),
      fontSize: 13,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('D8DEE9'),
      fontSize: 9,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('4C566A'),
  dividerColor: HexColor('4C566A'),
  buttonColor: HexColor("4C566A"),
  backgroundColor: HexColor('2E3440'),
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData whiteLightTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: TextTheme(
    headline1: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
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
    ),
    bodyText2: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.normal,
    ),
    subtitle1: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 13,
      fontWeight: FontWeight.normal,
    ),
    subtitle2: TextStyle(
      color: HexColor('9a9a9f'),
      fontSize: 9,
      fontWeight: FontWeight.normal,
    ),
  ),
  accentColor: HexColor('e5e5ea'),
  dividerColor: HexColor('e5e5ea').withOpacity(0.5),
  backgroundColor: Colors.white,
);
