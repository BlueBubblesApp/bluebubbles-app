import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSwitch extends StatelessWidget {
  SettingsSwitch({
    super.key,
    required this.initialVal,
    required this.onChanged,
    required this.title,
    this.backgroundColor,
    this.subtitle,
    this.isThreeLine = false,
    this.padding = true,
  });
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;
  final bool isThreeLine;
  final bool padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged.call(!initialVal),
        splashColor: context.theme.colorScheme.surfaceVariant,
        splashFactory: context.theme.splashFactory,
        child: ListTile(
          mouseCursor: MouseCursor.defer,
          enableFeedback: true,
          minVerticalPadding: 10,
          horizontalTitleGap: 10,
          title: Text(
            title,
            style: context.theme.textTheme.bodyLarge,
          ),
          trailing: Switch(
            value: initialVal,
            activeColor: context.theme.colorScheme.primary.lightenOrDarken(15),
            onChanged: onChanged,
          ),
          subtitle: subtitle != null ? Text(
            subtitle!,
            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: 1.5),
          ) : null,
          contentPadding: padding ? const EdgeInsets.symmetric(horizontal: 16.0) : EdgeInsets.zero,
        ),
      ),
    );
  }
}
