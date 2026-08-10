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
    this.minVerticalPadding,
    this.activePage,
  });

  final Function? onTap;
  final Function? onLongPress;
  final String? subtitle;
  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final Color? backgroundColor;
  final bool isThreeLine;
  final double? minVerticalPadding;

  /// Settings page this tile opens. When given, the tile stays highlighted
  /// while that page is the one showing in the split view's right pane.
  final Type? activePage;

  @override
  Widget build(BuildContext context) {
    if (activePage == null) return _build(context, false);
    return Obx(() => _build(context, NavigationSvc.activeSettingsPage.value == activePage));
  }

  Widget _build(BuildContext context, bool active) {
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
          // painted above the ink layer, so it just switches on and off instead of
          // cross-fading with hover/splash
          child: ColoredBox(
            color: active ? context.theme.colorScheme.primary : Colors.transparent,
            child: ListTile(
              mouseCursor: MouseCursor.defer,
              enableFeedback: true,
              minVerticalPadding: minVerticalPadding ?? (SettingsSvc.settings.skin.value == Skins.iOS ? 14 : 6),
              horizontalTitleGap: 10,
              dense: false,
              leading: leading == null
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(bottom: isThreeLine ? 10 : 0.0, right: 5, left: 5),
                      child: leading,
                    ),
              title: title != null
                  ? Text(
                      title!,
                      style: context.theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: active ? FontWeight.w600 : null,
                        color: active ? context.theme.colorScheme.onPrimary : null,
                      ),
                    )
                  : null,
              trailing: trailing == null
                  ? null
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isThreeLine ? 10 : 0.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // trailing widgets (status text, caret) bake their colors in at the
                            // call site, so recolor what they paint rather than the theme
                            // they read — alpha survives, hue doesn't
                            if (active)
                              ColorFiltered(
                                colorFilter:
                                    ColorFilter.mode(context.theme.colorScheme.onPrimary, BlendMode.srcATop),
                                child: trailing!,
                              )
                            else
                              trailing!,
                          ],
                        ),
                      ),
                    ),
              subtitle: subtitle != null
                  ? Text(
                      subtitle!,
                      style: context.theme.textTheme.bodySmall!.copyWith(
                          color: (active
                                  ? context.theme.colorScheme.onPrimary
                                  : context.theme.colorScheme.onSurfaceVariant)
                              .withValues(alpha: 0.75),
                          height: 1.5),
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: SettingsSvc.settings.skin.value == Skins.iOS ? 0.0 : 4.0),
            ),
          ),
        ),
      ),
    );
  }
}
