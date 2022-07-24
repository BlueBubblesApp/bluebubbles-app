
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mixin to provide settings widgets with easy access to the commonly used
/// theming values
mixin ThemeHelpers<T extends StatefulWidget> on State<T> {
  // Samsung theme should always use the background color as the "header" color
  bool get reverseMapping =>
      SettingsManager().settings.skin.value == Skins.Material
          && ThemeManager().inDarkMode(context);

  /// iOS skin [ListTile] subtitle [TextStyle]s
  TextStyle get iosSubtitle => context.theme.textTheme.labelLarge!.copyWith(
      color: ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.onBackground
        : context.theme.colorScheme.properOnSurface,
      fontWeight: FontWeight.w300
  );

  /// Material / Samsung skin [ListTile] subtitle [TextStyle]s
  TextStyle get materialSubtitle => context.theme.textTheme.labelLarge!.copyWith(
      color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold
  );

  Color get _headerColor => ThemeManager().inDarkMode(context)
      ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
  Color get _tileColor => ThemeManager().inDarkMode(context)
      ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;

  /// Header / background color on settings pages
  Color get headerColor => reverseMapping ? _tileColor : _headerColor;

  /// Tile / foreground color on settings pages
  Color get tileColor => reverseMapping ? _headerColor : _tileColor;

  /// Whether or not to use tablet mode
  bool get showAltLayout => SettingsManager().settings.tabletMode.value
      && (!context.isPhone || context.isLandscape)
      && context.width > 600;

  bool get iOS => SettingsManager().settings.skin.value == Skins.iOS;

  bool get material => SettingsManager().settings.skin.value == Skins.Material;

  bool get samsung => SettingsManager().settings.skin.value == Skins.Samsung;
}