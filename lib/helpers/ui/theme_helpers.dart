import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

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

@immutable
class BubbleColors extends ThemeExtension<BubbleColors> {
  const BubbleColors({
    this.iMessageBubbleColor,
    this.oniMessageBubbleColor,
    this.smsBubbleColor,
    this.onSmsBubbleColor,
    this.receivedBubbleColor,
    this.onReceivedBubbleColor,
  });

  final Color? iMessageBubbleColor;
  final Color? oniMessageBubbleColor;
  final Color? smsBubbleColor;
  final Color? onSmsBubbleColor;
  final Color? receivedBubbleColor;
  final Color? onReceivedBubbleColor;

  @override
  BubbleColors copyWith(
      {Color? iMessageBubbleColor,
      Color? oniMessageBubbleColor,
      Color? smsBubbleColor,
      Color? onSmsBubbleColor,
      Color? receivedBubbleColor,
      Color? onReceivedBubbleColor}) {
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

/// Mixin to provide settings widgets with easy access to the commonly used
/// theming values
mixin ThemeHelpers<T extends StatefulWidget> on State<T> {
  // Samsung theme should always use the background color as the "header" color
  bool get reverseMapping => ss.settings.skin.value == Skins.Material && ts.inDarkMode(context);

  /// iOS skin [ListTile] subtitle [TextStyle]s
  TextStyle get iosSubtitle => context.theme.textTheme.labelLarge!.copyWith(
      color: ts.inDarkMode(context)
          ? (ss.settings.windowEffect.value != WindowEffect.disabled
              ? context.theme.colorScheme.properOnSurface
              : context.theme.colorScheme.onBackground)
          : (ss.settings.windowEffect.value != WindowEffect.disabled
              ? context.theme.colorScheme.onBackground
              : context.theme.colorScheme.properOnSurface),
      fontWeight: FontWeight.w300);

  /// Material / Samsung skin [ListTile] subtitle [TextStyle]s
  TextStyle get materialSubtitle =>
      context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);

  Color get _headerColor => (ts.inDarkMode(context)
      ? context.theme.colorScheme.background
      : context.theme.colorScheme.properSurface).withAlpha(ss.settings.windowEffect.value != WindowEffect.disabled ? 20 : 255);

  Color get _tileColor => (ts.inDarkMode(context) ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background)
      .withAlpha(ss.settings.windowEffect.value != WindowEffect.disabled ? 100 : 255);

  /// Header / background color on settings pages
  Color get headerColor => reverseMapping ? _tileColor : _headerColor;

  /// Tile / foreground color on settings pages
  Color get tileColor => reverseMapping ? _headerColor : _tileColor;

  /// Whether or not to use tablet mode
  bool get showAltLayout =>
      ss.settings.tabletMode.value && (!context.isPhone || context.width / context.height > 0.8) && context.width > 600 && !ls.isBubble;

  bool get showAltLayoutContextless =>
      ss.settings.tabletMode.value &&
      (!Get.context!.isPhone || Get.context!.width / Get.context!.height > 0.8) &&
      Get.context!.width > 600 &&
      !ls.isBubble;

  bool get iOS => ss.settings.skin.value == Skins.iOS;

  bool get material => ss.settings.skin.value == Skins.Material;

  bool get samsung => ss.settings.skin.value == Skins.Samsung;

  Brightness get brightness => context.theme.colorScheme.brightness;
}

extension ColorSchemeHelpers on ColorScheme {
  Color get properSurface => surface.computeDifference(background) < 10 ? surfaceVariant : surface;

  Color get properOnSurface => surface.computeDifference(background) < 10 ? onSurfaceVariant : onSurface;

  Color get iMessageBubble =>
      HSLColor.fromColor(primary).colorfulness < HSLColor.fromColor(primaryContainer).colorfulness ? primary : primaryContainer;

  Color get oniMessageBubble => iMessageBubble == primary ? onPrimary : onPrimaryContainer;

  Color get smsBubble => HSLColor.fromColor(primary).colorfulness > HSLColor.fromColor(primaryContainer).colorfulness ? primary : primaryContainer;

  Color get onSmsBubble => iMessageBubble == primary ? onPrimaryContainer : onPrimary;

  Color bubble(BuildContext context, bool iMessage) => ss.settings.monetTheming.value != Monet.none
      ? (iMessage ? iMessageBubble : smsBubble)
      : iMessage
          ? (context.theme.extensions[BubbleColors] as BubbleColors?)?.iMessageBubbleColor ?? iMessageBubble
          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.smsBubbleColor ?? smsBubble;

  Color onBubble(BuildContext context, bool iMessage) => ss.settings.monetTheming.value != Monet.none
      ? (iMessage ? oniMessageBubble : onSmsBubble)
      : iMessage
          ? (context.theme.extensions[BubbleColors] as BubbleColors?)?.oniMessageBubbleColor ?? oniMessageBubble
          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onSmsBubbleColor ?? onSmsBubble;
}

extension ColorHelpers on Color {
  Color darkenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }

  Color lightenPercent([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var p = percent / 100;
    return Color.fromARGB(alpha, red + ((255 - red) * p).round(), green + ((255 - green) * p).round(), blue + ((255 - blue) * p).round());
  }

  Color lightenOrDarken([double percent = 10]) {
    if (percent == 0) return this;
    if (computeDifference(Colors.black) <= 50) {
      return darkenPercent(percent);
    } else {
      return lightenPercent(percent);
    }
  }

  Color oppositeLightenOrDarken([double percent = 10]) {
    if (percent == 0) return this;
    if (computeDifference(Colors.black) <= 50) {
      return lightenPercent(percent);
    } else {
      return darkenPercent(percent);
    }
  }

  Color themeLightenOrDarken(BuildContext context, [double percent = 10]) {
    if (percent == 0) return this;
    if (!ts.inDarkMode(context)) {
      return darkenPercent(percent);
    } else {
      return lightenPercent(percent);
    }
  }

  Color themeOpacity(BuildContext context) {
    if (ss.settings.windowEffect.value == WindowEffect.disabled) return withOpacity(1.0.obs.value);
    if (!WindowEffects.dependsOnColor()) return withOpacity(0.0.obs.value);
    if (!ts.inDarkMode(context)) {
      return withOpacity(ss.settings.windowEffectCustomOpacityLight.value);
    } else {
      return withOpacity(ss.settings.windowEffectCustomOpacityDark.value);
    }
  }

  Color darkenAmount([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    if (amount == 0) return this;

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

  double computeDifference(Color? other) {
    if (other == null) return 100;
    final r1 = red;
    final g1 = green;
    final b1 = blue;
    final r2 = other.red;
    final g2 = other.green;
    final b2 = other.blue;
    final d = sqrt(pow(r2 - r1, 2) + pow(g2 - g1, 2) + pow(b2 - b1, 2));
    return d / sqrt(pow(255, 2) + pow(255, 2) + pow(255, 2)) * 100;
  }
}

extension HSLHelpers on HSLColor {
  /// Get "colorfulness" of a color based on saturation and brightness. Lower
  /// is more "colorful".
  double get colorfulness {
    final sat = saturation - 1;
    final bright = lightness - 0.5;
    return sqrt(sat * sat + bright * bright);
  }
}

extension OppositeBrightness on Brightness {
  Brightness get opposite => this == Brightness.light ? Brightness.dark : Brightness.light;
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

List<Color> toColorGradient(String? str) {
  if (isNullOrEmpty(str)!) return [HexColor("686868"), HexColor("928E8E")];

  int total = 0;
  for (int i = 0; i < (str ?? "").length; i++) {
    total += str!.codeUnitAt(i);
  }

  Random random = Random(total);
  int seed = random.nextInt(7);

  // These are my arbitrary weights. It's based on what I found
  // to be a good amount of each color
  if (seed == 0) {
    return [HexColor("fd678d"), HexColor("ff8aa8")]; // Pink
  } else if (seed == 1) {
    return [HexColor("6bcff6"), HexColor("94ddfd")]; // Blue
  } else if (seed == 2) {
    return [HexColor("fea21c"), HexColor("feb854")]; // Orange
  } else if (seed == 3) {
    return [HexColor("5ede79"), HexColor("8de798")]; // Green
  } else if (seed == 4) {
    return [HexColor("ffca1c"), HexColor("fcd752")]; // Yellow
  } else if (seed == 5) {
    return [HexColor("ff534d"), HexColor("fd726a")]; // Red
  } else {
    return [HexColor("a78df3"), HexColor("bcabfc")]; // Purple
  }
}
