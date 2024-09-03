import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.onTap,
    this.onLongPress,
    this.title,
    this.trailing,
    this.leading,
    this.subtitle,
    this.backgroundColor,
    this.isThreeLine = false,
  });

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
            enableFeedback: true,
            minVerticalPadding: 10,
            horizontalTitleGap: 10,
            dense: ss.settings.skin.value == Skins.iOS ? true : false,
            leading: leading == null ? null : Padding(
              padding: EdgeInsets.only(bottom: isThreeLine ? 10 : 0.0, right: 5),
              child: leading,
            ),
            title: title != null ? Text(
              title!,
              style: context.theme.textTheme.bodyLarge,
            ) : null,
            trailing: trailing == null ? null : Padding(
              padding: EdgeInsets.only(bottom: isThreeLine ? 10 : 0.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  trailing!,
                ],
              ),
            ),
            subtitle: subtitle != null ? Text(
              subtitle!,
              style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface, height: 1.5),
            ) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
        ),
      ),
    );
  }
}
