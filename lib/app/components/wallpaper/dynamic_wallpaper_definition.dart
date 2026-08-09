import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/floating_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/wave_wallpaper.dart';
import 'package:flutter/material.dart';

/// One entry in the dynamic wallpaper catalog. Implementations own their own
/// config schema (as a plain JSON-able `Map<String, dynamic>`) and know how
/// to render both the live wallpaper and their own config screen controls.
///
/// To add a new dynamic wallpaper: implement this class and add an instance
/// to [DynamicWallpaperRegistry._definitions] — the picker gallery, live
/// previews, config screen, and persistence all pick it up automatically.
abstract class DynamicWallpaperDefinition {
  /// Stable identifier persisted as `Chat.dynamicWallpaperId`. Never rename
  /// once shipped — existing chats reference it directly.
  final String id;
  final String displayName;
  final IconData icon;

  const DynamicWallpaperDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
  });

  /// A sensible starting config, seeded from the chat's active theme (so the
  /// first preview a user sees already matches their bubble color).
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage});

  /// Renders the wallpaper itself. Used both as the actual chat background
  /// and (at a smaller scale, `IgnorePointer`-wrapped by the caller) as the
  /// live preview on the gallery tile and config screen.
  Widget buildView(BuildContext context, Map<String, dynamic> config);

  /// The editable controls for [config], described generically so a single
  /// skin-aware config screen shell can render any dynamic wallpaper type.
  /// Each field's `onChanged` callback should call [onConfigChanged] with a
  /// new map (`{...config, 'key': value}`) rather than mutating in place.
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  );
}

abstract final class DynamicWallpaperRegistry {
  static final List<DynamicWallpaperDefinition> _definitions = [
    WaveWallpaperDefinition(),
    FloatingWallpaperDefinition(),
  ];

  static List<DynamicWallpaperDefinition> get all => List.unmodifiable(_definitions);

  static DynamicWallpaperDefinition? byId(String? id) {
    if (id == null) return null;
    for (final definition in _definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}
