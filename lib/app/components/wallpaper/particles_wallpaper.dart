import 'dart:math';

import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:particles_flutter/engine.dart';
import 'package:particles_flutter/interactions.dart';
import 'package:particles_flutter/physics.dart';

/// Per-preset density/speed defaults and slider ranges -- see
/// [ParticlesWallpaperDefinition._presetTuning].
typedef _PresetTuning = ({
  double count,
  double countMin,
  double countMax,
  int countDivisions,
  double speed,
  double speedMin,
  double speedMax,
});

/// Dynamic wallpaper backed by the `particles_flutter` package. Only exposes
/// a curated set of presets built from the package's documented example
/// scenes — not the full particle-physics API — so the config screen stays
/// a handful of understandable knobs instead of the package's raw surface.
class ParticlesWallpaperDefinition extends DynamicWallpaperDefinition {
  ParticlesWallpaperDefinition() : super(id: 'particles', displayName: 'Particles', icon: Icons.grain_rounded);

  static const _presets = <ConfigChoiceOption>[
    ConfigChoiceOption(value: 'starfield', label: 'Starfield', icon: Icons.auto_awesome_rounded),
    ConfigChoiceOption(value: 'web', label: 'Web', icon: Icons.hub_outlined),
    ConfigChoiceOption(value: 'nebula', label: 'Nebula', icon: Icons.blur_on_rounded),
    ConfigChoiceOption(value: 'ghosts', label: 'Ghosts', icon: Icons.blur_circular_rounded),
    ConfigChoiceOption(value: 'pulse', label: 'Pulse', icon: Icons.radio_button_checked_rounded),
    ConfigChoiceOption(value: 'snow', label: 'Snow', icon: Icons.ac_unit_rounded),
  ];

  /// Density/speed starting points *and* slider ranges, per preset --
  /// applied whenever the preset selector changes so switching effects
  /// looks right away rather than inheriting an unrelated preset's tuning,
  /// and so e.g. "Web" (small, thin dots) can cap out at a much lower count
  /// than "Snow" (wants density) without either one having to share a
  /// single compromise range. Speed defaults to a fairly slow 0.5x -- a
  /// wallpaper should read as calm background motion, not something
  /// competing for attention with the conversation.
  static const _presetTuning = <String, _PresetTuning>{
    'starfield':
        (count: 120, countMin: 10, countMax: 200, countDivisions: 38, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
    'web': (count: 25, countMin: 10, countMax: 50, countDivisions: 40, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
    'nebula': (count: 10, countMin: 5, countMax: 30, countDivisions: 25, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
    'ghosts': (count: 45, countMin: 10, countMax: 90, countDivisions: 40, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
    'pulse': (count: 55, countMin: 10, countMax: 110, countDivisions: 40, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
    'snow': (count: 100, countMin: 10, countMax: 200, countDivisions: 38, speed: 0.5, speedMin: 0.2, speedMax: 2.0),
  };

  static String _preset(Map<String, dynamic> c) => (c['preset'] as String?) ?? 'starfield';
  static _PresetTuning _tuningFor(String preset) => _presetTuning[preset] ?? _presetTuning['starfield']!;

  static int _count(Map<String, dynamic> c) {
    final tuning = _tuningFor(_preset(c));
    return ((c['count'] as num?)?.toInt() ?? tuning.count.toInt())
        .clamp(tuning.countMin.toInt(), tuning.countMax.toInt());
  }

  static double _speed(Map<String, dynamic> c) {
    final tuning = _tuningFor(_preset(c));
    return ((c['speed'] as num?)?.toDouble() ?? tuning.speed).clamp(tuning.speedMin, tuning.speedMax);
  }

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.white];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(2).toList();
    final tuning = _tuningFor('starfield');
    return {
      'preset': 'starfield',
      'count': tuning.count,
      'speed': tuning.speed,
      'colors': (colors.isEmpty ? [Colors.white] : colors).map((c) => c.toARGB32()).toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _ParticlesWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final selected = _colors(config, palette).take(3).toList();
    final tuning = _tuningFor(_preset(config));

    return [
      ConfigChoiceField(
        label: "Effect",
        value: _preset(config),
        options: _presets,
        onChanged: (preset) {
          final next = _tuningFor(preset);
          onConfigChanged({...config, 'preset': preset, 'count': next.count, 'speed': next.speed});
        },
      ),
      ConfigSliderField(
        label: "Density",
        value: _count(config).toDouble(),
        min: tuning.countMin,
        max: tuning.countMax,
        divisions: tuning.countDivisions,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'count': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: tuning.speedMin,
        max: tuning.speedMax,
        divisions: 18,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speed': v}),
      ),
      ConfigColorField(
        label: "Colors",
        palette: palette,
        selected: selected,
        maxSelected: 3,
        onChanged: (colors) => onConfigChanged({...config, 'colors': colors.map((c) => c.toARGB32()).toList()}),
      ),
    ];
  }

  /// Builds the actual `Particles` widget for [preset]. Ported directly from
  /// the package's documented example scenes (starfield/snow/ghosts/pulse),
  /// plus `connectDots` for a constellation-style "web" and a hand-tuned
  /// soft-cloud "nebula" built from the same primitives (not an official
  /// example — the package has no such preset).
  static Widget _build(String preset, int count, double speed, List<Color> colors, Size size) {
    final rng = Random();
    Color colorAt(int i) => colors[i % colors.length];

    switch (preset) {
      case 'snow':
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          particlePhysics: ParticlePhysics(gravityScale: 20 * speed),
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: rng.nextDouble() * 6 + 2,
              color: colorAt(i).withValues(alpha: 0.8),
              velocity: Offset((rng.nextDouble() - 0.5) * 20 * speed, (rng.nextDouble() * 15 + 5) * speed),
            ),
          ),
        );
      case 'ghosts':
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: rng.nextDouble() * 14 + 8,
              color: colorAt(i),
              velocity: Offset((rng.nextDouble() - 0.5) * 15 * speed, (rng.nextDouble() - 0.5) * 10 * speed),
              lifetime: rng.nextDouble() * 3.0 + 2.0,
              startOpacity: 0.0,
              endOpacity: 0.0,
              startScale: 0.6,
              endScale: 1.2,
              scaleCurve: Curves.easeOut,
            ),
          ),
        );
      case 'pulse':
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: 10,
              color: colorAt(i),
              velocity: Offset((rng.nextDouble() - 0.5) * 20 * speed, (rng.nextDouble() - 0.5) * 20 * speed),
              lifetime: 2.5,
              startScale: 0.1,
              endScale: 1.8,
              scaleCurve: Curves.easeInOut,
              startOpacity: 0.0,
              endOpacity: 0.0,
            ),
          ),
        );
      case 'web':
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          connectDots: true,
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: rng.nextDouble() * 2 + 1,
              color: colorAt(i),
              velocity: Offset((rng.nextDouble() - 0.5) * 30 * speed, (rng.nextDouble() - 0.5) * 30 * speed),
            ),
          ),
        );
      case 'nebula':
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: rng.nextDouble() * 40 + 20,
              color: colorAt(i).withValues(alpha: 0.12),
              velocity: Offset((rng.nextDouble() - 0.5) * 6 * speed, (rng.nextDouble() - 0.5) * 6 * speed),
            ),
          ),
        );
      case 'starfield':
      default:
        return Particles(
          width: size.width,
          height: size.height,
          boundType: BoundType.WrapAround,
          // A wallpaper sits behind the message list -- it must never react
          // to the user's taps/drags meant for the conversation above it.
          interaction: ParticleInteraction.none(),
          particles: List.generate(
            count,
            (i) => CircularParticle(
              radius: rng.nextDouble() * 3 + 0.5,
              color: colorAt(i).withValues(alpha: 0.7),
              velocity: Offset((rng.nextDouble() - 0.5) * 40 * speed, (rng.nextDouble() - 0.5) * 40 * speed),
            ),
          ),
        );
    }
  }
}

class _ParticlesWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _ParticlesWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = ParticlesWallpaperDefinition._colors(config, palette);
    final preset = ParticlesWallpaperDefinition._preset(config);
    final count = ParticlesWallpaperDefinition._count(config);
    final speed = ParticlesWallpaperDefinition._speed(config);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.maxWidth.isFinite ? constraints.maxWidth : 300,
              constraints.maxHeight.isFinite ? constraints.maxHeight : 300,
            );
            // `Particles` only reads its `particles` list once, in
            // `initState()` -- it never regenerates them on rebuild, so
            // switching presets (a completely different particle profile:
            // radius, physics, boundary behavior) would otherwise keep
            // animating the old preset's particles under the new preset's
            // live-updating physics, producing visibly broken motion.
            // Keying on every field that shapes the particle set forces a
            // fresh instance whenever any of them change.
            final colorKey = colors.map((c) => c.toARGB32()).join(',');
            return KeyedSubtree(
              key: ValueKey('$preset-$count-$speed-$colorKey'),
              child: ParticlesWallpaperDefinition._build(preset, count, speed, colors, size),
            );
          },
        ),
      ),
    );
  }
}
