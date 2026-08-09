import 'package:flutter/material.dart';

/// Generic, skin-agnostic description of one editable control on a dynamic
/// wallpaper's config screen. [DynamicWallpaperDefinition.buildConfigFields]
/// returns a list of these; the config page shell (one body per skin) turns
/// each into the appropriate row widget. This is what makes adding a new
/// dynamic wallpaper type "free" from a UI perspective — it only has to
/// describe its knobs, not build three skin-specific screens for them.
sealed class ConfigField {
  final String label;
  const ConfigField(this.label);
}

class ConfigSliderField extends ConfigField {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value)? format;
  final void Function(double value) onChanged;

  const ConfigSliderField({
    required String label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.format,
  }) : super(label);
}

class ConfigChoiceOption {
  final String value;
  final String label;
  final IconData? icon;

  const ConfigChoiceOption({required this.value, required this.label, this.icon});
}

class ConfigChoiceField extends ConfigField {
  final String value;
  final List<ConfigChoiceOption> options;
  final void Function(String value) onChanged;

  const ConfigChoiceField({
    required String label,
    required this.value,
    required this.options,
    required this.onChanged,
  }) : super(label);
}

class ConfigToggleField extends ConfigField {
  final bool value;
  final void Function(bool value) onChanged;

  const ConfigToggleField({
    required String label,
    required this.value,
    required this.onChanged,
  }) : super(label);
}

/// A palette swatch picker. When [maxSelected] is 1 this behaves as a
/// single-select (e.g. floating-shape color); larger values allow selecting
/// several colors in order (e.g. wave layer colors).
class ConfigColorField extends ConfigField {
  final List<Color> palette;
  final List<Color> selected;
  final int maxSelected;
  final void Function(List<Color> selected) onChanged;

  const ConfigColorField({
    required String label,
    required this.palette,
    required this.selected,
    required this.onChanged,
    this.maxSelected = 1,
  }) : super(label);
}
