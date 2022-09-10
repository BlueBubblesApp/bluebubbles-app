import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

class Themes {
  static List<ThemeStruct> get defaultThemes => [
    ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),
    ThemeStruct(name: "Bright White", themeData: whiteLightTheme),
    ThemeStruct(name: "Nord Theme", themeData: nordDarkTheme),
    ThemeStruct(name: "Music Theme ☀", themeData: whiteLightTheme, gradientBg: true),
    ThemeStruct(name: "Music Theme 🌙", themeData: oledDarkTheme, gradientBg: true),
    ...FlexScheme.values
        .where((e) => e != FlexScheme.custom)
        .map((e) => [
          ThemeStruct(
              name: "${describeEnum(e).split(RegExp(r"(?=[A-Z])")).join(" ").capitalize} ☀",
              themeData: FlexThemeData.light(scheme: e, surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold, blendLevel: 40).copyWith(
                  textTheme: Typography.englishLike2021.merge(Typography.blackMountainView),
                  splashFactory: InkSparkle.splashFactory,
                  useMaterial3: true,
                  extensions: [
                    BubbleText(
                      bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
                        fontSize: 15,
                        height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
                      ),
                    ),
                  ]
              ),
          ),
          ThemeStruct(
              name: "${describeEnum(e).split(RegExp(r"(?=[A-Z])")).join(" ").capitalize} 🌙",
              themeData: FlexThemeData.dark(scheme: e, surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold, blendLevel: 40)
                  .copyWith(
                  textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
                  splashFactory: InkSparkle.splashFactory,
                  useMaterial3: true,
                  extensions: [
                    BubbleText(
                      bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
                        fontSize: 15,
                        height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
                      ),
                    ),
                  ]
              ),
          ),
    ]).flattened,
  ];
}

bool isEqual(ThemeData one, ThemeData two) {
  return one.colorScheme.secondary == two.colorScheme.secondary && one.backgroundColor == two.backgroundColor;
}

ThemeData oledDarkTheme = FlexColorScheme(
  textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    background: Colors.black,
    error: Colors.red,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
).toTheme.copyWith(splashFactory: InkSparkle.splashFactory, extensions: [
  BubbleColors(
    iMessageBubbleColor: HexColor("1982FC"),
    oniMessageBubbleColor: Colors.white,
    smsBubbleColor: HexColor("43CC47"),
    onSmsBubbleColor: Colors.white,
    receivedBubbleColor: HexColor("323332"),
    onReceivedBubbleColor: Colors.white,
  ),
  BubbleText(
    bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
      fontSize: 15,
      height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
      color: Colors.white,
    ),
  ),
]);

ThemeData nordDarkTheme = FlexColorScheme(
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
  useMaterial3: true,
).toTheme.copyWith(splashFactory: InkSparkle.splashFactory, extensions: [
  BubbleText(
    bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
      fontSize: 15,
      height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
    ),
  ),
]);

ThemeData whiteLightTheme = FlexColorScheme(
  textTheme: Typography.englishLike2021.merge(Typography.blackMountainView),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    background: Colors.white,
    error: Colors.red,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
).toTheme.copyWith(splashFactory: InkSparkle.splashFactory, extensions: [
  BubbleColors(
      iMessageBubbleColor: HexColor("1982FC"),
      oniMessageBubbleColor: Colors.white,
      smsBubbleColor: HexColor("43CC47"),
      onSmsBubbleColor: Colors.white,
      receivedBubbleColor: HexColor("e9e9e8"),
      onReceivedBubbleColor: Colors.black,
  ),
  BubbleText(
    bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
      fontSize: 15,
      height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
    ),
  ),
]);

void loadTheme(BuildContext? context, {ThemeStruct? lightOverride, ThemeStruct? darkOverride}) {
  if (context == null) return;

  // Set the theme to match those of the settings
  ThemeData light = (lightOverride ?? ThemeStruct.getLightTheme()).data;
  ThemeData dark = (darkOverride ?? ThemeStruct.getDarkTheme()).data;

  final tuple = Platform.isWindows ? applyWindowsAccent(light, dark) : applyMonet(light, dark);
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
          secondary: light.colorScheme.secondary.harmonizeWith(Color(monetPalette!.secondary.get(40))),
          onSecondary: light.colorScheme.onSecondary.harmonizeWith(Color(monetPalette!.secondary.get(100))),
          secondaryContainer: light.colorScheme.secondaryContainer.harmonizeWith(Color(monetPalette!.secondary.get(90))),
          onSecondaryContainer: light.colorScheme.onSecondaryContainer.harmonizeWith(Color(monetPalette!.secondary.get(10))),
          tertiary: light.colorScheme.tertiary.harmonizeWith(Color(monetPalette!.tertiary.get(40))),
          onTertiary: light.colorScheme.onTertiary.harmonizeWith(Color(monetPalette!.tertiary.get(100))),
          tertiaryContainer: light.colorScheme.tertiaryContainer.harmonizeWith(Color(monetPalette!.tertiary.get(90))),
          onTertiaryContainer: light.colorScheme.onTertiaryContainer.harmonizeWith(Color(monetPalette!.tertiary.get(10))),
          error: light.colorScheme.error.harmonizeWith(Color(monetPalette!.error.get(40))),
          onError: light.colorScheme.onError.harmonizeWith(Color(monetPalette!.error.get(100))),
          errorContainer: light.colorScheme.errorContainer.harmonizeWith(Color(monetPalette!.error.get(90))),
          onErrorContainer: light.colorScheme.onErrorContainer.harmonizeWith(Color(monetPalette!.error.get(10))),
          background: light.colorScheme.background.harmonizeWith(Color(monetPalette!.neutral.get(99))),
          onBackground: light.colorScheme.onBackground.harmonizeWith(Color(monetPalette!.neutral.get(10))),
          surface: light.colorScheme.surface.harmonizeWith(Color(monetPalette!.neutral.get(99))),
          onSurface: light.colorScheme.onSurface.harmonizeWith(Color(monetPalette!.neutral.get(10))),
          surfaceVariant: light.colorScheme.surfaceVariant.harmonizeWith(Color(monetPalette!.neutralVariant.get(90))),
          onSurfaceVariant: light.colorScheme.onSurfaceVariant.harmonizeWith(Color(monetPalette!.neutralVariant.get(30))),
          outline: light.colorScheme.outline.harmonizeWith(Color(monetPalette!.neutralVariant.get(50))),
          shadow: light.colorScheme.shadow.harmonizeWith(Color(monetPalette!.neutral.get(0))),
          inverseSurface: light.colorScheme.inverseSurface.harmonizeWith(Color(monetPalette!.neutral.get(20))),
          onInverseSurface: light.colorScheme.onInverseSurface.harmonizeWith(Color(monetPalette!.neutral.get(95))),
          inversePrimary: light.colorScheme.inversePrimary.harmonizeWith(Color(monetPalette!.primary.get(80))),
        ),
    );
    dark = dark.copyWith(
        colorScheme: dark.colorScheme.copyWith(
          primary: Color(monetPalette!.primary.get(80)),
          onPrimary: Color(monetPalette!.primary.get(20)),
          primaryContainer: Color(monetPalette!.primary.get(30)),
          onPrimaryContainer: Color(monetPalette!.primary.get(90)),
          secondary: dark.colorScheme.secondary.harmonizeWith(Color(monetPalette!.secondary.get(80))),
          onSecondary: dark.colorScheme.onSecondary.harmonizeWith(Color(monetPalette!.secondary.get(20))),
          secondaryContainer: dark.colorScheme.secondaryContainer.harmonizeWith(Color(monetPalette!.secondary.get(30))),
          onSecondaryContainer: dark.colorScheme.onSecondaryContainer.harmonizeWith(Color(monetPalette!.secondary.get(90))),
          tertiary: dark.colorScheme.tertiary.harmonizeWith(Color(monetPalette!.tertiary.get(80))),
          onTertiary: dark.colorScheme.onTertiary.harmonizeWith(Color(monetPalette!.tertiary.get(20))),
          tertiaryContainer: dark.colorScheme.tertiaryContainer.harmonizeWith(Color(monetPalette!.tertiary.get(30))),
          onTertiaryContainer: dark.colorScheme.onTertiaryContainer.harmonizeWith(Color(monetPalette!.tertiary.get(90))),
          error: dark.colorScheme.error.harmonizeWith(Color(monetPalette!.error.get(80))),
          onError: dark.colorScheme.onError.harmonizeWith(Color(monetPalette!.error.get(20))),
          errorContainer: dark.colorScheme.errorContainer.harmonizeWith(Color(monetPalette!.error.get(30))),
          onErrorContainer: dark.colorScheme.onErrorContainer.harmonizeWith(Color(monetPalette!.error.get(80))),
          background: dark.colorScheme.background.harmonizeWith(Color(monetPalette!.neutral.get(10))),
          onBackground: dark.colorScheme.onBackground.harmonizeWith(Color(monetPalette!.neutral.get(90))),
          surface: dark.colorScheme.surface.harmonizeWith(Color(monetPalette!.neutral.get(10))),
          onSurface: dark.colorScheme.onSurface.harmonizeWith(Color(monetPalette!.neutral.get(90))),
          surfaceVariant: dark.colorScheme.surfaceVariant.harmonizeWith(Color(monetPalette!.neutralVariant.get(30))),
          onSurfaceVariant: dark.colorScheme.onSurfaceVariant.harmonizeWith(Color(monetPalette!.neutralVariant.get(80))),
          outline: dark.colorScheme.outline.harmonizeWith(Color(monetPalette!.neutralVariant.get(60))),
          shadow: dark.colorScheme.shadow.harmonizeWith(Color(monetPalette!.neutral.get(0))),
          inverseSurface: dark.colorScheme.inverseSurface.harmonizeWith(Color(monetPalette!.neutral.get(90))),
          onInverseSurface: dark.colorScheme.onInverseSurface.harmonizeWith(Color(monetPalette!.neutral.get(20))),
          inversePrimary: dark.colorScheme.inversePrimary.harmonizeWith(Color(monetPalette!.primary.get(40))),
        ),
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
    );
  }
  return Tuple2(light, dark);
}

Tuple2<ThemeData, ThemeData> applyWindowsAccent(ThemeData light, ThemeData dark) {
  if (windowsAccentColor == null) {
    return Tuple2(light, dark);
  }

  Hct color = Hct.fromInt(windowsAccentColor!.value);
  TonalPalette tonalPalette = TonalPalette.of(color.hue, color.chroma);

  if (SettingsManager().settings.useWindowsAccent.value) {
    light = light.copyWith(
      colorScheme: light.colorScheme.copyWith(
        primary: Color(tonalPalette.get(40)),
        onPrimary: Color(tonalPalette.get(100)),
        primaryContainer: Color(tonalPalette.get(90)),
        onPrimaryContainer: Color(tonalPalette.get(10)),
        background: light.colorScheme.background.harmonizeWith(Color(tonalPalette.get(40))),
        secondary: light.colorScheme.secondary.harmonizeWith(Color(tonalPalette.get(40))),
      ),
    );
    dark = dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(
        primary: Color(tonalPalette.get(80)),
        onPrimary: Color(tonalPalette.get(20)),
        primaryContainer: Color(tonalPalette.get(30)),
        onPrimaryContainer: Color(tonalPalette.get(90)),
        background: dark.colorScheme.background.harmonizeWith(Color(tonalPalette.get(80))),
        secondary: dark.colorScheme.secondary.harmonizeWith(Color(tonalPalette.get(80))),
      ),
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

@immutable
class BubbleColors extends ThemeExtension<BubbleColors> {
  const BubbleColors({
    required this.iMessageBubbleColor,
    required this.oniMessageBubbleColor,
    required this.smsBubbleColor,
    required this.onSmsBubbleColor,
    required this.receivedBubbleColor,
    required this.onReceivedBubbleColor,
  });

  final Color? iMessageBubbleColor;
  final Color? oniMessageBubbleColor;
  final Color? smsBubbleColor;
  final Color? onSmsBubbleColor;
  final Color? receivedBubbleColor;
  final Color? onReceivedBubbleColor;

  @override
  BubbleColors copyWith({Color? iMessageBubbleColor, Color? oniMessageBubbleColor, Color? smsBubbleColor, Color? onSmsBubbleColor, Color? receivedBubbleColor, Color? onReceivedBubbleColor}) {
    return BubbleColors(
      iMessageBubbleColor: iMessageBubbleColor ?? this.iMessageBubbleColor,
      oniMessageBubbleColor: oniMessageBubbleColor ?? this.oniMessageBubbleColor,
      smsBubbleColor: smsBubbleColor ?? this.smsBubbleColor,
      onSmsBubbleColor: onSmsBubbleColor ?? this.onSmsBubbleColor,
      receivedBubbleColor: receivedBubbleColor ?? this.receivedBubbleColor,
      onReceivedBubbleColor: onReceivedBubbleColor ?? this.onReceivedBubbleColor,
    );
  }

  @override
  BubbleColors lerp(ThemeExtension<BubbleColors>? other, double t) {
    if (other is! BubbleColors) {
      return this;
    }
    return BubbleColors(
      iMessageBubbleColor: Color.lerp(iMessageBubbleColor, other.iMessageBubbleColor, t),
      oniMessageBubbleColor: Color.lerp(oniMessageBubbleColor, other.oniMessageBubbleColor, t),
      smsBubbleColor: Color.lerp(smsBubbleColor, other.smsBubbleColor, t),
      onSmsBubbleColor: Color.lerp(onSmsBubbleColor, other.onSmsBubbleColor, t),
      receivedBubbleColor: Color.lerp(receivedBubbleColor, other.receivedBubbleColor, t),
      onReceivedBubbleColor: Color.lerp(onReceivedBubbleColor, other.onReceivedBubbleColor, t),
    );
  }
}

@immutable
class BubbleText extends ThemeExtension<BubbleText> {
  const BubbleText({
    required this.bubbleText,
  });

  final TextStyle bubbleText;

  @override
  BubbleText copyWith({TextStyle? bubbleText}) {
    return BubbleText(
      bubbleText: bubbleText ?? this.bubbleText,
    );
  }

  @override
  BubbleText lerp(ThemeExtension<BubbleText>? other, double t) {
    if (other is! BubbleText) {
      return this;
    }
    return BubbleText(
      bubbleText: TextStyle.lerp(bubbleText, other.bubbleText, t)!,
    );
  }
}
