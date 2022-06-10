import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

class Themes {
  static List<ThemeStruct> get defaultThemes => [
    ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),
    ThemeStruct(name: "Bright White", themeData: whiteLightTheme),
    ThemeStruct(name: "Nord Theme", themeData: nordDarkTheme),
    ThemeStruct(name: "Music Theme (Light)", themeData: whiteLightTheme, gradientBg: true),
    ThemeStruct(name: "Music Theme (Dark)", themeData: oledDarkTheme, gradientBg: true),
  ];
}

bool isEqual(ThemeData one, ThemeData two) {
  return one.colorScheme.secondary == two.colorScheme.secondary && one.backgroundColor == two.backgroundColor;
}

ThemeData oledDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.whiteRedmond),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: Colors.black,
    cardColor: HexColor('26262a'),
    errorColor: Colors.red,
    brightness: Brightness.dark,
  ).copyWith(outline: Colors.grey),
  dividerColor: HexColor('27272a'),
  backgroundColor: Colors.black,
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData nordDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.whiteRedmond),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: HexColor('2E3440'),
    cardColor: HexColor('4C566A'),
    errorColor: Colors.red,
    brightness: Brightness.dark,
  ).copyWith(outline: Colors.grey),
  dividerColor: HexColor('4C566A'),
  backgroundColor: HexColor('2E3440'),
  splashColor: Colors.white.withOpacity(0.35),
);

ThemeData whiteLightTheme = ThemeData(
  primarySwatch: Colors.blue,
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.blackRedmond),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    backgroundColor: Colors.white,
    cardColor: HexColor('e5e5ea'),
    errorColor: Colors.red,
    brightness: Brightness.light,
  ).copyWith(outline: Colors.grey),
  dividerColor: HexColor('e5e5ea').withOpacity(0.5),
  backgroundColor: Colors.white,
);

void loadTheme(BuildContext? context, {ThemeStruct? lightOverride, ThemeStruct? darkOverride}) {
  if (context == null) return;

  // Set the theme to match those of the settings
  ThemeData light = (lightOverride ?? ThemeStruct.getLightTheme()).data;
  ThemeData dark = (darkOverride ?? ThemeStruct.getDarkTheme()).data;

  final tuple = applyMonet(light, dark);
  light = tuple.item1;
  dark = tuple.item2;

  AdaptiveTheme.of(context).setTheme(
    light: light,
    dark: dark,
  );
}

Tuple2<ThemeData, ThemeData> applyMonet(ThemeData light, ThemeData dark) {
  if (SettingsManager().settings.monetTheming.value == Monet.harmonize && monetPalette != null) {
    light = light.copyWith(
        primaryColor: Color(monetPalette!.primary.get(50)),
        backgroundColor: light.backgroundColor == Colors.white
            ? Color(monetPalette!.neutral.get(99))
            : light.backgroundColor.harmonizeWith(Color(monetPalette!.primary.get(50))),
        colorScheme: light.colorScheme.copyWith(
          secondary: light.colorScheme.secondary.harmonizeWith(Color(monetPalette!.primary.get(50))),
        ),
        useMaterial3: SettingsManager().useMaterial3,
        typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
        splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
    dark = dark.copyWith(
        primaryColor: Color(monetPalette!.primary.get(50)),
        backgroundColor: dark.backgroundColor.harmonizeWith(Color(monetPalette!.primary.get(60))),
        colorScheme: dark.colorScheme.copyWith(
          secondary: dark.colorScheme.secondary.harmonizeWith(Color(monetPalette!.primary.get(60))),
        ),
        useMaterial3: SettingsManager().useMaterial3,
        typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
        splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
  } else if (SettingsManager().isFullMonet && monetPalette != null) {
    light = light.copyWith(
      primaryColor: Color(monetPalette!.primary.get(40)),
      backgroundColor: Color(monetPalette!.neutral.get(99)),
      colorScheme: light.colorScheme.copyWith(
        primary: Color(monetPalette!.primary.get(40)),
        onPrimary: Color(monetPalette!.primary.get(100)),
        primaryContainer: Color(monetPalette!.primary.get(90)),
        onPrimaryContainer: Color(monetPalette!.primary.get(10)),
        secondary: Color(monetPalette!.secondary.get(40)),
        onSecondary: Color(monetPalette!.secondary.get(100)),
        secondaryContainer: Color(monetPalette!.secondary.get(90)),
        onSecondaryContainer: Color(monetPalette!.secondary.get(10)),
        tertiary: Color(monetPalette!.tertiary.get(40)),
        onTertiary: Color(monetPalette!.tertiary.get(100)),
        tertiaryContainer: Color(monetPalette!.tertiary.get(90)),
        onTertiaryContainer: Color(monetPalette!.tertiary.get(10)),
        error: Color(monetPalette!.error.get(40)),
        onError: Color(monetPalette!.error.get(100)),
        errorContainer: Color(monetPalette!.error.get(90)),
        onErrorContainer: Color(monetPalette!.error.get(10)),
        background: Color(monetPalette!.neutral.get(99)),
        onBackground: Color(monetPalette!.neutral.get(10)),
        surface: Color(monetPalette!.neutral.get(99)),
        onSurface: Color(monetPalette!.neutral.get(10)),
        surfaceVariant: Color(monetPalette!.neutralVariant.get(90)),
        onSurfaceVariant: Color(monetPalette!.neutralVariant.get(30)),
        outline: Color(monetPalette!.neutralVariant.get(50)),
        shadow: Color(monetPalette!.neutral.get(0)),
        inverseSurface: Color(monetPalette!.neutral.get(20)),
        onInverseSurface: Color(monetPalette!.neutral.get(95)),
        inversePrimary: Color(monetPalette!.primary.get(80)),
      ),
      useMaterial3: SettingsManager().useMaterial3,
      typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
      splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
    dark = dark.copyWith(
      primaryColor: Color(monetPalette!.primary.get(50)),
      backgroundColor: Color(monetPalette!.neutral.get(10)),
      colorScheme: dark.colorScheme.copyWith(
        primary: Color(monetPalette!.primary.get(80)),
        onPrimary: Color(monetPalette!.primary.get(20)),
        primaryContainer: Color(monetPalette!.primary.get(30)),
        onPrimaryContainer: Color(monetPalette!.primary.get(90)),
        secondary: Color(monetPalette!.secondary.get(80)),
        onSecondary: Color(monetPalette!.secondary.get(20)),
        secondaryContainer: Color(monetPalette!.secondary.get(30)),
        onSecondaryContainer: Color(monetPalette!.secondary.get(90)),
        tertiary: Color(monetPalette!.tertiary.get(80)),
        onTertiary: Color(monetPalette!.tertiary.get(20)),
        tertiaryContainer: Color(monetPalette!.tertiary.get(30)),
        onTertiaryContainer: Color(monetPalette!.tertiary.get(90)),
        error: Color(monetPalette!.error.get(80)),
        onError: Color(monetPalette!.error.get(20)),
        errorContainer: Color(monetPalette!.error.get(30)),
        onErrorContainer: Color(monetPalette!.error.get(80)),
        background: Color(monetPalette!.neutral.get(10)),
        onBackground: Color(monetPalette!.neutral.get(90)),
        surface: Color(monetPalette!.neutral.get(10)),
        onSurface: Color(monetPalette!.neutral.get(90)),
        surfaceVariant: Color(monetPalette!.neutralVariant.get(30)),
        onSurfaceVariant: Color(monetPalette!.neutralVariant.get(80)),
        outline: Color(monetPalette!.neutralVariant.get(60)),
        shadow: Color(monetPalette!.neutral.get(0)),
        inverseSurface: Color(monetPalette!.neutral.get(90)),
        onInverseSurface: Color(monetPalette!.neutral.get(20)),
        inversePrimary: Color(monetPalette!.primary.get(40)),
      ),
      useMaterial3: SettingsManager().useMaterial3,
      typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
      splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
  } else {
    light = light.copyWith(
      useMaterial3: SettingsManager().useMaterial3,
      typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
      splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
    dark = dark.copyWith(
      useMaterial3: SettingsManager().useMaterial3,
      typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
      splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
  }
  return Tuple2(light, dark);
}

ThemeStruct revertToPreviousDarkTheme() {
  List<ThemeStruct> allThemes = ThemeStruct.getThemes();
  final darkName = prefs.getString("previous-dark");
  ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == darkName);

  previous ??= Themes.defaultThemes.firstWhere((element) => element.name == "OLED Dark");

  // Remove the previous flags
  prefs.remove("previous-dark");

  return previous;
}

ThemeStruct revertToPreviousLightTheme() {
  List<ThemeStruct> allThemes = ThemeStruct.getThemes();
  final lightName = prefs.getString("previous-light");
  ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == lightName);

  previous ??= Themes.defaultThemes.firstWhere((element) => element.name == "Bright White");

  // Remove the previous flags
  prefs.remove("previous-light");

  return previous;
}

extension SettingsThemeData on ThemeData {
  bool get isOled {
    return backgroundColor == Colors.black;
  }
  bool get isMonoColorPanel {
    return SettingsManager().settings.skin.value == Skins.iOS && isOled;
  }
  Color get tileColor {
    if (SettingsManager().isFullMonet) {
      return colorScheme.surfaceVariant;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && (backgroundColor == Colors.black || isEqual(this, nordDarkTheme))) {
      return headerColor;
    }
    if ((colorScheme.secondary.computeLuminance() < backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(this, whiteLightTheme))) {
      return backgroundColor;
    } else {
      return colorScheme.secondary;
    }

  }
  Color get headerColor {
    if ((colorScheme.secondary.computeLuminance() < backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(this, whiteLightTheme))) {
      return colorScheme.secondary;
    } else {
      return backgroundColor;
    }
  }
}
