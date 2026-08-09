import 'package:bluebubbles/app/components/wallpaper/dynamic_wallpaper_config_field.dart';
import 'package:bluebubbles/app/components/bb_switch.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Renders one [ConfigField] as a row. Shared by the Cupertino and
/// Material/Samsung-expressive config bodies — [expressive] only changes
/// label typography so it fits whichever section container it's dropped
/// into (`SettingsSection` vs `M3ESection`).
Widget buildConfigFieldRow(BuildContext context, ConfigField field, {required bool expressive}) {
  final labelStyle = expressive
      ? context.theme.textTheme.bodyLarge
      : context.theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);

  Widget label() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(field.label, style: labelStyle),
      );

  return switch (field) {
    ConfigSliderField f => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(),
          SettingsSlider(
            startingVal: f.value.clamp(f.min, f.max).toDouble(),
            min: f.min,
            max: f.max,
            divisions: f.divisions,
            formatValue: f.format,
            update: f.onChanged,
          ),
        ],
      ),
    ConfigChoiceField f => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(),
          SettingsOptions<String>(
            title: "",
            initial: f.value,
            options: f.options.map((o) => o.value).toList(),
            capitalize: false,
            textProcessing: (v) => f.options.firstWhere((o) => o.value == v).label,
            onChanged: (v) {
              if (v != null) f.onChanged(v);
            },
          ),
        ],
      ),
    ConfigToggleField f => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(f.label, style: labelStyle)),
            BBSwitch(value: f.value, onChanged: f.onChanged),
          ],
        ),
      ),
    ConfigColorField f => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _ColorSwatchPicker(field: f),
          ),
        ],
      ),
  };
}

class _ColorSwatchPicker extends StatelessWidget {
  final ConfigColorField field;

  const _ColorSwatchPicker({required this.field});

  void _tap(Color color) {
    final selected = List<Color>.from(field.selected);
    final index = selected.indexWhere((c) => c.toARGB32() == color.toARGB32());

    if (field.maxSelected <= 1) {
      field.onChanged([color]);
      return;
    }

    if (index != -1) {
      // Keep at least one color selected.
      if (selected.length > 1) selected.removeAt(index);
    } else if (selected.length < field.maxSelected) {
      selected.add(color);
    } else {
      selected
        ..removeAt(0)
        ..add(color);
    }
    field.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: field.palette.map((color) {
        final selected = field.selected.any((c) => c.toARGB32() == color.toARGB32());
        return GestureDetector(
          onTap: () => _tap(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? context.theme.colorScheme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 1)),
              ],
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
