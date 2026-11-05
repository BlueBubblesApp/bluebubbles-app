import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Visual constants shared by the media collection layouts (stack, collage, grid) and their cards.
///
/// Keep sizing, radii and shadows here so the three layouts can't drift apart.
abstract final class CollectionStyle {
  /// Collage / stack card width: this fraction of the screen width, capped at [maxCardWidth].
  static const double cardWidthFactor = 0.42;
  static const double maxCardWidth = 220.0;

  /// Grid width: this fraction of the screen width (roughly a text bubble's max width), capped at [maxGridWidth].
  static const double gridWidthFactor = 0.75;
  static const double maxGridWidth = 280.0;

  /// Card corner radius per skin.
  static double get cardRadius => switch (SettingsSvc.settings.skin.value) {
        Skins.Samsung => 25.0,
        Skins.iOS => 20.0,
        Skins.Material => M3EShapes.lg,
      };

  static BorderRadius get cardBorderRadius => BorderRadius.all(Radius.circular(cardRadius));

  /// Radius of an author-edge corner that joins an adjacent subject / body bubble (Material and Samsung only).
  ///
  /// Material matches the 5px connected corner `TailClipper` draws on text bubbles. Samsung is rounder so the
  /// joint doesn't look pinched against its larger 25px card radius.
  static double get connectedCornerRadius => SettingsSvc.settings.skin.value == Skins.Samsung ? 12.0 : 5.0;

  /// Soft card shadow, painted on the iOS skin only (null on Material / Samsung).
  static List<BoxShadow>? cardShadow(BuildContext context) {
    if (SettingsSvc.settings.skin.value != Skins.iOS) return null;
    return [
      BoxShadow(
        color: context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }
}
