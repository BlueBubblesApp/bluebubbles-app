import 'dart:convert';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:flutter/material.dart';

class Settings {
  Settings();

  Settings.fromJson(Map<String, dynamic> json)
      : serverAddress =
            json.containsKey('server_address') ? json['server_address'] : "",
        fcmAuthData =
            json.containsKey('fcm_auth_data') ? json['fcm_auth_data'] : null,
        guidAuthKey =
            json.containsKey('guidAuthKey') ? json['guidAuthKey'] : "",
        finishedSetup =
            json.containsKey('finishedSetup') ? json['finishedSetup'] : false,
        chunkSize = json.containsKey('chunkSize') ? json['chunkSize'] : 500,
        autoOpenKeyboard = json.containsKey('autoOpenKeyboard')
            ? json['autoOpenKeyboard']
            : true,
        autoDownload =
            json.containsKey('autoDownload') ? json['autoDownload'] : true,
        onlyWifiDownload =
          json.containsKey('onlyWifiDownload') ? json['onlyWifiDownload'] : false,
        hideTextPreviews = json.containsKey('hideTextPreviews')
            ? json['hideTextPreviews']
            : false,
        showIncrementalSync = json.containsKey('showIncrementalSync')
            ? json['showIncrementalSync']
            : false,
        lowMemoryMode =
            json.containsKey('lowMemoryMode') ? json['lowMemoryMode'] : false,
        scrollSpeed =
            json.containsKey('scrollSpeed') ? json['scrollSpeed'] : 0.95,
        lastIncrementalSync = json.containsKey('lastIncrementalSync')
            ? json['lastIncrementalSync']
            : 0,
        _darkColorTheme = json.containsKey('darkColorTheme')
            ? jsonDecode(json['darkColorTheme'])
            : {},
        _lightColorTheme = json.containsKey('lightColorTheme')
            ? jsonDecode(json['lightColorTheme'])
            : {};

  var fcmAuthData;
  String guidAuthKey = "";
  String serverAddress = "";
  bool finishedSetup = false;
  int chunkSize = 500;
  bool autoDownload = true;
  bool onlyWifiDownload = false;
  bool autoOpenKeyboard = true;
  bool hideTextPreviews = false;
  bool showIncrementalSync = false;
  bool lowMemoryMode = false;
  double scrollSpeed = 0.95;
  int lastIncrementalSync = 0;
  Map<String, dynamic> _lightColorTheme = {};
  Map<String, dynamic> _darkColorTheme = {};
  Skins skin = Skins.IOS;

  void setOneColorOfDarkTheme(
      ThemeColors theme, Color color, BuildContext context) {
    if (_darkColorTheme.length == 0) {
      darkColorTheme = AdaptiveTheme.of(context).darkTheme;
    }
    _darkColorTheme[theme.toString()] = color.value;
  }

  void setOneColorOfLightTheme(
      ThemeColors theme, Color color, BuildContext context) {
    if (_lightColorTheme.length == 0) {
      lightColorTheme = AdaptiveTheme.of(context).theme;
    }
    _lightColorTheme[theme.toString()] = color.value;
  }

  set darkColorTheme(ThemeData theme) {
    for (ThemeColors color in ThemeColors.values) {
      switch (color) {
        case ThemeColors.Headline1:
          _darkColorTheme[color.toString()] =
              theme.textTheme.headline1.color.value;
          break;
        case ThemeColors.Headline2:
          _darkColorTheme[color.toString()] =
              theme.textTheme.headline2.color.value;
          break;
        case ThemeColors.Bodytext1:
          _darkColorTheme[color.toString()] =
              theme.textTheme.bodyText1.color.value;
          break;
        case ThemeColors.BodyText2:
          _darkColorTheme[color.toString()] =
              theme.textTheme.bodyText2.color.value;
          break;
        case ThemeColors.Subtitle1:
          _darkColorTheme[color.toString()] =
              theme.textTheme.subtitle1.color.value;
          break;
        case ThemeColors.Subtitle2:
          _darkColorTheme[color.toString()] =
              theme.textTheme.subtitle2.color.value;
          break;
        case ThemeColors.AccentColor:
          _darkColorTheme[color.toString()] = theme.accentColor.value;
          break;
        case ThemeColors.DividerColor:
          _darkColorTheme[color.toString()] = theme.dividerColor.value;
          break;
        case ThemeColors.BackgroundColor:
          _darkColorTheme[color.toString()] = theme.backgroundColor.value;
          break;
      }
    }
  }

  set darkColorPreset(DarkThemes theme) {
    switch (theme) {
      case DarkThemes.OLED:
        darkColorTheme = oledDarkTheme;
        break;
      case DarkThemes.Nord:
        darkColorTheme = nordDarkTheme;
        break;
    }
  }

  set lightColorTheme(ThemeData theme) {
    for (ThemeColors color in ThemeColors.values) {
      switch (color) {
        case ThemeColors.Headline1:
          _lightColorTheme[color.toString()] =
              theme.textTheme.headline1.color.value;
          break;
        case ThemeColors.Headline2:
          _lightColorTheme[color.toString()] =
              theme.textTheme.headline2.color.value;
          break;
        case ThemeColors.Bodytext1:
          _lightColorTheme[color.toString()] =
              theme.textTheme.bodyText1.color.value;
          break;
        case ThemeColors.BodyText2:
          _lightColorTheme[color.toString()] =
              theme.textTheme.bodyText2.color.value;
          break;
        case ThemeColors.Subtitle1:
          _lightColorTheme[color.toString()] =
              theme.textTheme.subtitle1.color.value;
          break;
        case ThemeColors.Subtitle2:
          _lightColorTheme[color.toString()] =
              theme.textTheme.subtitle2.color.value;
          break;
        case ThemeColors.AccentColor:
          _lightColorTheme[color.toString()] = theme.accentColor.value;
          break;
        case ThemeColors.DividerColor:
          _lightColorTheme[color.toString()] = theme.dividerColor.value;
          break;
        case ThemeColors.BackgroundColor:
          _lightColorTheme[color.toString()] = theme.backgroundColor.value;
          break;
      }
    }
  }

  set lightColorPreset(LightThemes theme) {
    switch (theme) {
      case LightThemes.Bright_White:
        lightColorTheme = whiteLightTheme;
        break;
    }
  }

  ThemeData get darkTheme {
    ThemeData theme = oledDarkTheme;
    if (_darkColorTheme.length != 9) return theme;
    _darkColorTheme.forEach((key, value) {
      theme = returnThemeFromColorTheme(theme, key, value);
    });
    return theme;
  }

  ThemeData get lightTheme {
    ThemeData theme = whiteLightTheme;
    if (_lightColorTheme.length != 9) return theme;
    _lightColorTheme.forEach((key, value) {
      theme = returnThemeFromColorTheme(theme, key, value);
    });
    return theme;
  }

  DarkThemes get darkPreset {
    if (darkTheme == oledDarkTheme) {
      return DarkThemes.OLED;
    } else if (darkTheme == nordDarkTheme) {
      return DarkThemes.Nord;
    } else {
      return null;
    }
  }

  LightThemes get lightPreset {
    if (lightTheme == whiteLightTheme) {
      return LightThemes.Bright_White;
    } else {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'server_address': serverAddress,
        'fcm_auth_data': fcmAuthData,
        'guidAuthKey': guidAuthKey,
        'finishedSetup': finishedSetup,
        'chunkSize': chunkSize,
        'lastIncrementalSync': lastIncrementalSync,
        'autoDownload': autoDownload != null ? autoDownload : true,
        'onlyWifiDownload': onlyWifiDownload != null ? onlyWifiDownload : true,
        'autoOpenKeyboard': autoOpenKeyboard != null ? autoOpenKeyboard : true,
        'hideTextPreviews': hideTextPreviews != null ? hideTextPreviews : false,
        'showIncrementalSync':
            showIncrementalSync != null ? showIncrementalSync : false,
        'lowMemoryMode': lowMemoryMode != null ? lowMemoryMode : false,
        'scrollSpeed': scrollSpeed != null ? scrollSpeed : 0.95,
        'darkColorTheme': jsonEncode(_darkColorTheme),
        'lightColorTheme': jsonEncode(_lightColorTheme),
      };
  ThemeData returnThemeFromColorTheme(ThemeData _theme, String key, int value) {
    ThemeColors color =
        ThemeColors.values.firstWhere((e) => e.toString() == key);
    ThemeData theme = _theme;
    switch (color) {
      case ThemeColors.Headline1:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            headline1: theme.textTheme.headline1.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.Headline2:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            headline2: theme.textTheme.headline2.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.Bodytext1:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            bodyText1: theme.textTheme.bodyText1.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.BodyText2:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            bodyText2: theme.textTheme.bodyText2.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.Subtitle1:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            subtitle1: theme.textTheme.subtitle1.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.Subtitle2:
        theme = theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            subtitle2: theme.textTheme.subtitle2.copyWith(color: Color(value)),
          ),
        );
        break;
      case ThemeColors.AccentColor:
        theme = theme.copyWith(accentColor: Color(value));
        break;
      case ThemeColors.DividerColor:
        theme = theme.copyWith(dividerColor: Color(value));
        break;
      case ThemeColors.BackgroundColor:
        theme = theme.copyWith(backgroundColor: Color(value));
        break;
    }
    return theme;
  }
}
