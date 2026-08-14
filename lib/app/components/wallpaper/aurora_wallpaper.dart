import 'dart:math';

import 'package:aurora_background/aurora_background.dart';
import 'package:aurora_background/star_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dynamic wallpaper backed by the `aurora_background` package — layered,
/// slowly drifting aurora ribbons over a starfield, in colors drawn from the
/// chat's theme palette.
///
/// The package hardcodes each ribbon's alpha internally (`withOpacity(0.1/0.5
/// /0.1)` in its painter), so there's deliberately no opacity knob here — the
/// selected palette colors and the blur are what shape how strongly it reads.
class AuroraWallpaperDefinition extends DynamicWallpaperDefinition {
  AuroraWallpaperDefinition() : super(id: 'aurora', displayName: 'Aurora', icon: Icons.nights_stay_rounded);

  static int _waveCount(Map<String, dynamic> c) => ((c['waveCount'] as num?)?.toInt() ?? 3).clamp(1, 5).toInt();
  static double _speed(Map<String, dynamic> c) => (c['speed'] as num?)?.toDouble() ?? 0.5;
  static double _waveHeight(Map<String, dynamic> c) => (c['waveHeight'] as num?)?.toDouble() ?? 0.15;
  static double _basePosition(Map<String, dynamic> c) => (c['basePosition'] as num?)?.toDouble() ?? 0.4;
  static double _blur(Map<String, dynamic> c) => (c['blur'] as num?)?.toDouble() ?? 40;
  static bool _showStars(Map<String, dynamic> c) => (c['showStars'] as bool?) ?? true;
  static int _starCount(Map<String, dynamic> c) => ((c['starCount'] as num?)?.toInt() ?? 100).clamp(0, 400).toInt();
  static double _starSize(Map<String, dynamic> c) => (c['starSize'] as num?)?.toDouble() ?? 1.5;

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.lightBlueAccent, Colors.greenAccent];
  }

  /// One `[edge, center, edge]` triple per ribbon — the package's painter maps
  /// these onto a top-left→bottom-right gradient with the center color as the
  /// dominant one. Pulling the edges from the *next* palette color makes a
  /// multi-color selection blend between ribbons; with a single color selected
  /// it collapses to a flat, uniform ribbon.
  static List<List<Color>> _waveColors(List<Color> colors, int waveCount) {
    return List.generate(waveCount, (i) {
      final center = colors[i % colors.length];
      final edge = colors[(i + 1) % colors.length];
      return [edge, center, edge];
    });
  }

  /// Per-ribbon animation periods in seconds. Successive ribbons drift more
  /// slowly than the one before it, which is what gives the stack its parallax.
  static List<int> _waveDurations(int waveCount, double speed) {
    return List.generate(waveCount, (i) => max(1, ((8 + i * 8) / speed).round()));
  }

  /// The vertical backdrop the ribbons sit on. Kept anchored to the theme's
  /// surface color (so a light theme doesn't get an out-of-nowhere black sky)
  /// and tinted toward the aurora colors as it descends into the ribbons.
  static List<Color> _backgroundColors(BuildContext context, List<Color> colors) {
    final surface = context.theme.colorScheme.surface;
    return [
      surface,
      Color.lerp(surface, colors.first, 0.18)!,
      Color.lerp(surface, colors.last, 0.30)!,
    ];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(3).toList();
    return {
      'waveCount': 3.0,
      // Fairly slow by default -- a wallpaper should read as calm background
      // motion, not something competing for attention with the conversation.
      'speed': 0.5,
      'waveHeight': 0.15,
      'basePosition': 0.4,
      'blur': 40.0,
      'showStars': true,
      'starCount': 100.0,
      'starSize': 1.5,
      'colors': (colors.isEmpty ? [Colors.lightBlueAccent, Colors.greenAccent] : colors)
          .map((c) => c.toARGB32())
          .toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _AuroraWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final selected = _colors(config, palette).take(5).toList();

    return [
      ConfigSliderField(
        label: "Ribbons",
        value: _waveCount(config).toDouble(),
        min: 1,
        max: 5,
        divisions: 4,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'waveCount': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: 0.2,
        max: 2.0,
        divisions: 18,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speed': v}),
      ),
      ConfigSliderField(
        label: "Ribbon height",
        value: _waveHeight(config),
        min: 0.05,
        max: 0.4,
        divisions: 35,
        format: (v) => "${(v * 100).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'waveHeight': v}),
      ),
      ConfigSliderField(
        label: "Ribbon position",
        value: _basePosition(config),
        min: 0.1,
        max: 0.7,
        divisions: 12,
        format: (v) => "${(v * 100).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'basePosition': v}),
      ),
      ConfigSliderField(
        label: "Blur",
        value: _blur(config),
        min: 0,
        max: 100,
        divisions: 20,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'blur': v}),
      ),
      ConfigToggleField(
        label: "Stars",
        value: _showStars(config),
        onChanged: (v) => onConfigChanged({...config, 'showStars': v}),
      ),
      if (_showStars(config)) ...[
        ConfigSliderField(
          label: "Star count",
          value: _starCount(config).toDouble(),
          min: 10,
          max: 400,
          divisions: 39,
          format: (v) => v.toStringAsFixed(0),
          onChanged: (v) => onConfigChanged({...config, 'starCount': v}),
        ),
        ConfigSliderField(
          label: "Star size",
          value: _starSize(config),
          min: 0.5,
          max: 4.0,
          divisions: 14,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => onConfigChanged({...config, 'starSize': v}),
        ),
      ],
      ConfigColorField(
        label: "Colors",
        palette: palette,
        selected: selected,
        maxSelected: 5,
        onChanged: (colors) => onConfigChanged({...config, 'colors': colors.map((c) => c.toARGB32()).toList()}),
      ),
    ];
  }
}

class _AuroraWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _AuroraWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = AuroraWallpaperDefinition._colors(config, palette);
    final waveCount = AuroraWallpaperDefinition._waveCount(config);
    final speed = AuroraWallpaperDefinition._speed(config);
    final durations = AuroraWallpaperDefinition._waveDurations(waveCount, speed);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: ClipRect(
        // `AuroraBackground` builds its animation controllers once, in
        // `initState()`, straight off `numberOfWaves`/`waveDurations` -- it
        // has no `didUpdateWidget`. Raising the ribbon count on a live widget
        // would index past the controllers it already made (a range error),
        // and a speed change would simply be ignored. Keying on exactly those
        // two inputs forces a fresh instance when they change, while colors,
        // blur, heights and the starfield (all read during build) keep
        // updating in place without restarting the animation.
        child: KeyedSubtree(
          key: ValueKey('$waveCount-${durations.join(',')}'),
          child: AuroraBackground(
            numberOfWaves: waveCount,
            waveDurations: durations,
            waveColors: AuroraWallpaperDefinition._waveColors(colors, waveCount),
            backgroundColors: AuroraWallpaperDefinition._backgroundColors(context, colors),
            waveHeightMultiplier: AuroraWallpaperDefinition._waveHeight(config),
            baseHeightMultiplier: AuroraWallpaperDefinition._basePosition(config),
            waveBlur: AuroraWallpaperDefinition._blur(config),
            starFieldConfig: StarFieldConfig(
              starCount: AuroraWallpaperDefinition._showStars(config)
                  ? AuroraWallpaperDefinition._starCount(config)
                  : 0,
              maxStarSize: AuroraWallpaperDefinition._starSize(config),
              starColor: context.theme.colorScheme.onSurface,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
