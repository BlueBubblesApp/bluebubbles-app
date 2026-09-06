import 'package:bluebubbles/app/layouts/settings/pages/advanced/app_updates_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Reactive tile for the App Updates settings page — only rebuilds when
/// update availability changes.
class AppUpdatesTile extends StatelessWidget {
  final Color tileColor;

  const AppUpdatesTile({super.key, required this.tileColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsTile(
        backgroundColor: tileColor,
        title: "App Updates",
        activePage: AppUpdatesPanel,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (UpdateSvc.updateAvailable.value)
              Text(
                "Update Available",
                style: context.theme.textTheme.bodyMedium!.apply(color: Colors.green),
              ),
            const SizedBox(width: 5),
            const NextButton(),
          ],
        ),
        onTap: () async {
          NavigationSvc.pushAndRemoveSettingsUntil(context, const AppUpdatesPanel(), (Route route) => route.isFirst);
        },
        leading: SettingsLeadingIcon(
          iosIcon: CupertinoIcons.arrow_down_circle,
          materialIcon: Icons.system_update,
          containerColor: UpdateSvc.updateAvailable.value ? Colors.green : null,
        ),
      ),
    );
  }
}
