import 'package:flutter/material.dart';

class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }
}

extension ColorHelpers on Color {
  Color darkenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(this.alpha, (this.red * f).round(), (this.green * f).round(), (this.blue * f).round());
  }

  Color lightenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(this.alpha, this.red + ((255 - this.red) * p).round(),
        this.green + ((255 - this.green) * p).round(), this.blue + ((255 - this.blue) * p).round());
  }

  Color lightenOrDarken([double percent = 10]) {
    if (this.computeLuminance() >= 0.5) {
      return this.darkenPercent(percent);
    } else {
      return this.lightenPercent(percent);
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
}
