import 'package:bluebubbles/app/components/bb_slider.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSlider extends StatelessWidget {
  const SettingsSlider(
      {required this.startingVal,
      this.update,
      this.onChangeEnd,
      this.formatValue,
      required this.min,
      required this.max,
      this.leadingMinWidth,
      required this.divisions,
      this.leading,
      this.backgroundColor,
      super.key});

  final double startingVal;
  final Function(double val)? update;
  final Function(double val)? onChangeEnd;
  final Function(double value)? formatValue;
  final double min;
  final double max;
  final double? leadingMinWidth;
  final int divisions;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    String value = startingVal.toString();
    if (formatValue != null) {
      value = formatValue!(startingVal);
    }

    return ListTile(
      leading: leading,
      trailing: Text(value, style: context.theme.textTheme.bodyLarge),
      minLeadingWidth: leadingMinWidth,
      title: BBSlider(
        value: startingVal,
        onChanged: update,
        onChangeEnd: onChangeEnd,
        label: value,
        divisions: divisions,
        min: min,
        max: max,
      ),
    );
  }
}
