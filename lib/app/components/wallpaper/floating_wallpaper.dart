import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:floating_animation/floating_animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dynamic wallpaper backed by the `floating_animation` package — a stream
/// of slowly floating shapes/icons in a color drawn from the chat's theme.
class FloatingWallpaperDefinition extends DynamicWallpaperDefinition {
  FloatingWallpaperDefinition() : super(id: 'floating', displayName: 'Floating Shapes', icon: Icons.bubble_chart_rounded);

  static const _shapes = <ConfigChoiceOption>[
    ConfigChoiceOption(value: 'circle', label: 'Circles', icon: Icons.circle),
    ConfigChoiceOption(value: 'rectangle', label: 'Squares', icon: Icons.square_rounded),
    ConfigChoiceOption(value: 'triangle', label: 'Triangles', icon: Icons.change_history_rounded),
    ConfigChoiceOption(value: 'heart', label: 'Hearts', icon: Icons.favorite_rounded),
  ];

  // FloatingDirection only supports up/down.
  static const _directions = <ConfigChoiceOption>[
    ConfigChoiceOption(value: 'up', label: 'Up', icon: Icons.arrow_upward_rounded),
    ConfigChoiceOption(value: 'down', label: 'Down', icon: Icons.arrow_downward_rounded),
  ];

  static String _shape(Map<String, dynamic> c) => (c['shape'] as String?) ?? 'circle';
  static int _maxShapes(Map<String, dynamic> c) => (c['maxShapes'] as num?)?.toInt() ?? 25;
  static double _speed(Map<String, dynamic> c) => (c['speedMultiplier'] as num?)?.toDouble() ?? 0.5;
  static double _size(Map<String, dynamic> c) => (c['sizeMultiplier'] as num?)?.toDouble() ?? 1.0;
  static double _spawnRate(Map<String, dynamic> c) => (c['spawnRate'] as num?)?.toDouble() ?? 5.0;
  static bool _rotation(Map<String, dynamic> c) => (c['enableRotation'] as bool?) ?? false;
  static bool _pulse(Map<String, dynamic> c) => (c['enablePulse'] as bool?) ?? false;

  static FloatingDirection _direction(Map<String, dynamic> c) {
    final raw = (c['direction'] as String?) ?? 'up';
    return FloatingDirection.values.firstWhere((e) => e.name == raw, orElse: () => FloatingDirection.up);
  }

  static Color _color(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw.first;
    return fallbackPalette.isNotEmpty ? fallbackPalette.first : Colors.blue;
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    return {
      'shape': 'circle',
      'maxShapes': 25.0,
      // Fairly slow by default -- a wallpaper should read as calm background
      // motion, not something competing for attention with the conversation.
      'speedMultiplier': 0.5,
      'sizeMultiplier': 1.0,
      'direction': 'up',
      'spawnRate': 5.0,
      'enableRotation': false,
      'enablePulse': true,
      'colors': [palette.isNotEmpty ? palette.first.toARGB32() : Colors.blue.toARGB32()],
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _FloatingWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final selectedColor = _color(config, palette);

    return [
      ConfigChoiceField(
        label: "Shape",
        value: _shape(config),
        options: _shapes,
        onChanged: (v) => onConfigChanged({...config, 'shape': v}),
      ),
      ConfigChoiceField(
        label: "Direction",
        value: (config['direction'] as String?) ?? 'up',
        options: _directions,
        onChanged: (v) => onConfigChanged({...config, 'direction': v}),
      ),
      ConfigSliderField(
        label: "Count",
        value: _maxShapes(config).toDouble(),
        min: 5,
        max: 50,
        divisions: 45,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'maxShapes': v}),
      ),
      ConfigSliderField(
        label: "Spawn rate",
        value: _spawnRate(config),
        min: 1,
        max: 20,
        divisions: 19,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'spawnRate': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: 0.1,
        max: 1.0,
        divisions: 9,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speedMultiplier': v}),
      ),
      ConfigSliderField(
        label: "Size",
        value: _size(config),
        min: 0.4,
        max: 3.0,
        divisions: 26,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'sizeMultiplier': v}),
      ),
      ConfigToggleField(
        label: "Rotate while floating",
        value: _rotation(config),
        onChanged: (v) => onConfigChanged({...config, 'enableRotation': v}),
      ),
      ConfigToggleField(
        label: "Pulse opacity",
        value: _pulse(config),
        onChanged: (v) => onConfigChanged({...config, 'enablePulse': v}),
      ),
      ConfigColorField(
        label: "Color",
        palette: palette,
        selected: [selectedColor],
        maxSelected: 1,
        onChanged: (colors) => onConfigChanged({...config, 'colors': colors.map((c) => c.toARGB32()).toList()}),
      ),
    ];
  }
}

class _FloatingWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _FloatingWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final shape = FloatingWallpaperDefinition._shape(config);
    final color = FloatingWallpaperDefinition._color(config, palette);
    final speed = FloatingWallpaperDefinition._speed(config);
    final size = FloatingWallpaperDefinition._size(config);
    final rotation = FloatingWallpaperDefinition._rotation(config);
    final pulse = FloatingWallpaperDefinition._pulse(config);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: FloatingAnimation(
        // `FloatingAnimation` only reads speed/size/rotation/pulse once, in
        // its own `initState()` -- it never re-reads them on rebuild, so
        // those sliders would otherwise silently do nothing after the first
        // frame. Keying on them forces a fresh instance (and a fresh
        // `initState()`) whenever one changes.
        key: ValueKey('$speed-$size-$rotation-$pulse'),
        maxShapes: FloatingWallpaperDefinition._maxShapes(config),
        speedMultiplier: speed,
        sizeMultiplier: size,
        selectedShape: shape,
        shapeColors: {shape: color},
        direction: FloatingWallpaperDefinition._direction(config),
        spawnRate: FloatingWallpaperDefinition._spawnRate(config),
        enableRotation: rotation,
        enablePulse: pulse,
      ),
    );
  }
}
