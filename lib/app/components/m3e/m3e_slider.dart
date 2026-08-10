import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Material 3 Expressive slider theming — a thicker track, an oversized round
/// thumb, and dotted stop indicators for discrete steps, built from the app's
/// active [ColorScheme]. Used by [BBSlider] (`lib/app/components/bb_slider.dart`)
/// under the Material and Samsung skins.
abstract final class M3ESlider {
  static const double trackHeight = 16;
  static const double thumbRadius = 14;
  static const double overlayRadius = 24;
  static const double tickMarkRadius = 1.5;

  static SliderThemeData themeData(
    BuildContext context, {
    Color? activeColor,
    Color? inactiveColor,
    Color? thumbColor,
  }) {
    final colorScheme = context.theme.colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ?? colorScheme.secondaryContainer;
    final thumb = thumbColor ?? active;

    return SliderThemeData(
      trackHeight: trackHeight,
      activeTrackColor: active,
      inactiveTrackColor: inactive,
      secondaryActiveTrackColor: active.withValues(alpha: 0.6),
      disabledActiveTrackColor: active.withValues(alpha: 0.38),
      disabledInactiveTrackColor: inactive.withValues(alpha: 0.38),
      thumbColor: thumb,
      disabledThumbColor: thumb.withValues(alpha: 0.38),
      overlayColor: active.withValues(alpha: 0.12),
      activeTickMarkColor: colorScheme.onPrimary.withValues(alpha: 0.6),
      inactiveTickMarkColor: colorScheme.onSecondaryContainer.withValues(alpha: 0.6),
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: thumbRadius, disabledThumbRadius: thumbRadius),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: overlayRadius),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: tickMarkRadius),
    );
  }
}
