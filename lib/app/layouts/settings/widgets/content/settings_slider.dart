import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSlider extends StatelessWidget {
  SettingsSlider(
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
        Key? key})
      : super(key: key);

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
      title: Slider(
        activeColor: context.theme.colorScheme.primary.oppositeLightenOrDarken(20),
        secondaryActiveColor: context.theme.colorScheme.primary.withOpacity(0.6),
        thumbColor: context.theme.colorScheme.primary,
        inactiveColor: context.theme.colorScheme.primary.withOpacity(0.2),
        value: startingVal,
        onChanged: update,
        onChangeEnd: onChangeEnd,
        label: value,
        divisions: divisions,
        min: min,
        max: max,
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}
