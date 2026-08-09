import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wave/wave.dart';

/// Dynamic wallpaper backed by the `wave` package — a stack of animated,
/// layered wave shapes in colors drawn from the chat's theme palette.
class WaveWallpaperDefinition extends DynamicWallpaperDefinition {
  WaveWallpaperDefinition() : super(id: 'wave', displayName: 'Waves', icon: Icons.waves_rounded);

  static double _amplitude(Map<String, dynamic> c) => (c['amplitude'] as num?)?.toDouble() ?? 20;
  static double _frequency(Map<String, dynamic> c) => (c['frequency'] as num?)?.toDouble() ?? 1.6;
  static double _speed(Map<String, dynamic> c) => (c['speed'] as num?)?.toDouble() ?? 0.2;
  static double _opacity(Map<String, dynamic> c) => (c['opacity'] as num?)?.toDouble() ?? 0.5;
  static int _layerCount(Map<String, dynamic> c) => ((c['layerCount'] as num?)?.toInt() ?? 3).clamp(2, 4).toInt();

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.blue, Colors.lightBlue];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(3).toList();
    return {
      'amplitude': 20.0,
      'frequency': 1.6,
      // Fairly slow by default -- a wallpaper should read as calm background
      // motion, not something competing for attention with the conversation.
      'speed': 0.2,
      'opacity': 0.5,
      'layerCount': colors.length.clamp(2, 4).toDouble(),
      'colors': colors.map((c) => c.toARGB32()).toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _WaveWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final layerCount = _layerCount(config);
    final selected = _colors(config, palette).take(4).toList();

    return [
      ConfigSliderField(
        label: "Amplitude",
        value: _amplitude(config),
        min: 4,
        max: 48,
        divisions: 44,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'amplitude': v}),
      ),
      ConfigSliderField(
        label: "Frequency",
        value: _frequency(config),
        min: 0.4,
        max: 3.2,
        divisions: 28,
        format: (v) => v.toStringAsFixed(1),
        onChanged: (v) => onConfigChanged({...config, 'frequency': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: 0.1,
        max: 0.5,
        divisions: 4,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speed': v}),
      ),
      ConfigSliderField(
        label: "Opacity",
        value: _opacity(config),
        min: 0.2,
        max: 1.0,
        divisions: 16,
        format: (v) => "${(v * 100).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'opacity': v}),
      ),
      ConfigSliderField(
        label: "Wave layers",
        value: layerCount.toDouble(),
        min: 2,
        max: 4,
        divisions: 2,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'layerCount': v}),
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

class _WaveWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _WaveWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = WaveWallpaperDefinition._colors(config, palette);
    final layerCount = WaveWallpaperDefinition._layerCount(config);
    final speed = WaveWallpaperDefinition._speed(config);
    final opacity = WaveWallpaperDefinition._opacity(config);

    final layerColors =
        List.generate(layerCount, (i) => colors[i % colors.length].withValues(alpha: opacity));
    final durations = List.generate(layerCount, (i) => ((9000 - i * 1500) / speed).round());
    final heightPercentages = List.generate(layerCount, (i) => 0.16 + i * 0.07);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: WaveWidget(
        config: CustomConfig(
          colors: layerColors,
          durations: durations,
          heightPercentages: heightPercentages,
        ),
        waveAmplitude: WaveWallpaperDefinition._amplitude(config),
        waveFrequency: WaveWallpaperDefinition._frequency(config),
        backgroundColor: Colors.transparent,
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }
}
