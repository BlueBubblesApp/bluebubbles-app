import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide GetStringUtils;
import 'package:material_color_utilities/material_color_utilities.dart' as mui_utils;
import 'package:simple_animations/simple_animations.dart';
import 'package:bluebubbles/models/models.dart' show ThemePair;
import 'package:universal_io/io.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
ThemesService get ThemeSvc => GetIt.I<ThemesService>();

enum MaterialYouVariant {
  base,
  vibrant,
  expressive,
  soft,
  neutral,
  lagoon,
  sunset,
  neonPop,
  earthy,
}

class ThemesService {
  static const String materialYouLightName = "Material You (Light)";
  static const String materialYouDarkName = "Material You (Dark)";
  static const String _adaptiveBackgroundThemePrefix = "__adaptive_background_theme__";
  static const Map<MaterialYouVariant, String> _variantTokens = {
    MaterialYouVariant.base: "Material You",
    MaterialYouVariant.vibrant: "Material You - Vibrant",
    MaterialYouVariant.expressive: "Material You - Expressive",
    MaterialYouVariant.soft: "Material You - Soft",
    MaterialYouVariant.neutral: "Material You - Neutral",
    MaterialYouVariant.lagoon: "Material You - Style 1",
    MaterialYouVariant.sunset: "Material You - Style 2",
    MaterialYouVariant.neonPop: "Material You - Style 3",
    MaterialYouVariant.earthy: "Material You - Style 4",
  };
  mui_utils.CorePalette? monetPalette;
  Color? desktopAccentColor;

  final Rx<MovieTween> gradientTween = Rx<MovieTween>(MovieTween()
    ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
        .tween("color1", Tween<double>(begin: 0, end: 0.2))
    ..scene(begin: Duration.zero, duration: const Duration(seconds: 3))
        .tween("color2", Tween<double>(begin: 0.8, end: 1)));

  Future<void> init() async {
    // on Linux these block the GTK thread and freeze the splash
    // spinner; defer to initDynamicColorsDeferred (post-splash) instead.
    if (!(kIsDesktop && Platform.isLinux)) {
      monetPalette = await DynamicColorPlugin.getCorePalette();
      if (kIsDesktop) {
        desktopAccentColor = await DynamicColorPlugin.getAccentColor();
      }
    }

    // Re-save preset themes so any stale DB values (e.g. old surfaceContainerHighest)
    // are always overwritten with the current static definitions.
    if (!kIsWeb) {
      for (final preset in defaultThemes) {
        preset.save(updateIfNotAbsent: true);
      }
      _refreshMaterialYouThemePresets();
    }
  }

  /// Linux-only: dynamic-color fetch deferred out of [init]; call post-splash.
  Future<void> initDynamicColorsDeferred() async {
    if (!(kIsDesktop && Platform.isLinux)) return;
    monetPalette = await DynamicColorPlugin.getCorePalette();
    desktopAccentColor = await DynamicColorPlugin.getAccentColor();
    _refreshMaterialYouThemePresets();
  }

  static final oledDarkTheme = FlexColorScheme(
    textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      surface: Colors.black,
      surfaceContainerHighest: HexColor("323332"),
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
        fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
        height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
        color: Colors.white,
      ),
    ),
  ]);

  static final nordDarkTheme = FlexColorScheme(
    textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: createMaterialColor(HexColor("5E81AC")),
      accentColor: HexColor("88C0D0"),
      brightness: Brightness.dark,
    ).copyWith(
      surface: HexColor("3B4252"),
      primaryContainer: HexColor("49688e"),
      outline: Colors.grey,
    ),
    useMaterial3: true,
  ).toTheme.copyWith(splashFactory: InkSparkle.splashFactory, extensions: [
    BubbleText(
      bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
        fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
        height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
      ),
    ),
  ]);

  static final whiteLightTheme = () {
    final base = FlexColorScheme(
      textTheme: Typography.englishLike2021.merge(Typography.blackMountainView),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        surface: Colors.white,
        error: Colors.red,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ).toTheme;
    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.white,
        surfaceContainerHighest: HexColor('F2F2F6'),
      ),
      extensions: [
        BubbleColors(
          iMessageBubbleColor: HexColor("1982FC"),
          oniMessageBubbleColor: Colors.white,
          smsBubbleColor: HexColor("43CC47"),
          onSmsBubbleColor: Colors.white,
          receivedBubbleColor: HexColor("e9e9ea"),
          onReceivedBubbleColor: Colors.black,
        ),
        BubbleText(
          bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
            fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
            height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
          ),
        ),
      ],
    );
  }();

  static String materialYouThemeName(MaterialYouVariant variant, Brightness brightness) {
    final base = _variantTokens[variant]!;
    return variant == MaterialYouVariant.base
        ? (brightness == Brightness.dark ? materialYouDarkName : materialYouLightName)
        : "$base (${brightness == Brightness.dark ? "Dark" : "Light"})";
  }

  static bool isMaterialYouThemeName(String name) {
    return MaterialYouVariant.values
        .expand((variant) => [
              materialYouThemeName(variant, Brightness.light),
              materialYouThemeName(variant, Brightness.dark),
            ])
        .contains(name);
  }

  static String materialYouDisplayName(String name) {
    if (!isMaterialYouThemeName(name)) return name;
    if (name == materialYouLightName || name == materialYouDarkName) return "Default";
    if (name.contains("Vibrant")) return "Vibrant";
    if (name.contains("Expressive")) return "Expressive";
    if (name.contains("Soft")) return "Soft";
    if (name.contains("Neutral")) return "Neutral";
    if (name.contains("Style 1") || name.contains("Drift") || name.contains("Lagoon")) return "Style 1";
    if (name.contains("Style 2") || name.contains("Ember") || name.contains("Sunset")) return "Style 2";
    if (name.contains("Style 3") || name.contains("Bloom") || name.contains("Neon Pop")) return "Style 3";
    if (name.contains("Style 4") || name.contains("Moss") || name.contains("Earthy")) return "Style 4";
    return "Default";
  }

  static int materialYouSortOrder(String name) {
    if (name == materialYouLightName || name == materialYouDarkName) return 0;
    if (name.contains("Vibrant")) return 1;
    if (name.contains("Expressive")) return 2;
    if (name.contains("Soft")) return 3;
    if (name.contains("Neutral")) return 4;
    if (name.contains("Style 1") || name.contains("Drift") || name.contains("Lagoon")) return 5;
    if (name.contains("Style 2") || name.contains("Ember") || name.contains("Sunset")) return 6;
    if (name.contains("Style 3") || name.contains("Bloom") || name.contains("Neon Pop")) return 7;
    if (name.contains("Style 4") || name.contains("Moss") || name.contains("Earthy")) return 8;
    return 99;
  }

  static String adaptiveBackgroundThemeName(
    String scopeKey, {
    required MaterialYouVariant variant,
    required Brightness brightness,
  }) {
    return "$_adaptiveBackgroundThemePrefix::$scopeKey::${brightness.name}::${variant.name}";
  }

  static bool isAdaptiveBackgroundThemeName(String name) {
    return name.startsWith(_adaptiveBackgroundThemePrefix);
  }

  static bool isGeneratedMaterialThemeName(String name) {
    return isMaterialYouThemeName(name) || isAdaptiveBackgroundThemeName(name);
  }

  static String adaptiveBackgroundThemeDisplayName(String name) {
    if (!isAdaptiveBackgroundThemeName(name)) return name;
    final parts = name.split("::");
    if (parts.length < 4) return "Default";
    final variant = MaterialYouVariant.values.firstWhereOrNull((value) => value.name == parts[3]);
    if (variant == null) return "Default";
    return materialYouDisplayName(materialYouThemeName(variant, Brightness.light));
  }

  static Color _tone(Color color, {double sat = 0, double light = 0, double hue = 0}) {
    final hsl = HSLColor.fromColor(color);
    final nHue = (hsl.hue + hue) % 360;
    final nSat = (hsl.saturation + sat).clamp(0.0, 1.0);
    final nLight = (hsl.lightness + light).clamp(0.0, 1.0);
    return hsl.withHue(nHue).withSaturation(nSat).withLightness(nLight).toColor();
  }

  static ThemeData materialYouTheme(
    Brightness brightness, {
    mui_utils.CorePalette? palette,
    MaterialYouVariant variant = MaterialYouVariant.base,
  }) {
    final resolvedPalette = palette;
    if (resolvedPalette == null) {
      return brightness == Brightness.dark ? oledDarkTheme : whiteLightTheme;
    }

    final bool isDark = brightness == Brightness.dark;
    final satDelta = switch (variant) {
      MaterialYouVariant.base => 0.0,
      MaterialYouVariant.vibrant => 0.24,
      MaterialYouVariant.expressive => 0.14,
      MaterialYouVariant.soft => -0.30,
      MaterialYouVariant.neutral => -0.46,
      MaterialYouVariant.lagoon => 0.04,
      MaterialYouVariant.sunset => 0.06,
      MaterialYouVariant.neonPop => 0.10,
      MaterialYouVariant.earthy => -0.18,
    };
    final hueDelta = switch (variant) {
      MaterialYouVariant.base => 0.0,
      MaterialYouVariant.vibrant => 0.0,
      MaterialYouVariant.expressive => 22.0,
      MaterialYouVariant.soft => -16.0,
      MaterialYouVariant.neutral => 0.0,
      MaterialYouVariant.lagoon => -14.0,
      MaterialYouVariant.sunset => 20.0,
      MaterialYouVariant.neonPop => 6.0,
      MaterialYouVariant.earthy => -6.0,
    };
    final lightDelta = switch (variant) {
      MaterialYouVariant.base => 0.0,
      MaterialYouVariant.vibrant => isDark ? -0.03 : 0.0,
      MaterialYouVariant.expressive => isDark ? -0.05 : 0.01,
      MaterialYouVariant.soft => isDark ? 0.01 : 0.08,
      MaterialYouVariant.neutral => isDark ? -0.03 : 0.03,
      MaterialYouVariant.lagoon => isDark ? -0.02 : 0.01,
      MaterialYouVariant.sunset => isDark ? -0.01 : 0.03,
      MaterialYouVariant.neonPop => isDark ? -0.03 : 0.01,
      MaterialYouVariant.earthy => isDark ? 0.0 : 0.02,
    };
    Color tone(Color color) => _tone(color, sat: satDelta, light: lightDelta, hue: hueDelta);

    Color primary = tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)));
    Color onPrimary = tone(Color(resolvedPalette.primary.get(isDark ? 20 : 100)));
    Color primaryContainer = tone(Color(resolvedPalette.primary.get(isDark ? 30 : 90)));
    Color onPrimaryContainer = tone(Color(resolvedPalette.primary.get(isDark ? 90 : 10)));
    Color secondary = tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)));
    Color onSecondary = tone(Color(resolvedPalette.secondary.get(isDark ? 20 : 100)));
    Color secondaryContainer = tone(Color(resolvedPalette.secondary.get(isDark ? 30 : 90)));
    Color onSecondaryContainer = tone(Color(resolvedPalette.secondary.get(isDark ? 90 : 10)));
    Color tertiary = tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)));
    Color onTertiary = tone(Color(resolvedPalette.tertiary.get(isDark ? 20 : 100)));
    Color tertiaryContainer = tone(Color(resolvedPalette.tertiary.get(isDark ? 30 : 90)));
    Color onTertiaryContainer = tone(Color(resolvedPalette.tertiary.get(isDark ? 90 : 10)));
    Color surface = Color(resolvedPalette.neutral.get(isDark ? 10 : 99));
    Color onSurface = Color(resolvedPalette.neutral.get(isDark ? 90 : 10));
    Color surfaceVariant = Color(resolvedPalette.neutralVariant.get(isDark ? 30 : 90));
    Color onSurfaceVariant = Color(resolvedPalette.neutralVariant.get(isDark ? 80 : 30));
    Color outline = Color(resolvedPalette.neutralVariant.get(isDark ? 60 : 50));
    Color outlineVariant = Color(resolvedPalette.neutralVariant.get(isDark ? 30 : 80));

    if (variant == MaterialYouVariant.vibrant) {
      // Make vibrant clearly "punchy primary" while muting supporting accents.
      primary = _tone(primary, sat: 0.14, light: isDark ? 0.0 : -0.02);
      onPrimary = _tone(onPrimary, sat: 0.05);
      primaryContainer = _tone(primaryContainer, sat: 0.12, light: isDark ? -0.01 : 0.0);
      secondary = _tone(secondary, sat: -0.10, hue: 10);
      tertiary = _tone(tertiary, sat: -0.12, hue: -10);
      secondaryContainer = _tone(secondaryContainer, sat: -0.12, light: isDark ? 0.0 : 0.01);
      tertiaryContainer = _tone(tertiaryContainer, sat: -0.14, light: isDark ? 0.0 : 0.01);
    } else if (variant == MaterialYouVariant.expressive) {
      // Expressive: rotate primary away from base and swap accent personalities.
      primary = _tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)), sat: 0.06, hue: 20);
      onPrimary = _tone(Color(resolvedPalette.primary.get(isDark ? 20 : 100)), sat: 0.04, hue: 14);
      primaryContainer = _tone(Color(resolvedPalette.primary.get(isDark ? 30 : 90)), sat: 0.05, hue: 18);
      onPrimaryContainer = _tone(Color(resolvedPalette.primary.get(isDark ? 90 : 10)), sat: 0.04, hue: 14);

      secondary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)), sat: 0.08, hue: 24);
      onSecondary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 20 : 100)), sat: 0.04, hue: 16);
      secondaryContainer = _tone(Color(resolvedPalette.tertiary.get(isDark ? 30 : 90)), sat: 0.06, hue: 22);
      onSecondaryContainer = _tone(Color(resolvedPalette.tertiary.get(isDark ? 90 : 10)), sat: 0.04, hue: 16);

      tertiary = _tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)), sat: 0.04, hue: -18);
      onTertiary = _tone(Color(resolvedPalette.secondary.get(isDark ? 20 : 100)), sat: 0.03, hue: -12);
      tertiaryContainer = _tone(Color(resolvedPalette.secondary.get(isDark ? 30 : 90)), sat: 0.03, hue: -16);
      onTertiaryContainer = _tone(Color(resolvedPalette.secondary.get(isDark ? 90 : 10)), sat: 0.03, hue: -12);
    } else if (variant == MaterialYouVariant.soft) {
      // Soft: low-chroma, airy surfaces, subdued accents.
      surface = _tone(surface, sat: -0.12, light: isDark ? 0.05 : 0.04, hue: -10);
      surfaceVariant = _tone(surfaceVariant, sat: -0.14, light: isDark ? 0.04 : 0.05, hue: -10);
      primary = _tone(primary, sat: -0.18, light: isDark ? 0.05 : 0.05, hue: -6);
      secondary = _tone(secondary, sat: -0.20, light: isDark ? 0.05 : 0.05, hue: -8);
      tertiary = _tone(tertiary, sat: -0.20, light: isDark ? 0.05 : 0.05, hue: -8);
      primaryContainer = _tone(primaryContainer, sat: -0.16, light: isDark ? 0.04 : 0.04);
      secondaryContainer = _tone(secondaryContainer, sat: -0.18, light: isDark ? 0.04 : 0.05);
      tertiaryContainer = _tone(tertiaryContainer, sat: -0.18, light: isDark ? 0.04 : 0.05);
      outline = _tone(outline, sat: -0.16, light: isDark ? 0.03 : 0.02);
      outlineVariant = _tone(outlineVariant, sat: -0.16, light: isDark ? 0.03 : 0.02);
    } else if (variant == MaterialYouVariant.neutral) {
      // Neutral: near-monochrome, minimal accent saturation.
      primary = _tone(primary, sat: -0.28);
      secondary = _tone(secondary, sat: -0.42);
      tertiary = _tone(tertiary, sat: -0.42);
      primaryContainer = _tone(primaryContainer, sat: -0.34);
      secondaryContainer = _tone(secondaryContainer, sat: -0.38);
      tertiaryContainer = _tone(tertiaryContainer, sat: -0.38);
      surface = _tone(surface, sat: -0.22);
      surfaceVariant = _tone(surfaceVariant, sat: -0.24);
      onSurface = _tone(onSurface, sat: -0.16);
      onSurfaceVariant = _tone(onSurfaceVariant, sat: -0.16);
      outline = _tone(outline, sat: -0.22);
      outlineVariant = _tone(outlineVariant, sat: -0.22);
    } else if (variant == MaterialYouVariant.lagoon) {
      // Secondary-led cool variant.
      primary = _tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)), sat: 0.06, hue: -10);
      onPrimary = _tone(Color(resolvedPalette.secondary.get(isDark ? 20 : 100)), sat: 0.06, hue: -6);
      primaryContainer = _tone(Color(resolvedPalette.secondary.get(isDark ? 30 : 90)), sat: 0.04, hue: -8);
      onPrimaryContainer = _tone(Color(resolvedPalette.secondary.get(isDark ? 90 : 10)), sat: 0.08, hue: -8);
      secondary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)), sat: -0.04, hue: -16);
      tertiary = _tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)), sat: -0.12, hue: -10);
    } else if (variant == MaterialYouVariant.sunset) {
      // Tertiary-led warm variant.
      primary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)), sat: 0.08, hue: 12);
      onPrimary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 20 : 100)), sat: 0.08, hue: 10);
      primaryContainer = _tone(Color(resolvedPalette.tertiary.get(isDark ? 30 : 90)), sat: 0.06, hue: 12);
      onPrimaryContainer = _tone(Color(resolvedPalette.tertiary.get(isDark ? 90 : 10)), sat: 0.08, hue: 10);
      secondary = _tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)), sat: -0.08, hue: 6);
      tertiary = _tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)), sat: -0.05, hue: 14);
      surfaceVariant = _tone(surfaceVariant, sat: 0.03, hue: 8);
    } else if (variant == MaterialYouVariant.neonPop) {
      // High-contrast accent swap for maximal separation.
      primary = _tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)), sat: 0.10, hue: 14);
      onPrimary = _tone(Color(resolvedPalette.secondary.get(isDark ? 20 : 100)), sat: 0.10, hue: 12);
      secondary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)), sat: -0.02, hue: -16);
      onSecondary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 20 : 100)), sat: 0.10, hue: -14);
      tertiary = _tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)), sat: -0.06, hue: 6);
      primaryContainer = _tone(Color(resolvedPalette.secondary.get(isDark ? 30 : 90)), sat: 0.06, hue: 14);
      secondaryContainer = _tone(Color(resolvedPalette.tertiary.get(isDark ? 30 : 90)), sat: -0.04, hue: -14);
      tertiaryContainer = _tone(Color(resolvedPalette.primary.get(isDark ? 30 : 90)), sat: -0.08, hue: 4);
    } else if (variant == MaterialYouVariant.earthy) {
      // Muted warm/olive leaning variant.
      primary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 80 : 40)), sat: -0.08, hue: -10);
      onPrimary = _tone(Color(resolvedPalette.tertiary.get(isDark ? 20 : 100)), sat: -0.02, hue: -8);
      secondary = _tone(Color(resolvedPalette.secondary.get(isDark ? 80 : 40)), sat: -0.16, hue: -16);
      tertiary = _tone(Color(resolvedPalette.primary.get(isDark ? 80 : 40)), sat: -0.20, hue: -20);
      surface = _tone(surface, sat: -0.04, light: isDark ? 0.01 : 0.02, hue: -8);
      surfaceVariant = _tone(surfaceVariant, sat: -0.06, light: isDark ? 0.01 : 0.02, hue: -10);
    }

    final base = FlexColorScheme(
      textTheme: Typography.englishLike2021.merge(isDark ? Typography.whiteMountainView : Typography.blackMountainView),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: Color(resolvedPalette.error.get(isDark ? 80 : 40)),
        onError: Color(resolvedPalette.error.get(isDark ? 20 : 100)),
        errorContainer: Color(resolvedPalette.error.get(isDark ? 30 : 90)),
        onErrorContainer: Color(resolvedPalette.error.get(isDark ? 80 : 10)),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceVariant,
        surfaceVariant: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        shadow: Color(resolvedPalette.neutral.get(0)),
        inverseSurface: Color(resolvedPalette.neutral.get(isDark ? 90 : 20)),
        onInverseSurface: Color(resolvedPalette.neutral.get(isDark ? 20 : 95)),
        inversePrimary: _tone(primary, light: isDark ? -0.18 : 0.18),
        scrim: Color(resolvedPalette.neutral.get(0)),
      ),
      useMaterial3: true,
    ).toTheme;

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      extensions: [
        BubbleColors(
          iMessageBubbleColor: primary,
          oniMessageBubbleColor: onPrimary,
          smsBubbleColor: secondary,
          onSmsBubbleColor: onSecondary,
          receivedBubbleColor: surfaceVariant,
          onReceivedBubbleColor: onSurfaceVariant,
        ),
        BubbleText(
          bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
            fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
            height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
            color: Color(resolvedPalette.neutral.get(isDark ? 90 : 10)),
          ),
        ),
      ],
    );
  }

  static List<ThemeStruct> get defaultThemes => [
        ThemeStruct(name: "Bright White", themeData: whiteLightTheme),
        ThemeStruct(name: "OLED Dark", themeData: oledDarkTheme),
        ...MaterialYouVariant.values.expand((variant) => [
              ThemeStruct(
                  name: materialYouThemeName(variant, Brightness.light),
                  themeData: materialYouTheme(Brightness.light, variant: variant)),
              ThemeStruct(
                  name: materialYouThemeName(variant, Brightness.dark),
                  themeData: materialYouTheme(Brightness.dark, variant: variant)),
            ]),
        ThemeStruct(name: "Nord Theme", themeData: nordDarkTheme),
        ThemeStruct(name: "Music Theme ☀", themeData: whiteLightTheme),
        ThemeStruct(name: "Music Theme 🌙", themeData: oledDarkTheme),
        ...FlexScheme.values
            .where((e) => e != FlexScheme.custom)
            .map((e) => [
                  ThemeStruct(
                    name: "${e.name.split(RegExp(r"(?=[A-Z])")).join(" ").capitalize} ☀",
                    themeData: FlexThemeData.light(
                            scheme: e, surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold, blendLevel: 40)
                        .copyWith(
                            textTheme: Typography.englishLike2021.merge(Typography.blackMountainView),
                            splashFactory: InkSparkle.splashFactory,
                            extensions: [
                          BubbleText(
                            bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
                              fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
                              height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
                            ),
                          ),
                        ]),
                  ),
                  ThemeStruct(
                    name: "${e.name.split(RegExp(r"(?=[A-Z])")).join(" ").capitalize} 🌙",
                    themeData: FlexThemeData.dark(
                            scheme: e, surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold, blendLevel: 40)
                        .copyWith(
                            textTheme: Typography.englishLike2021.merge(Typography.whiteMountainView),
                            splashFactory: InkSparkle.splashFactory,
                            extensions: [
                          BubbleText(
                            bubbleText: Typography.englishLike2021.bodyMedium!.copyWith(
                              fontSize: ThemeStruct.defaultTextSizes["bubbleText"],
                              height: Typography.englishLike2021.bodyMedium!.height! * 0.85,
                            ),
                          ),
                        ]),
                  ),
                ])
            .flattened,
      ];

  Skins get skin => SettingsSvc.settings.skin.value;

  bool get isMaterialYouSelectedLight => isMaterialYouThemeName(PrefsSvc.theme.getSelectedLightTheme() ?? '');
  bool get isMaterialYouSelectedDark => isMaterialYouThemeName(PrefsSvc.theme.getSelectedDarkTheme() ?? '');
  bool get isAnyMaterialYouSelected => isMaterialYouSelectedLight || isMaterialYouSelectedDark;
  bool isMaterialYouActive(BuildContext context) =>
      inDarkMode(context) ? isMaterialYouSelectedDark : isMaterialYouSelectedLight;

  ScrollPhysics get scrollPhysics {
    if (SettingsSvc.settings.skin.value == Skins.iOS) {
      return const AlwaysScrollableScrollPhysics(
        parent: CustomBouncingScrollPhysics(),
      );
    } else {
      return const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      );
    }
  }

  bool inDarkMode(BuildContext context) {
    final mode = AdaptiveTheme.maybeOf(context)?.mode;
    if (mode == null) return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    return mode == AdaptiveThemeMode.dark ||
        (mode == AdaptiveThemeMode.system && PlatformDispatcher.instance.platformBrightness == Brightness.dark);
  }

  bool isGradientBg(BuildContext context) {
    if (inDarkMode(context)) {
      return ThemeStruct.getDarkTheme().gradientBg;
    } else {
      return ThemeStruct.getLightTheme().gradientBg;
    }
  }

  Future<void> refreshMonet(BuildContext context) async {
    monetPalette = await DynamicColorPlugin.getCorePalette();
    _refreshMaterialYouThemePresets();
    if (!context.mounted) return;
    _loadTheme(context);
  }

  void _refreshMaterialYouThemePresets() {
    if (kIsWeb) return;
    for (final variant in MaterialYouVariant.values) {
      final light = ThemeStruct.findOne(materialYouThemeName(variant, Brightness.light));
      if (light != null) {
        light.data = materialYouTheme(Brightness.light, palette: monetPalette, variant: variant);
        light.save();
      }
      final dark = ThemeStruct.findOne(materialYouThemeName(variant, Brightness.dark));
      if (dark != null) {
        dark.data = materialYouTheme(Brightness.dark, palette: monetPalette, variant: variant);
        dark.save();
      }
    }
  }

  Future<void> refreshDesktopAccent(BuildContext context) async {
    desktopAccentColor = await DynamicColorPlugin.getAccentColor();
    if (!context.mounted) return;
    _loadTheme(context);
  }

  void updateMusicTheme(BuildContext context, Uint8List art) async {
    final darkTheme = ThemeStruct.getThemes().firstWhere((e) => e.name == "Music Theme 🌙");
    final lightTheme = ThemeStruct.getThemes().firstWhere((e) => e.name == "Music Theme ☀");
    final lightScheme = await ColorScheme.fromImageProvider(provider: MemoryImage(art), brightness: Brightness.light);
    final darkScheme = await ColorScheme.fromImageProvider(provider: MemoryImage(art), brightness: Brightness.dark);
    lightTheme.data = lightTheme.data.copyWith(colorScheme: lightScheme);
    darkTheme.data = darkTheme.data.copyWith(colorScheme: darkScheme);
    changeTheme(Get.context!, light: lightTheme, dark: darkTheme);
  }

  // ---------------------------------------------------------------------------
  // Adaptive Chat Theme — per-chat theme generation from background image
  // ---------------------------------------------------------------------------

  static final Map<String, Map<MaterialYouVariant, ({ThemeData light, ThemeData dark})>> _adaptiveThemeCache = {};

  static void clearAdaptiveThemeCache(String path) {
    _adaptiveThemeCache.remove(path);
  }

  /// Generates all 9 Material You variant [ThemeData] pairs (light + dark) by
  /// extracting the dominant seed color from the image at [imagePath] and
  /// feeding it through [CorePalette.of] + [materialYouTheme].
  ///
  /// Results are cached by file path; call [clearAdaptiveThemeCache] when the
  /// background image is replaced.
  static Future<Map<MaterialYouVariant, ({ThemeData light, ThemeData dark})>> generateAdaptiveThemesFromImage(
    String imagePath,
  ) async {
    if (_adaptiveThemeCache.containsKey(imagePath)) {
      return _adaptiveThemeCache[imagePath]!;
    }

    // Extract the dominant color via Flutter's built-in quantizer.
    final provider = FileImage(File(imagePath));
    final lightScheme = await ColorScheme.fromImageProvider(
      provider: provider,
      brightness: Brightness.light,
    );

    // Build a CorePalette from the dominant seed color so we can reuse all 9
    // existing variant algorithms in materialYouTheme().
    final corePalette = mui_utils.CorePalette.of(lightScheme.primary.value);

    final result = <MaterialYouVariant, ({ThemeData light, ThemeData dark})>{};
    for (final variant in MaterialYouVariant.values) {
      result[variant] = (
        light: materialYouTheme(Brightness.light, palette: corePalette, variant: variant),
        dark: materialYouTheme(Brightness.dark, palette: corePalette, variant: variant),
      );
    }

    _adaptiveThemeCache[imagePath] = result;
    return result;
  }

  static Future<List<ThemeStruct>> upsertAdaptiveBackgroundThemesFromImage(
    String imagePath, {
    required String scopeKey,
  }) async {
    final generated = await generateAdaptiveThemesFromImage(imagePath);
    final results = <ThemeStruct>[];

    for (final variant in MaterialYouVariant.values) {
      final pair = generated[variant]!;
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final name = adaptiveBackgroundThemeName(
          scopeKey,
          variant: variant,
          brightness: brightness,
        );
        final data = brightness == Brightness.dark ? pair.dark : pair.light;
        final struct = ThemeStruct.findOne(name) ?? ThemeStruct(name: name, themeData: data);
        struct
          ..name = name
          ..data = data
          ..gradientBg = false
          ..googleFont = 'Default';
        struct.save();
        results.add(struct);
      }
    }

    return results;
  }

  void _loadTheme(BuildContext context, {ThemeStruct? lightOverride, ThemeStruct? darkOverride}) {
    // Set the theme to match those of the settings
    ThemeData light = (lightOverride ?? ThemeStruct.getLightTheme()).data;
    ThemeData dark = (darkOverride ?? ThemeStruct.getDarkTheme()).data;

    final pair = getStructsFromData(light, dark);
    light = pair.light;
    dark = pair.dark;

    AdaptiveTheme.of(context).setTheme(
      light: light,
      dark: dark,
    );
  }

  ThemePair getStructsFromData(ThemeData light, ThemeData dark) {
    return Platform.isWindows ? _applyWindowsAccent(light, dark) : ThemePair(light: light, dark: dark);
  }

  Future<ThemeStruct> revertToPreviousDarkTheme() async {
    List<ThemeStruct> allThemes = ThemeStruct.getThemes();
    final darkName = PrefsSvc.theme.getPreviousDarkTheme();
    ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == darkName);

    previous ??= defaultThemes.firstWhere((element) => element.name == "OLED Dark");

    // Remove the previous flags
    await PrefsSvc.theme.clearPreviousDarkTheme();

    return previous;
  }

  Future<ThemeStruct> revertToPreviousLightTheme() async {
    List<ThemeStruct> allThemes = ThemeStruct.getThemes();
    final lightName = PrefsSvc.theme.getPreviousLightTheme();
    ThemeStruct? previous = allThemes.firstWhereOrNull((e) => e.name == lightName);

    previous ??= defaultThemes.firstWhere((element) => element.name == "Bright White");

    // Remove the previous flags
    await PrefsSvc.theme.clearPreviousLightTheme();

    return previous;
  }

  Future<void> changeTheme(BuildContext context, {ThemeStruct? light, ThemeStruct? dark}) async {
    light?.save();
    dark?.save();
    await PrefsSvc.theme.setSelectedThemes(
      lightTheme: light?.name,
      darkTheme: dark?.name,
    );

    if (!context.mounted) return;
    _loadTheme(context);
  }

  ThemePair _applyWindowsAccent(ThemeData light, ThemeData dark) {
    if (desktopAccentColor == null || !SettingsSvc.settings.useDesktopAccent.value) {
      return ThemePair(light: light, dark: dark);
    }

    CorePalette palette = CorePalette.of(desktopAccentColor!.value);

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
        surface: light.colorScheme.surface.harmonizeWith(Color(palette.neutral.get(99))),
        onSurface: light.colorScheme.onSurface.harmonizeWith(Color(palette.neutral.get(10))),
        surfaceVariant: light.colorScheme.surfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(90))),
        onSurfaceVariant: light.colorScheme.onSurfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(30))),
        outline: light.colorScheme.outline.harmonizeWith(Color(palette.neutralVariant.get(50))),
        outlineVariant: light.colorScheme.outlineVariant.harmonizeWith(Color(palette.neutralVariant.get(80))),
        shadow: light.colorScheme.shadow.harmonizeWith(Color(palette.neutral.get(0))),
        inverseSurface: light.colorScheme.inverseSurface.harmonizeWith(Color(palette.neutral.get(20))),
        onInverseSurface: light.colorScheme.onInverseSurface.harmonizeWith(Color(palette.neutral.get(95))),
        inversePrimary: light.colorScheme.inversePrimary.harmonizeWith(Color(palette.primary.get(80))),
        scrim: light.colorScheme.outlineVariant.harmonizeWith(Color(palette.neutral.get(0))),
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
        surface: dark.colorScheme.surface.harmonizeWith(Color(palette.neutral.get(10))),
        onSurface: dark.colorScheme.onSurface.harmonizeWith(Color(palette.neutral.get(90))),
        surfaceVariant: dark.colorScheme.surfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(30))),
        onSurfaceVariant: dark.colorScheme.onSurfaceVariant.harmonizeWith(Color(palette.neutralVariant.get(80))),
        outline: dark.colorScheme.outline.harmonizeWith(Color(palette.neutralVariant.get(60))),
        outlineVariant: dark.colorScheme.outlineVariant.harmonizeWith(Color(palette.neutralVariant.get(30))),
        shadow: dark.colorScheme.shadow.harmonizeWith(Color(palette.neutral.get(0))),
        inverseSurface: dark.colorScheme.inverseSurface.harmonizeWith(Color(palette.neutral.get(90))),
        onInverseSurface: dark.colorScheme.onInverseSurface.harmonizeWith(Color(palette.neutral.get(20))),
        inversePrimary: dark.colorScheme.inversePrimary.harmonizeWith(Color(palette.primary.get(40))),
        scrim: dark.colorScheme.outlineVariant.harmonizeWith(Color(palette.neutral.get(0))),
      ),
    );
    return ThemePair(light: light, dark: dark);
  }
}
