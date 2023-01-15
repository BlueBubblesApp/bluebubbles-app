import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    Key? key,
    this.onTap,
    this.onLongPress,
    this.title,
    this.trailing,
    this.leading,
    this.subtitle,
    this.backgroundColor,
    this.isThreeLine = false,
  }) : super(key: key);

  final Function? onTap;
  final Function? onLongPress;
  final String? subtitle;
  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final Color? backgroundColor;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap as void Function()?,
        onLongPress: onLongPress as void Function()?,
        splashColor: context.theme.colorScheme.surfaceVariant,
        splashFactory: context.theme.splashFactory,
        child: GestureDetector(
          onSecondaryTapUp: (details) async {
            if (kIsWeb) {
              (await html.document.onContextMenu.first).preventDefault();
            }
            onLongPress?.call();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            leading: leading,
            title: title != null ? Text(
              title!,
              style: context.theme.textTheme.bodyLarge,
            ) : null,
            trailing: trailing,
            subtitle: subtitle != null
                ? Text(
              subtitle!,
              style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: isThreeLine ? 1.5 : 1),
            ) : null,
            contentPadding: EdgeInsets.symmetric(vertical: isThreeLine ? 10 : 0, horizontal: 16.0),
          ),
        ),
      ),
    );
  }
}
