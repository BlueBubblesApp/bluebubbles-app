import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TroubleshootPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
        Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return SettingsScaffold(
      title: "Troubleshooting",
      initialHeader: "Logging",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsTile(
                    backgroundColor: tileColor,
                    onTap: () async {
                      if (Logger.saveLogs.value) {
                        await Logger.stopSavingLogs();
                        Logger.saveLogs.value = false;
                      } else {
                        Logger.startSavingLogs();
                      }
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.pencil_ellipsis_rectangle,
                      materialIcon: Icons.history_edu,
                    ),
                    title: "${Logger.saveLogs.value ? "End" : "Start"} Logging",
                    subtitle: Logger.saveLogs.value
                        ? "Logging started, tap here to end and save"
                        : "Create a bug report for developers to analyze",
                  )),
                ]
              ),
            ],
          ),
        ),
      ]
    );
  }
}
