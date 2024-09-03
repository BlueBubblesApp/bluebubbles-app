import 'package:bluebubbles/app/layouts/settings/widgets/content/settings_leading_icon.dart';
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
    this.leading,
  });
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;
  final bool isThreeLine;
  final SettingsLeadingIcon? leading;

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
          leading: leading == null ? null : Padding(
            padding: EdgeInsets.only(bottom: isThreeLine ? 10 : 0.0, right: 5),
            child: leading,
          ),
          trailing: Switch(
            value: initialVal,
            activeColor: context.theme.colorScheme.primary.lightenOrDarken(15),
            onChanged: onChanged,
          ),
          subtitle: subtitle != null ? Text(
            subtitle!,
            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface.withOpacity(0.75), height: 1.5),
          ) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
      ),
    );
  }
}
