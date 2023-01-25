import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'colors.dart';

typedef ColorSwatch = Map<int, Color>;
typedef ColorFilter = Oklch Function(Oklch);

abstract class ColorScheme {
  const ColorScheme();

  ColorSwatch get neutral1;
  ColorSwatch get neutral2;
  ColorSwatch get accent1;
  ColorSwatch get accent2;
  ColorSwatch get accent3;

  // Helpers
  List<ColorSwatch> get neutralColors => [neutral1, neutral2];
  List<ColorSwatch> get accentColors => [accent1, accent2, accent3];
}

class TargetColors extends ColorScheme {
  /// Lightness from AOSP defaults
  static const Map<int, double> lightnessMap = {
    0: 1.000,
    10: 0.988,
    50: 0.955,
    100: 0.913,
    200: 0.827,
    300: 0.741,
    400: 0.653,
    500: 0.562,
    600: 0.482,
    700: 0.394,
    800: 0.309,
    900: 0.222,
    1000: 0.000,
  };

  /// Lightness map in CIELAB L*
  static const Map<int, double> lstarLightnessMap = {
    0: 100.0,
    10: 99.0,
    50: 95.0,
    100: 90.0,
    200: 80.0,
    300: 70.0,
    400: 60.0,
    500: 49.6,
    600: 40.0,
    700: 30.0,
    800: 20.0,
    900: 10.0,
    1000: 0.0,
  };

  // Neutral chroma from Google's CAM16 implementation
  static const double neutral1Chroma = 0.0132;
  static const double neutral2Chroma = neutral1Chroma / 2;

  // Accent chroma from Pixel defaults
  static const double accent1Chroma = 0.1212;
  static const double accent2Chroma = 0.04;
  static const double accent3Chroma = 0.06;

  final double chromaFactor;

  const TargetColors([this.chromaFactor = 1.0]);

  @override
  ColorSwatch get neutral1 => _shadesWithChroma(neutral1Chroma);
  @override
  ColorSwatch get neutral2 => _shadesWithChroma(neutral2Chroma);
  @override
  ColorSwatch get accent1 => _shadesWithChroma(accent1Chroma);
  @override
  ColorSwatch get accent2 => _shadesWithChroma(accent2Chroma);
  @override
  ColorSwatch get accent3 => _shadesWithChroma(accent3Chroma);

  ColorSwatch _shadesWithChroma(double chroma) {
    final double chromaAdj = chroma * chromaFactor;

    return lightnessMap.map(
          (key, value) => MapEntry(key, Oklch(value, chromaAdj)),
    );
  }
}

class DynamicColorScheme extends ColorScheme {
  // Hue shift for the tertiary accent color (accent3), in degrees.
  // 60 degrees = shifting by a secondary color
  static const double accent3HueShiftDegrees = 60.0;

  // Threshold for matching CIELAB L* targets. Colors with lightness delta
  // under this value are considered to match the reference lightness.
  static const double targetLstarThreshold = 0.01;

  // Threshold for terminating the binary search if min and max are too close.
  // The search is very unlikely to make progress after this point, so we
  // just terminate it and return the best L* value found.
  static const double targetLEpsilon = 0.001;

  final ColorScheme targetColors;
  final Color primaryColor;
  final double chromaMultiplier;
  final bool accurateShades;

  const DynamicColorScheme({
    required this.targetColors,
    required this.primaryColor,
    this.chromaMultiplier = 1.0,
    this.accurateShades = true,
  });

  Oklch get primaryNeutral {
    final Oklch lch = primaryColor.toLinearSrgb().toOklab().toOklch();
    return Oklch(lch.l, lch.c * chromaMultiplier, lch.h);
  }

  Oklch get primaryAccent => primaryNeutral;

  // Main background color. Tinted with the primary color.
  @override
  ColorSwatch get neutral1 =>
      _transformSwatch(targetColors.neutral1, primaryNeutral, (_) => _);

  // Secondary background color. Slightly tinted with the primary color.
  @override
  ColorSwatch get neutral2 =>
      _transformSwatch(targetColors.neutral2, primaryNeutral, (_) => _);

  // Main accent color. Generally, this is close to the primary color.
  @override
  ColorSwatch get accent1 =>
      _transformSwatch(targetColors.accent1, primaryAccent, (_) => _);

  // Secondary accent color. Darker shades of accent1.
  @override
  ColorSwatch get accent2 =>
      _transformSwatch(targetColors.accent2, primaryAccent, (_) => _);

  // Tertiary accent color. Primary color shifted to the next secondary color via hue offset.
  @override
  ColorSwatch get accent3 => _transformSwatch(
    targetColors.accent3,
    primaryAccent,
        (lch) => Oklch(lch.l, lch.c, lch.h + accent3HueShiftDegrees),
  );

  ColorSwatch _transformSwatch(
      ColorSwatch swatch,
      Lch primary,
      Oklch Function(Oklch) colorFilter,
      ) {
    return swatch.map((shade, color) {
      final Lch target;

      if (color is Lch) {
        target = color as Lch;
      } else {
        target = color.toLinearSrgb().toOklab().toOklch();
      }
      final double targetLstar = TargetColors.lstarLightnessMap[shade]!;
      final Oklch newLch =
      colorFilter(_transformColor(target, primary, targetLstar));
      final Srgb newSrgb = newLch.toOklab().toLinearSrgb().toSrgb();

      return MapEntry(shade, newSrgb);
    });
  }

  Oklch _transformColor(Lch target, Lch primary, double targetLstar) {
    // Allow colorless gray.
    final double c = primary.c.clamp(0.0, target.c);
    // Use the primary color's hue, since it's the most prominent feature of the theme.
    final double h = primary.h;
    // Binary search for the target lightness for accuracy
    final double l =
    accurateShades ? _searchLstar(targetLstar, c, h) : target.l;

    return Oklch(l, c, h);
  }

  double _searchLstar(double targetLstar, double c, double h) {
    // Some colors result in imperfect blacks (e.g. #000002) if we don't account for
    // negative lightness.
    double min = -0.5;
    // Colors can also be overexposed to better match CIELAB targets.
    double max = 1.5;

    // Keep track of the best L value found.
    // This will be returned if the search fails to converge.
    double bestL = double.nan;
    double bestLDelta = double.infinity;

    while (true) {
      final double mid = (min + max) / 2;
      // The search must be done in 8-bpc sRGB to account for the effects of clipping.
      // Otherwise, results at lightness extremes (especially ~shade 10) are quite far
      // off after quantization and clipping.
      final int srgbClipped =
      Oklch(mid, c, h).toOklab().toLinearSrgb().toSrgb().quantize8();

      // Convert back to Color and compare CIELAB L*
      final double lstar = Srgb.fromColor(ui.Color(srgbClipped))
          .toLinearSrgb()
          .toCieXyz()
          .toCieLab()
          .l;
      final double delta = (lstar - targetLstar).abs();

      if (delta < bestLDelta) {
        bestL = mid;
        bestLDelta = delta;
      }

      if (delta <= targetLstarThreshold) return mid;
      if ((min - max).abs() <= targetLEpsilon) return bestL;

      if (lstar < targetLstar) {
        min = mid;
      } else if (lstar > targetLstar) {
        max = mid;
      }
    }
  }
}

extension SchemeToColors on ColorScheme {
  MonetColors get asColors => MonetColors(
    accent1: accent1.asPalette,
    accent2: accent2.asPalette,
    accent3: accent3.asPalette,
    neutral1: neutral1.asPalette,
    neutral2: neutral2.asPalette,
  );
}

extension MapToPalette on ColorSwatch {
  MonetPalette get asPalette {
    final Map<int, ui.Color> newSwatch = map(
          (key, value) => MapEntry(
        key,
        ui.Color(value.toLinearSrgb().toSrgb().quantize8()),
      ),
    );

    return MonetPalette(newSwatch);
  }
}

/// Represents a collection of [MonetPalette]s that are generated using the bundled in monet engine
///
/// Each [MonetPalette] contains a set of 13 shades of a base color.
/// The base color used for each palette depend on the engine itself.
class MonetColors {
  /// Main accent color. Generally, this is close to the primary color.
  final MonetPalette accent1;

  /// Secondary accent color. Darker shades of [accent1].
  final MonetPalette accent2;

  /// Tertiary accent color. Primary color shifted to the next secondary color via hue offset.
  final MonetPalette accent3;

  /// Main background color. Tinted with the primary color.
  final MonetPalette neutral1;

  /// Secondary background color. Slightly tinted with the primary color.
  final MonetPalette neutral2;

  /// Creates a new instance of [MonetColors].
  ///
  /// Usually there should be no need to call this manually as you can get
  /// an already instanced object by creating a new [MonetProvider] with [MonetProvider.newInstance()]
  /// and then calling [MonetProvider.colors].
  const MonetColors({
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.neutral1,
    required this.neutral2,
  });
}

/// A set of 13 shades of a base color that was derived from the monet engine color calculations.
class MonetPalette extends material.ColorSwatch<int> {
  /// The raw map contains a set of key/values with all the shades
  final Map<int, material.Color> colors;

  /// Creates a new [MonetPalette]. It's not recommended to use this constructor directly
  /// as working and ready instances are already provided by [MonetColors].
  MonetPalette(this.colors)
      : assert(colors.length == 13),
        super(colors[500]!.value, colors);

  /// Lightest shade of the palette, equals to white.
  material.Color get shade0 => this[0]!;

  /// Base color at 99% lightness.
  material.Color get shade10 => this[10]!;

  /// Base color at 95% lightness.
  material.Color get shade50 => this[50]!;

  /// Base color at 90% lightness.
  material.Color get shade100 => this[100]!;

  /// Base color at 80% lightness.
  material.Color get shade200 => this[200]!;

  /// Base color at 70% lightness.
  material.Color get shade300 => this[300]!;

  /// Base color at 60% lightness.
  material.Color get shade400 => this[400]!;

  /// Base color at 50% lightness.
  material.Color get shade500 => this[500]!;

  /// Base color at 40% lightness.
  material.Color get shade600 => this[600]!;

  /// Base color at 30% lightness.
  material.Color get shade700 => this[700]!;

  /// Base color at 20% lightness.
  material.Color get shade800 => this[800]!;

  /// Base color at 10% lightness.
  material.Color get shade900 => this[900]!;

  /// Darkest shade of the palette, equals: black.
  material.Color get shade1000 => this[1000]!;

  /// Create a [MaterialColor] out of this palette.
  ///
  /// Note: [shade0], [shade10] and [shade1000] get discarded as they are
  /// not supported in a [MaterialColor].
  material.MaterialColor get asMaterialColor {
    return material.MaterialColor(shade500.value, colors);
  }
}