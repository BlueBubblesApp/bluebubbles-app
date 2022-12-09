import 'dart:math';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/color_engine/engine.dart' as engine;
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart' hide GetStringUtils;
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ThemesService ts = Get.isRegistered<ThemesService>() ? Get.find<ThemesService>() : Get.put(ThemesService());

class ThemesService extends GetxService {
  CorePalette? monetPalette;
  Color? windowsAccentColor;

  final Rx<MovieTween> gradientTween = Rx<MovieTween>(MovieTween()
    ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
        .tween("color1", Tween<double>(begin: 0, end: 0.2))
    ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
        .tween("color2", Tween<double>(begin: 0.8, end: 1)));

  Future<void> init() async {
    monetPalette = await DynamicColorPlugin.getCorePalette();
    if (Platform.isWindows) {
      windowsAccentColor = await DynamicColorPlugin.getAccentColor();
    }
  }

  final oledDarkTheme = FlexColorScheme(
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

  final nordDarkTheme = FlexColorScheme(
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

  final whiteLightTheme = FlexColorScheme(
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

  List<ThemeStruct> get defaultThemes => [
    ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),
    ThemeStruct(name: "Bright White", themeData: whiteLightTheme),
    ThemeStruct(name: "Nord Theme", themeData: nordDarkTheme),
    ThemeStruct(name: "Music Theme ☀", themeData: whiteLightTheme),
    ThemeStruct(name: "Music Theme 🌙", themeData: oledDarkTheme),
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

  Skins get skin => ss.settings.skin.value;

  ScrollPhysics get scrollPhysics {
    if (ss.settings.skin.value == Skins.iOS) {
      return const AlwaysScrollableScrollPhysics(
        parent: CustomBouncingScrollPhysics(),
      );
    } else {
      return const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    }
  }

  bool get isFullMonet => ss.settings.monetTheming.value == Monet.full;

  bool inDarkMode(BuildContext context) =>
      (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ||
        (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.system &&
            SchedulerBinding.instance.window.platformBrightness == Brightness.dark));

  bool isGradientBg(BuildContext context) {
    if (inDarkMode(context)) {
      return ThemeStruct.getDarkTheme().gradientBg;
    } else {
      return ThemeStruct.getLightTheme().gradientBg;
    }
  }

  Future<void> refreshMonet(BuildContext context) async {
    monetPalette = await DynamicColorPlugin.getCorePalette();
    _loadTheme(context);
  }

  Future<void> refreshWindowsAccent(BuildContext context) async {
    windowsAccentColor = await DynamicColorPlugin.getAccentColor();
    _loadTheme(context);
  }

  void updateMusicTheme(BuildContext context, Color primary, Color lightBg, Color darkBg, double primaryPercent, double lightBgPercent, double darkBgPercent) async {
    final darkTheme = ThemeStruct.getThemes().firstWhere((e) => e.name == "Music Theme 🌙");
    final lightTheme = ThemeStruct.getThemes().firstWhere((e) => e.name == "Music Theme ☀");
    final engine.ColorScheme scheme = engine.DynamicColorScheme(
      targetColors: const engine.TargetColors(),
      primaryColor: engine.Srgb.fromColor(primary),
    );
    final engine.MonetColors colors = scheme.asColors;
    lightTheme.data = lightTheme.data.copyWith(
      colorScheme: lightTheme.data.colorScheme.copyWith(
        primary: colors.accent1.shade700,
        onPrimary: colors.accent1.shade100,
        primaryContainer: colors.accent1.shade100,
        onPrimaryContainer: colors.accent1.shade900,
        secondary: colors.accent2.shade600,
        onSecondary: colors.accent2.shade50,
        secondaryContainer: colors.accent2.shade100,
        onSecondaryContainer: colors.accent2.shade900,
        tertiary: colors.accent3.shade600,
        onTertiary: colors.accent3.shade50,
        tertiaryContainer: colors.accent3.shade100,
        onTertiaryContainer: colors.accent3.shade900,
        background: colors.neutral1.shade10,
        onBackground: colors.neutral1.shade900,
        surface: colors.neutral1.shade10,
        onSurface: colors.neutral1.shade900,
        surfaceVariant: colors.neutral2.shade100,
        onSurfaceVariant: colors.neutral2.shade700,
        outline: colors.neutral1.shade500,
        shadow: colors.neutral1.shade1000,
        inverseSurface: colors.neutral1.shade800,
        onInverseSurface: colors.neutral1.shade50,
        inversePrimary: colors.accent1.shade200,
      ),
    );
    darkTheme.data = darkTheme.data.copyWith(
      colorScheme: darkTheme.data.colorScheme.copyWith(
        primary: colors.accent1.shade800,
        onPrimary: colors.accent1.shade200,
        primaryContainer: colors.accent1.shade700,
        onPrimaryContainer: colors.accent1.shade100,
        secondary: colors.accent2.shade200,
        onSecondary: colors.accent2.shade800,
        secondaryContainer: colors.accent2.shade700,
        onSecondaryContainer: colors.accent2.shade100,
        tertiary: colors.accent3.shade200,
        onTertiary: colors.accent3.shade800,
        tertiaryContainer: colors.accent3.shade700,
        onTertiaryContainer: colors.accent3.shade100,
        background: colors.neutral1.shade900,
        onBackground: colors.neutral1.shade100,
        surface: colors.neutral1.shade900,
        onSurface: colors.neutral1.shade100,
        surfaceVariant: colors.neutral2.shade700,
        onSurfaceVariant: colors.neutral2.shade200,
        outline: colors.neutral1.shade400,
        shadow: colors.neutral1.shade1000,
        inverseSurface: colors.neutral1.shade100,
        onInverseSurface: colors.neutral1.shade800,
        inversePrimary: colors.accent1.shade600,
      ),
    );
    if (inDarkMode(context)) {
      if (primaryPercent != 0.5 && darkBgPercent != 0.5) {
        double difference = min((primaryPercent / (primaryPercent + darkBgPercent)), 1 - (primaryPercent / (primaryPercent + darkBgPercent)));
        Tween<double> color1 = Tween<double>(begin: 0, end: difference);
        Tween<double> color2 = Tween<double>(begin: 1 - difference, end: 1);
        gradientTween.value = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color1", color1)
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color2", color2);
      } else {
        gradientTween.value = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color1", Tween<double>(begin: 0, end: 0.2))
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color2", Tween<double>(begin: 0.8, end: 1));
      }
    } else {
      if (primaryPercent != 0.5 && lightBgPercent != 0.5) {
        double difference = min((primaryPercent / (primaryPercent + lightBgPercent)), 1 - (primaryPercent / (primaryPercent + lightBgPercent)));
        Tween<double> color1 = Tween<double>(begin: 0.0, end: difference);
        Tween<double> color2 = Tween<double>(begin: 1.0 - difference, end: 1.0);
        gradientTween.value = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color1", color1)
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color2", color2);
      } else {
        gradientTween.value = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color1", Tween<double>(begin: 0, end: 0.2))
          ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
              .tween("color2", Tween<double>(begin: 0.8, end: 1));
      }
    }
    changeTheme(Get.context!, light: lightTheme, dark: darkTheme);
  }

  void _loadTheme(BuildContext context, {ThemeStruct? lightOverride, ThemeStruct? darkOverride}) {
    // Set the theme to match those of the settings
    ThemeData light = (lightOverride ?? ThemeStruct.getLightTheme()).data;
    ThemeData dark = (darkOverride ?? ThemeStruct.getDarkTheme()).data;

    final tuple = getStructsFromData(light, dark);
    light = tuple.item1;
    dark = tuple.item2;

    AdaptiveTheme.of(context).setTheme(
      light: light,
      dark: dark,
    );
  }
  
  Tuple2 getStructsFromData(ThemeData light, ThemeData dark) {
    return Platform.isWindows ? _applyWindowsAccent(light, dark) : _applyMonet(light, dark);
  }

  ThemeStruct revertToPreviousDarkTheme() {
    List<ThemeStruct> allThemes = ThemeStruct.getThemes();
    final darkName = ss.prefs.getString("previous-dark");
    ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == darkName);

    previous ??= defaultThemes.firstWhere((element) => element.name == "OLED Dark");

    // Remove the previous flags
    ss.prefs.remove("previous-dark");

    return previous;
  }

  ThemeStruct revertToPreviousLightTheme() {
    List<ThemeStruct> allThemes = ThemeStruct.getThemes();
    final lightName = ss.prefs.getString("previous-light");
    ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == lightName);

    previous ??= defaultThemes.firstWhere((element) => element.name == "Bright White");

    // Remove the previous flags
    ss.prefs.remove("previous-light");

    return previous;
  }

  void changeTheme(BuildContext context, {ThemeStruct? light, ThemeStruct? dark}) {
    light?.save();
    dark?.save();
    if (light != null) ss.prefs.setString("selected-light", light.name);
    if (dark != null) ss.prefs.setString("selected-dark", dark.name);

    _loadTheme(context);
  }

  Tuple2<ThemeData, ThemeData> _applyMonet(ThemeData light, ThemeData dark) {
    if (ss.settings.monetTheming.value == Monet.harmonize && monetPalette != null) {
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
    } else if (isFullMonet && monetPalette != null) {
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

  Tuple2<ThemeData, ThemeData> _applyWindowsAccent(ThemeData light, ThemeData dark) {
    if (windowsAccentColor == null || !ss.settings.useWindowsAccent.value) {
      return Tuple2(light, dark);
    }

    CorePalette palette = CorePalette.of(windowsAccentColor!.value);

    light = light.copyWith(
      colorScheme: light.colorScheme.copyWith(
        primary: Color(palette.primary.get(40)),
        onPrimary: Color(palette.primary.get(100)),
        primaryContainer: Color(palette.primary.get(90)),
        onPrimaryContainer: Color(palette.primary.get(10)),
        secondary: light.colorScheme.secondary.harmonizeWith(Color(palette.secondary.get(40))),
        onSecondary: light.colorScheme.onSecondary.harmonizeWith(Color(palette.secondary.get(100))),
        secondaryContainer: light.colorScheme.secondaryContainer.harmonizeWith(Color(palette.secondary.get(90))),
        onSecondaryContainer: light.colorScheme.onSecondaryContainer.harmonizeWith(Color(palette.secondary.get(10))),
        tertiary: light.colorScheme.tertiary.harmonizeWith(Color(palette.tertiary.get(40))),
        onTertiary: light.colorScheme.onTertiary.harmonizeWith(Color(palette.tertiary.get(100))),
        tertiaryContainer: light.colorScheme.tertiaryContainer.harmonizeWith(Color(palette.tertiary.get(90))),
        onTertiaryContainer: light.colorScheme.onTertiaryContainer.harmonizeWith(Color(palette.tertiary.get(10))),
        error: light.colorScheme.error.harmonizeWith(Color(palette.error.get(40))),
        onError: light.colorScheme.onError.harmonizeWith(Color(palette.error.get(100))),
        errorContainer: light.colorScheme.errorContainer.harmonizeWith(Color(palette.error.get(90))),
        onErrorContainer: light.colorScheme.onErrorContainer.harmonizeWith(Color(palette.error.get(10))),
        background: light.colorScheme.background.harmonizeWith(Color(palette.neutral.get(99))),
        onBackground: light.colorScheme.onBackground.harmonizeWith(Color(palette.neutral.get(10))),
        surface: light.colorScheme.surface.harmonizeWith(Color(palette.neutral.get(99))),
        onSurface: light.colorScheme.onSurface.harmonizeWith(Color(palette.neutral.get(10))),
        surfaceVariant: light.colorScheme.surfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(90))),
        onSurfaceVariant: light.colorScheme.onSurfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(30))),
        outline: light.colorScheme.outline.harmonizeWith(Color(palette.neutralVariant.get(50))),
        shadow: light.colorScheme.shadow.harmonizeWith(Color(palette.neutral.get(0))),
        inverseSurface: light.colorScheme.inverseSurface.harmonizeWith(Color(palette.neutral.get(20))),
        onInverseSurface: light.colorScheme.onInverseSurface.harmonizeWith(Color(palette.neutral.get(95))),
        inversePrimary: light.colorScheme.inversePrimary.harmonizeWith(Color(palette.primary.get(80))),
      ),
    );
    dark = dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(
        primary: Color(palette.primary.get(80)),
        onPrimary: Color(palette.primary.get(20)),
        primaryContainer: Color(palette.primary.get(30)),
        onPrimaryContainer: Color(palette.primary.get(90)),
        secondary: dark.colorScheme.secondary.harmonizeWith(Color(palette.secondary.get(80))),
        onSecondary: dark.colorScheme.onSecondary.harmonizeWith(Color(palette.secondary.get(20))),
        secondaryContainer: dark.colorScheme.secondaryContainer.harmonizeWith(Color(palette.secondary.get(30))),
        onSecondaryContainer: dark.colorScheme.onSecondaryContainer.harmonizeWith(Color(palette.secondary.get(90))),
        tertiary: dark.colorScheme.tertiary.harmonizeWith(Color(palette.tertiary.get(80))),
        onTertiary: dark.colorScheme.onTertiary.harmonizeWith(Color(palette.tertiary.get(20))),
        tertiaryContainer: dark.colorScheme.tertiaryContainer.harmonizeWith(Color(palette.tertiary.get(30))),
        onTertiaryContainer: dark.colorScheme.onTertiaryContainer.harmonizeWith(Color(palette.tertiary.get(90))),
        error: dark.colorScheme.error.harmonizeWith(Color(palette.error.get(80))),
        onError: dark.colorScheme.onError.harmonizeWith(Color(palette.error.get(20))),
        errorContainer: dark.colorScheme.errorContainer.harmonizeWith(Color(palette.error.get(30))),
        onErrorContainer: dark.colorScheme.onErrorContainer.harmonizeWith(Color(palette.error.get(80))),
        background: dark.colorScheme.background.harmonizeWith(Color(palette.neutral.get(10))),
        onBackground: dark.colorScheme.onBackground.harmonizeWith(Color(palette.neutral.get(90))),
        surface: dark.colorScheme.surface.harmonizeWith(Color(palette.neutral.get(10))),
        onSurface: dark.colorScheme.onSurface.harmonizeWith(Color(palette.neutral.get(90))),
        surfaceVariant: dark.colorScheme.surfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(30))),
        onSurfaceVariant: dark.colorScheme.onSurfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(80))),
        outline: dark.colorScheme.outline.harmonizeWith(Color(palette.neutralVariant.get(60))),
        shadow: dark.colorScheme.shadow.harmonizeWith(Color(palette.neutral.get(0))),
        inverseSurface: dark.colorScheme.inverseSurface.harmonizeWith(Color(palette.neutral.get(90))),
        onInverseSurface: dark.colorScheme.onInverseSurface.harmonizeWith(Color(palette.neutral.get(20))),
        inversePrimary: dark.colorScheme.inversePrimary.harmonizeWith(Color(palette.primary.get(40))),
      ),
    );
    return Tuple2(light, dark);
  }
}
