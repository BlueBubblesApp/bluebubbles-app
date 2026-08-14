import 'package:bluebubbles/app/components/wallpaper/aurora_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/floating_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/lava_lamp_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/mesh_gradient_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/moving_background_wallpaper.dart';
import 'package:bluebubbles/app/components/wallpaper/particles_wallpaper.dart';
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

  /// Whether this wallpaper actually moves. Purely a *presentation* concern —
  /// the picker groups the gallery by it — and deliberately not part of how a
  /// wallpaper is stored: a still, generated-and-configured wallpaper uses the
  /// exact same `ChatWallpaperType.dynamic` + id + config-map plumbing as an
  /// animated one, and `dynamic` is a persisted enum name that isn't worth a
  /// migration to rename.
  bool get isAnimated => true;

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
    MovingBackgroundWallpaperDefinition(),
    ParticlesWallpaperDefinition(),
    AuroraWallpaperDefinition(),
    LavaLampWallpaperDefinition(),
    MeshGradientWallpaperDefinition(),
  ];

  static List<DynamicWallpaperDefinition> get all => List.unmodifiable(_definitions);

  /// The gallery renders these as two separate sections — a still wallpaper
  /// under an "Animated" header would just be misleading.
  static List<DynamicWallpaperDefinition> get animated =>
      List.unmodifiable(_definitions.where((d) => d.isAnimated));

  static List<DynamicWallpaperDefinition> get still =>
      List.unmodifiable(_definitions.where((d) => !d.isAnimated));

  static DynamicWallpaperDefinition? byId(String? id) {
    if (id == null) return null;
    for (final definition in _definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}
