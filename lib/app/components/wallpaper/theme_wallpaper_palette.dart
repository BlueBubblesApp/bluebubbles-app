import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Derives a small set of candidate colors for dynamic wallpaper config
/// screens from the chat's currently active theme, so a wave/floating
/// wallpaper always looks like it belongs to the conversation it's set on
/// rather than needing a totally separate color picker.
abstract final class ThemeWallpaperPalette {
  static List<Color> fromContext(BuildContext context, {required bool isIMessage}) {
    final scheme = context.theme.colorScheme;
    final colors = <Color>[
      scheme.bubble(context, isIMessage),
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.onBubble(context, isIMessage),
    ];

    // De-dupe while preserving order (multiple roles frequently resolve to
    // the same color on smaller custom themes).
    final seen = <int>{};
    final deduped = <Color>[];
    for (final c in colors) {
      if (seen.add(c.toARGB32())) deduped.add(c);
    }
    return deduped;
  }
}
