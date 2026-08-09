import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_moving_background/flutter_moving_background.dart';
import 'package:get/get.dart';

/// Dynamic wallpaper backed by the `flutter_moving_background` package —
/// soft, blurred, slowly drifting circles in colors drawn from the chat's
/// theme palette.
class MovingBackgroundWallpaperDefinition extends DynamicWallpaperDefinition {
  MovingBackgroundWallpaperDefinition()
      : super(id: 'moving_background', displayName: 'Drifting Circles', icon: Icons.gradient_rounded);

  static const _animationTypes = <ConfigChoiceOption>[
    ConfigChoiceOption(value: 'moveAndFade', label: 'Move & fade', icon: Icons.blur_on_rounded),
    ConfigChoiceOption(value: 'move', label: 'Move', icon: Icons.open_with_rounded),
    ConfigChoiceOption(value: 'pulse', label: 'Pulse', icon: Icons.radio_button_checked_rounded),
    ConfigChoiceOption(value: 'scale', label: 'Scale', icon: Icons.zoom_out_map_rounded),
  ];

  static AnimationType _animationType(Map<String, dynamic> c) {
    final raw = (c['animationType'] as String?) ?? 'moveAndFade';
    return AnimationType.values.firstWhere((e) => e.name == raw, orElse: () => AnimationType.moveAndFade);
  }

  static double _speed(Map<String, dynamic> c) => (c['speed'] as num?)?.toDouble() ?? 0.5;
  static int _circleCount(Map<String, dynamic> c) => ((c['circleCount'] as num?)?.toInt() ?? 4).clamp(2, 6).toInt();
  static double _circleSize(Map<String, dynamic> c) => (c['circleSize'] as num?)?.toDouble() ?? 1.0;
  static double _blur(Map<String, dynamic> c) => (c['blur'] as num?)?.toDouble() ?? 2.0;

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.blue, Colors.purple];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(3).toList();
    return {
      'animationType': 'moveAndFade',
      // Fairly slow by default -- a wallpaper should read as calm background
      // motion, not something competing for attention with the conversation.
      'speed': 0.5,
      'circleCount': colors.isEmpty ? 3.0 : colors.length.clamp(2, 6).toDouble(),
      'circleSize': 1.0,
      // Almost no blur by default -- the circles read as soft shapes with a
      // gentle edge rather than a hazy, indistinct glow.
      'blur': 2.0,
      'colors': (colors.isEmpty ? [Colors.blue, Colors.purple] : colors).map((c) => c.toARGB32()).toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _MovingBackgroundWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final circleCount = _circleCount(config);
    final selected = _colors(config, palette).take(6).toList();

    return [
      ConfigChoiceField(
        label: "Animation",
        value: _animationType(config).name,
        options: _animationTypes,
        onChanged: (v) => onConfigChanged({...config, 'animationType': v}),
      ),
      ConfigSliderField(
        label: "Speed",
        value: _speed(config),
        min: 0.3,
        max: 3.0,
        divisions: 27,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'speed': v}),
      ),
      ConfigSliderField(
        label: "Circle count",
        value: circleCount.toDouble(),
        min: 2,
        max: 6,
        divisions: 4,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'circleCount': v}),
      ),
      ConfigSliderField(
        label: "Circle size",
        value: _circleSize(config),
        min: 0.5,
        max: 2.0,
        divisions: 15,
        format: (v) => "${v.toStringAsFixed(1)}x",
        onChanged: (v) => onConfigChanged({...config, 'circleSize': v}),
      ),
      ConfigSliderField(
        label: "Blur",
        value: _blur(config),
        min: 0,
        max: 20,
        divisions: 40,
        format: (v) => v.toStringAsFixed(1),
        onChanged: (v) => onConfigChanged({...config, 'blur': v}),
      ),
      ConfigColorField(
        label: "Colors",
        palette: palette,
        selected: selected,
        maxSelected: 6,
        onChanged: (colors) => onConfigChanged({...config, 'colors': colors.map((c) => c.toARGB32()).toList()}),
      ),
    ];
  }
}

class _MovingBackgroundWallpaperView extends StatefulWidget {
  final Map<String, dynamic> config;

  const _MovingBackgroundWallpaperView({required this.config});

  @override
  State<_MovingBackgroundWallpaperView> createState() => _MovingBackgroundWallpaperViewState();
}

class _MovingBackgroundWallpaperViewState extends State<_MovingBackgroundWallpaperView> {
  // `MovingBackground` resets every circle's position (`didUpdateWidget`
  // compares `circles` by identity) whenever it's handed a new `circles`
  // list -- rebuilding one fresh with `List.generate` on every build (e.g.
  // an unrelated ancestor rebuild) reset the animation on every rebuild,
  // not just an actual config change. Cache it and only build a new one when
  // the values that actually shape it change.
  String? _circlesKey;
  List<MovingCircle>? _circles;

  List<MovingCircle> _circlesFor(List<Color> colors, int circleCount, double sizeMultiplier, double blur) {
    final key = '$circleCount-$sizeMultiplier-$blur-${colors.map((c) => c.toARGB32()).join(',')}';
    if (_circlesKey != key) {
      _circlesKey = key;
      _circles = List.generate(
        circleCount,
        (i) => MovingCircle(
          color: colors[i % colors.length].withValues(alpha: 0.55),
          radius: (110 + i * 35) * sizeMultiplier,
          blurSigma: blur,
        ),
      );
    }
    return _circles!;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = MovingBackgroundWallpaperDefinition._colors(widget.config, palette);
    final circleCount = MovingBackgroundWallpaperDefinition._circleCount(widget.config);
    final sizeMultiplier = MovingBackgroundWallpaperDefinition._circleSize(widget.config);
    final speed = MovingBackgroundWallpaperDefinition._speed(widget.config);
    final blur = MovingBackgroundWallpaperDefinition._blur(widget.config);
    final durationMs = (14000 / speed).round();

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: MovingBackground(
        backgroundColor: Colors.transparent,
        animationType: MovingBackgroundWallpaperDefinition._animationType(widget.config),
        duration: Duration(milliseconds: durationMs),
        circles: _circlesFor(colors, circleCount, sizeMultiplier, blur),
      ),
    );
  }
}
