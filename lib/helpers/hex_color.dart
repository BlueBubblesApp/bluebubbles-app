import 'dart:math';

import 'package:flutter/material.dart';

class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return int.parse(hexColor, radix: 16);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is HexColor && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

extension ColorSchemeHelpers on ColorScheme {
  Color get properSurface => surface.computeDifference(background) < 20 ? surfaceVariant : surface;

  Color get properOnSurface => surface.computeDifference(background) < 20 ? onSurfaceVariant : onSurface;
}

extension ColorHelpers on Color {
  Color darkenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(
        alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }

  Color lightenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(alpha, red + ((255 - red) * p).round(),
        green + ((255 - green) * p).round(), blue + ((255 - blue) * p).round());
  }

  Color lightenOrDarken([double percent = 10]) {
    if (computeLuminance() >= 0.5) {
      return darkenPercent(percent);
    } else {
      return lightenPercent(percent);
    }
  }
  
  Color oppositeLightenOrDarken([double percent = 10]) {
    if (computeLuminance() >= 0.5) {
      return lightenPercent(percent);
    } else {
      return darkenPercent(percent);
      
    }
  }

  Color darkenAmount([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  Color lightenAmount([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }
  //TODO Complete saturation color helper
  Color withSaturation([double amount = .1]) =>
      HSLColor.fromColor(this).withSaturation(amount).toColor();

  double computeDifference(Color? other) {
    if (other == null) return 100;
    final r1 = red;
    final g1 = green;
    final b1 = blue;
    final r2 = other.red;
    final g2 = other.green;
    final b2 = other.blue;
    final d = sqrt((r2-r1)^2+(g2-g1)^2+(b2-b1)^2);
    return d / sqrt((255)^2+(255)^2+(255)^2) * 100;
  }
}

MaterialColor createMaterialColor(Color color) {
  List<double> strengths = <double>[.05];
  Map<int, Color> swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (double strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}
