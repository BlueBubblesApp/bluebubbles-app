import 'dart:math';

import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_definition.dart';
import 'package:bluebubbles/app/components/wallpaper/theme_wallpaper_palette.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mesh/mesh.dart';

/// Wallpaper backed by the `mesh` package — a free-form mesh gradient blending
/// the chat's theme colors across a distorted grid of vertices.
///
/// The only static entry in the registry: there's no animation controller here
/// at all, so [isAnimated] is false and the picker files it under its own
/// section. Everything else (config schema, persistence, live preview) is
/// identical to the animated ones.
class MeshGradientWallpaperDefinition extends DynamicWallpaperDefinition {
  MeshGradientWallpaperDefinition()
      : super(id: 'mesh_gradient', displayName: 'Mesh Gradient', icon: Icons.format_color_fill_rounded);

  @override
  bool get isAnimated => false;

  static const _colorSpaces = <ConfigChoiceOption>[
    ConfigChoiceOption(value: 'lab', label: 'Natural', icon: Icons.palette_rounded),
    ConfigChoiceOption(value: 'linear', label: 'Linear', icon: Icons.linear_scale_rounded),
    ConfigChoiceOption(value: 'xyY', label: 'Vivid', icon: Icons.auto_awesome_rounded),
  ];

  /// `OMeshRect` asserts `width > 1 && height > 1`. At a grid of 2 every vertex
  /// is a corner, so distortion has nothing to move — that's the plain
  /// four-corner gradient case.
  static int _gridSize(Map<String, dynamic> c) => ((c['gridSize'] as num?)?.toInt() ?? 3).clamp(2, 5).toInt();

  static double _distortion(Map<String, dynamic> c) => ((c['distortion'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 0.5);
  static int _variation(Map<String, dynamic> c) => ((c['variation'] as num?)?.toInt() ?? 1).clamp(1, 12).toInt();
  static int _tessellation(Map<String, dynamic> c) => ((c['tessellation'] as num?)?.toInt() ?? 12).clamp(2, 20).toInt();
  static bool _smoothColors(Map<String, dynamic> c) => (c['smoothColors'] as bool?) ?? true;

  static OMeshColorSpace _colorSpace(Map<String, dynamic> c) {
    final raw = (c['colorSpace'] as String?) ?? 'lab';
    return OMeshColorSpace.values.firstWhere((e) => e.name == raw, orElse: () => OMeshColorSpace.lab);
  }

  static List<Color> _colors(Map<String, dynamic> c, List<Color> fallbackPalette) {
    final raw = (c['colors'] as List?)?.whereType<num>().map((e) => Color(e.toInt())).toList();
    if (raw != null && raw.isNotEmpty) return raw;
    return fallbackPalette.isNotEmpty ? fallbackPalette : const [Colors.blue, Colors.purple, Colors.pink];
  }

  /// Builds the vertex grid in row-major order, offset from a regular lattice
  /// by [distortion] — that irregularity is the whole point of a mesh gradient
  /// versus a plain linear one.
  ///
  /// Seeded off [variation] so the layout is *stable*: an unrelated ancestor
  /// rebuild must not reshuffle the user's wallpaper, and the config screen's
  /// preview has to match what actually gets applied. Edge vertices only slide
  /// along their own edge and corners don't move at all, so the mesh always
  /// covers the full rect instead of pulling away from a side.
  static List<OVertex> _vertices(int size, double distortion, int variation) {
    final rng = Random(variation * 7919);
    final step = 1 / (size - 1);
    final vertices = <OVertex>[];

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final onLeft = col == 0;
        final onRight = col == size - 1;
        final onTop = row == 0;
        final onBottom = row == size - 1;

        final jitterX = (rng.nextDouble() - 0.5) * step * distortion * 2;
        final jitterY = (rng.nextDouble() - 0.5) * step * distortion * 2;

        final x = (onLeft || onRight) ? (onLeft ? 0.0 : 1.0) : (col * step + jitterX).clamp(0.0, 1.0);
        final y = (onTop || onBottom) ? (onTop ? 0.0 : 1.0) : (row * step + jitterY).clamp(0.0, 1.0);

        vertices.add(OVertex(x, y));
      }
    }
    return vertices;
  }

  /// Indexes the palette on `row + col` rather than the flat vertex index —
  /// a flat index walks the palette in reading order and produces obvious
  /// horizontal banding, while the diagonal keeps neighbors distinct.
  static List<Color?> _vertexColors(int size, List<Color> colors) {
    return [
      for (var row = 0; row < size; row++)
        for (var col = 0; col < size; col++) colors[(row + col) % colors.length],
    ];
  }

  @override
  Map<String, dynamic> defaultConfig(BuildContext context, {required bool isIMessage}) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: isIMessage);
    final colors = palette.take(4).toList();
    return {
      'gridSize': 3.0,
      'distortion': 0.25,
      'variation': 1.0,
      'tessellation': 12.0,
      'colorSpace': 'lab',
      'smoothColors': true,
      'colors': (colors.isEmpty ? [Colors.blue, Colors.purple, Colors.pink] : colors)
          .map((c) => c.toARGB32())
          .toList(),
    };
  }

  @override
  Widget buildView(BuildContext context, Map<String, dynamic> config) {
    return _MeshGradientWallpaperView(config: config);
  }

  @override
  List<ConfigField> buildConfigFields(
    BuildContext context,
    Map<String, dynamic> config,
    void Function(Map<String, dynamic> next) onConfigChanged,
  ) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final selected = _colors(config, palette).take(6).toList();

    return [
      ConfigSliderField(
        label: "Grid",
        value: _gridSize(config).toDouble(),
        min: 2,
        max: 5,
        divisions: 3,
        format: (v) => "${v.toStringAsFixed(0)}×${v.toStringAsFixed(0)}",
        onChanged: (v) => onConfigChanged({...config, 'gridSize': v}),
      ),
      ConfigSliderField(
        label: "Distortion",
        value: _distortion(config),
        min: 0,
        max: 0.5,
        divisions: 20,
        format: (v) => "${(v * 200).round()}%",
        onChanged: (v) => onConfigChanged({...config, 'distortion': v}),
      ),
      ConfigSliderField(
        label: "Variation",
        value: _variation(config).toDouble(),
        min: 1,
        max: 12,
        divisions: 11,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'variation': v}),
      ),
      ConfigSliderField(
        label: "Smoothness",
        value: _tessellation(config).toDouble(),
        min: 2,
        max: 20,
        divisions: 18,
        format: (v) => v.toStringAsFixed(0),
        onChanged: (v) => onConfigChanged({...config, 'tessellation': v}),
      ),
      ConfigChoiceField(
        label: "Blending",
        value: _colorSpace(config).name,
        options: _colorSpaces,
        onChanged: (v) => onConfigChanged({...config, 'colorSpace': v}),
      ),
      ConfigToggleField(
        label: "Soften color edges",
        value: _smoothColors(config),
        onChanged: (v) => onConfigChanged({...config, 'smoothColors': v}),
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

class _MeshGradientWallpaperView extends StatelessWidget {
  final Map<String, dynamic> config;

  const _MeshGradientWallpaperView({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeWallpaperPalette.fromContext(context, isIMessage: true);
    final colors = MeshGradientWallpaperDefinition._colors(config, palette);
    final size = MeshGradientWallpaperDefinition._gridSize(config);

    return ColoredBox(
      color: context.theme.colorScheme.surface,
      child: ClipRect(
        child: OMeshGradient(
          tessellation: MeshGradientWallpaperDefinition._tessellation(config),
          mesh: OMeshRect(
            width: size,
            height: size,
            vertices: MeshGradientWallpaperDefinition._vertices(
              size,
              MeshGradientWallpaperDefinition._distortion(config),
              MeshGradientWallpaperDefinition._variation(config),
            ),
            colors: MeshGradientWallpaperDefinition._vertexColors(size, colors),
            colorSpace: MeshGradientWallpaperDefinition._colorSpace(config),
            smoothColors: MeshGradientWallpaperDefinition._smoothColors(config),
            fallbackColor: context.theme.colorScheme.surface,
          ),
        ),
      ),
    );
  }
}
