import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A skin-aware slider — renders [CupertinoSlider] under the iOS skin and a
/// Material 3 Expressive-styled [Slider] (see [M3ESlider]) under the Material
/// and Samsung skins. Use this instead of either widget directly.
class BBSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;

  /// Number of discrete steps between [min] and [max]. Null renders a continuous slider.
  final int? divisions;

  /// Shown above the thumb while dragging a discrete (Material/Samsung) slider.
  final String? label;

  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  const BBSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    if (context.iOS) {
      return CupertinoSlider(
        value: value,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: activeColor ?? Theme.of(context).colorScheme.primary,
        thumbColor: thumbColor ?? CupertinoColors.white,
      );
    }

    return SliderTheme(
      data: M3ESlider.themeData(
        context,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        thumbColor: thumbColor,
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        mouseCursor: MouseCursor.defer,
      ),
    );
  }
}
