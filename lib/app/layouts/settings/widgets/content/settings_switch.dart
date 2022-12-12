import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSwitch extends StatelessWidget {
  SettingsSwitch({
    Key? key,
    required this.initialVal,
    required this.onChanged,
    required this.title,
    this.backgroundColor,
    this.subtitle,
    this.isThreeLine = false,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    final thumbColor = context.theme.colorScheme.surface.computeDifference(backgroundColor) < 15
        ? context.theme.colorScheme.onSurface.withOpacity(0.6) : context.theme.colorScheme.surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged.call(!initialVal),
        splashColor: context.theme.colorScheme.surfaceVariant,
        splashFactory: context.theme.splashFactory,
        child: SwitchListTile(
          title: Text(
            title,
            style: context.theme.textTheme.bodyLarge,
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle!,
            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: isThreeLine ? 1.5 : 1),
          ) : null,
          value: initialVal,
          activeColor: context.theme.colorScheme.primary,
          activeTrackColor: context.theme.colorScheme.primaryContainer,
          // make sure the track color does not blend in with the background color of the tiles
          inactiveTrackColor: context.theme.colorScheme.surfaceVariant.computeDifference(backgroundColor) < 15
              ? context.theme.colorScheme.surface.computeDifference(backgroundColor) < 15
              ? thumbColor.darkenPercent(20)
              : context.theme.colorScheme.surface.withOpacity(0.6)
              : context.theme.colorScheme.surfaceVariant,
          inactiveThumbColor: thumbColor,
          onChanged: onChanged,
          contentPadding: EdgeInsets.symmetric(vertical: isThreeLine ? 10 : 0, horizontal: 16.0),
        ),
      ),
    );
  }
}
