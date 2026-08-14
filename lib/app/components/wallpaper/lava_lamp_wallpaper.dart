import 'dart:math';

import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metaballs/metaballs.dart';

/// Dynamic wallpaper backed by the `metaballs` package — slowly drifting
/// blobs that merge and separate as they pass each other, colored from the
/// chat's theme palette.
///
/// Deliberately never sets a [MetaballsEffect]: all four of them (`follow`,
/// `grow`, `speedup`, `ripple`) are driven by cursor/touch position, and
/// passing any one of them makes `Metaballs` wrap itself in a `MouseRegion` +
/// `Listener`. A wallpaper sits behind the message list and must never
/// register interest in the user's taps and drags.
class LavaLampWallpaperDefinition extends DynamicWallpaperDefinition {
  LavaLampWallpaperDefinition()
      : super(id: 'lava_lamp', displayName: 'Lava Lamp', icon: Icons.water_drop_rounded);

  /// The package asserts `metaballs > 0 && metaballs <= 128`; the exposed
  /// range stops well short of that because the shader takes one uniform per
  /// blob and the effect turns into undifferentiated soup long before 128.
  static int _blobCount(Map<String, dynamic> c) => ((c['blobCount'] as num?)?.toInt() ?? 20).clamp(3, 60).toInt();

  static double _speed(Map<String, dynamic> c) => ((c['speed'] as num?)?.toDouble() ?? 0.4).clamp(0.1, 1.0);
  static double _minRadius(Map<String, dynamic> c) => ((c['minRadius'] as num?)?.toDouble() ?? 20).clamp(2.0, 80.0);
  static double _glowRadius(Map<String, dynamic> c) => ((c['glowRadius'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0);
  static double _glowIntensity(Map<String, dynamic> c) =>
      ((c['glowIntensity'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0);
  static double _bounciness(Map<String, dynamic> c) => ((c['bounciness'] as num?)?.toDouble() ?? 3).clamp(0.5, 10.0);

  /// `Metaballs` asserts `maxBallRadius >= minBallRadius`, and the two sliders
  /// can be dragged past each other — so the max is always floored at the min
  /// rather than trusted straight out of the config map.
  static double _maxRadius(Map<String, dynamic> c) {
    final raw = ((c['maxRadius'] as num?)?.toDouble() ?? 45).clamp(2.0, 140.0);
    return max(raw, _minRadius(c));
  }

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.deepOrange, Colors.pinkAccent];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(2).toList();
    return {
      'blobCount': 20.0,
      // Fairly slow by default -- a wallpaper should read as calm background
      // motion, not something competing for attention with the conversation.
      'speed': 0.4,
      'minRadius': 20.0,
      'maxRadius': 45.0,
      'glowRadius': 0.7,
      'glowIntensity': 0.6,
      'bounciness': 3.0,
      'colors':
          (colors.isEmpty ? [Colors.deepOrange, Colors.pinkAccent] : colors).map((c) => c.toARGB32()).toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _LavaLampWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final selected = _colors(config, palette).take(4).toList();

    return [
      ConfigSliderField(
        label: "Blobs",
        value: _blobCount(config).toDouble(),
        min: 3,
        max: 60,
        divisions: 57,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'blobCount': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: 0.1,
        max: 1.0,
        divisions: 9,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speed': v}),
      ),
      ConfigSliderField(
        label: "Min size",
        value: _minRadius(config),
        min: 2,
        max: 80,
        divisions: 39,
        format: (v) => v.toStringAsFixed(0),
        // Push the max up with the min rather than letting the stored value
        // sit below it and get silently floored -- otherwise dragging min past
        // max, then back down, would appear to "stick" the max slider.
        onChanged: (v) => onConfigChanged({
          ...config,
          'minRadius': v,
          if (_maxRadius(config) < v) 'maxRadius': v,
        }),
      ),
      ConfigSliderField(
        label: "Max size",
        value: _maxRadius(config),
        min: 2,
        max: 140,
        divisions: 46,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({
          ...config,
          'maxRadius': v,
          if (_minRadius(config) > v) 'minRadius': v,
        }),
      ),
      ConfigSliderField(
        label: "Glow size",
        value: _glowRadius(config),
        min: 0,
        max: 1,
        divisions: 20,
        format: (v) => "${(v * 100).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'glowRadius': v}),
      ),
      ConfigSliderField(
        label: "Glow intensity",
        value: _glowIntensity(config),
        min: 0,
        max: 1,
        divisions: 20,
        format: (v) => "${(v * 100).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'glowIntensity': v}),
      ),
      ConfigSliderField(
        label: "Bounciness",
        value: _bounciness(config),
        min: 0.5,
        max: 10,
        divisions: 19,
        format: (v) => v.toStringAsFixed(1),
        onChanged: (v) => onConfigChanged({...config, 'bounciness': v}),
      ),
      ConfigColorField(
        label: "Colors",
        palette: palette,
        selected: selected,
        maxSelected: 4,
        onChanged: (colors) => onConfigChanged({...config, 'colors': colors.map((c) => c.toARGB32()).toList()}),
      ),
    ];
  }
}

class _LavaLampWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _LavaLampWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = LavaLampWallpaperDefinition._colors(config, palette);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
            final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 300.0;
            // The package's shader samples raw `gl_FragCoord`, which Flutter
            // reports in *physical* pixels, but it positions the balls (and
            // scales their radii) off `LayoutBuilder` constraints, which are
            // *logical* pixels. On any display with a pixel ratio above 1
            // that mismatch squeezes the entire simulation into the top-left
            // 1/ratio of the widget -- a quarter at 2x, a ninth at 3x. The
            // package should be using `FlutterFragCoord()` from
            // `flutter/runtime_effect.glsl`, which normalizes exactly this.
            //
            // Compensate by laying `Metaballs` out at physical-pixel
            // dimensions and scaling the result back down, so one of its
            // logical units maps to one physical pixel and the two coordinate
            // spaces line up. At a pixel ratio of 1 this collapses to a no-op,
            // which is also precisely when the underlying bug doesn't bite.
            final ratio = MediaQuery.devicePixelRatioOf(context);

            return SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: width * ratio,
                  height: height * ratio,
                  child: Metaballs(
                    // `Metaballs` handles every one of these live: the ball
                    // count is reconciled in its `didUpdateWidget`, and the
                    // rest are read during build. Nothing here needs keying to
                    // pick up a config change.
                    metaballs: LavaLampWallpaperDefinition._blobCount(config),
                    speedMultiplier: LavaLampWallpaperDefinition._speed(config),
                    minBallRadius: LavaLampWallpaperDefinition._minRadius(config),
                    maxBallRadius: LavaLampWallpaperDefinition._maxRadius(config),
                    glowRadius: LavaLampWallpaperDefinition._glowRadius(config),
                    glowIntensity: LavaLampWallpaperDefinition._glowIntensity(config),
                    bounceStiffness: LavaLampWallpaperDefinition._bounciness(config),
                    color: colors.first,
                    // `gradient` overrides `color` in the renderer, and a
                    // single-stop LinearGradient isn't valid -- so only build
                    // one once there are actually two or more colors to blend
                    // between.
                    gradient: colors.length < 2
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
