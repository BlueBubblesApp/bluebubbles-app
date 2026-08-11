import 'package:bluebubbles/app/layouts/settings/pages/advanced/redacted_mode_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Optimized reactive tile for Redacted Mode
/// Only rebuilds when redactedMode setting changes
class RedactedModeTile extends StatelessWidget {
  final Color tileColor;

  const RedactedModeTile({super.key, required this.tileColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsTile(
        backgroundColor: tileColor,
        title: "Redacted Mode",
        activePage: RedactedModePanel,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SettingsSvc.settings.redactedMode.value ? "Enabled" : "Disabled",
              style: context.theme.textTheme.bodyMedium!.apply(
                color: context.theme.colorScheme.outline.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 5),
            const NextButton(),
          ],
        ),
        onTap: () async {
          NavigationSvc.pushAndRemoveSettingsUntil(context, const RedactedModePanel(), (Route route) => route.isFirst);
        },
        leading: SettingsLeadingIcon(
          iosIcon: CupertinoIcons.wand_stars,
          materialIcon: Icons.auto_fix_high,
          containerColor: SettingsSvc.settings.redactedMode.value ? Colors.green : Colors.red[700],
        ),
      ),
    );
  }
}
