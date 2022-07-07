import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSlider extends StatelessWidget {
  SettingsSlider(
      {required this.startingVal,
        this.update,
        this.onChangeEnd,
        required this.text,
        this.formatValue,
        required this.min,
        required this.max,
        required this.divisions,
        this.leading,
        this.backgroundColor,
        Key? key})
      : super(key: key);

  final double startingVal;
  final Function(double val)? update;
  final Function(double val)? onChangeEnd;
  final String text;
  final Function(double value)? formatValue;
  final double min;
  final double max;
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
      title: SettingsManager().settings.skin.value == Skins.iOS
          ? CupertinoSlider(
        activeColor: context.theme.colorScheme.primary.withOpacity(0.6),
        thumbColor: context.theme.colorScheme.primary,
        value: startingVal,
        onChanged: update,
        onChangeEnd: onChangeEnd,
        divisions: divisions,
        min: min,
        max: max,
      )
          : Slider(
        activeColor: context.theme.colorScheme.primary.withOpacity(0.6),
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
