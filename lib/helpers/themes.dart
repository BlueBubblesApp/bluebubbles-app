import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    background: Colors.black,
    error: Colors.red,
    brightness: Brightness.dark,
  ),
);

ThemeData nordDarkTheme = ThemeData(
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: createMaterialColor(HexColor("5E81AC")),
    accentColor: HexColor("88C0D0"),
    backgroundColor: HexColor("3B4252"),
    cardColor: HexColor("4C566A"),
    errorColor: Colors.red,
    brightness: Brightness.dark,
  ).copyWith(
    primaryContainer: HexColor("49688e"),
    outline: Colors.grey,
  ),
);

ThemeData whiteLightTheme = ThemeData(
  splashFactory: InkRipple.splashFactory,
  textTheme: Typography.englishLike2021.merge(Typography.blackMountainView),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    background: Colors.white,
    error: Colors.red,
    brightness: Brightness.light,
  ),
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
        colorScheme: light.colorScheme.copyWith(
          primary: Color(monetPalette!.primary.get(40)),
          onPrimary: Color(monetPalette!.primary.get(100)),
          primaryContainer: Color(monetPalette!.primary.get(90)),
          onPrimaryContainer: Color(monetPalette!.primary.get(10)),
          background: light.colorScheme.background.harmonizeWith(Color(monetPalette!.primary.get(40))),
          secondary: light.colorScheme.secondary.harmonizeWith(Color(monetPalette!.primary.get(40))),
        ),
        useMaterial3: SettingsManager().useMaterial3,
        typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
        splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
    dark = dark.copyWith(
        colorScheme: dark.colorScheme.copyWith(
          primary: Color(monetPalette!.primary.get(80)),
          onPrimary: Color(monetPalette!.primary.get(20)),
          primaryContainer: Color(monetPalette!.primary.get(30)),
          onPrimaryContainer: Color(monetPalette!.primary.get(90)),
          background: dark.colorScheme.background.harmonizeWith(Color(monetPalette!.primary.get(80))),
          secondary: dark.colorScheme.secondary.harmonizeWith(Color(monetPalette!.primary.get(80))),
        ),
        useMaterial3: SettingsManager().useMaterial3,
        typography: SettingsManager().useMaterial3 ? Typography.material2021() : null,
        splashFactory: SettingsManager().useMaterial3 ? InkSparkle.splashFactory : null,
    );
  } else if (SettingsManager().isFullMonet && monetPalette != null) {
    light = light.copyWith(
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
}
