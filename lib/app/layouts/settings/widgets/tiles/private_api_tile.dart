import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Optimized reactive tile for Private API Features
/// Only rebuilds when enablePrivateAPI or serverPrivateAPI changes
class PrivateAPITile extends StatelessWidget {
  final Color tileColor;

  const PrivateAPITile({super.key, required this.tileColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsTile(
        backgroundColor: tileColor,
        title: "Private API Features",
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SettingsSvc.settings.enablePrivateAPI.value
                  ? SettingsSvc.settings.serverPrivateAPI.value == false
                        ? "Not Set Up"
                        : "Enabled"
                  : "Disabled",
              style: context.theme.textTheme.bodyMedium!.apply(
                color: context.theme.colorScheme.outline.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 5),
            const NextButton(),
          ],
        ),
        onTap: () async {
          NavigationSvc.pushAndRemoveSettingsUntil(context, PrivateAPIPanel(), (Route route) => route.isFirst);
        },
        leading: SettingsLeadingIcon(
          expressive: true,
          iosIcon: CupertinoIcons.exclamationmark_shield_fill,
          materialIcon: Icons.gpp_maybe,
          containerColor: SettingsSvc.settings.enablePrivateAPI.value
              ? SettingsSvc.settings.serverPrivateAPI.value == false
                    ? Colors.red[700]
                    : Colors.green
              : Colors.amber,
        ),
      ),
    );
  }
}
