import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/html/launch_at_startup.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'dart:io';

class DesktopPanel extends StatelessWidget {
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
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() <
                Theme.of(context).backgroundColor.computeLuminance() ||
            SettingsManager().settings.skin.value == Skins.Material) &&
        (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }
    return SettingsScaffold(
      title: "Desktop Settings",
      initialHeader: "Window Behavior",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      headerColor: headerColor,
      tileColor: tileColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.launchAtStartup.value = val;
                          saveSettings();
                          if (val) {
                            await LaunchAtStartup.enable();
                          } else {
                            await LaunchAtStartup.disable();
                          }
                        },
                        initialVal: SettingsManager().settings.launchAtStartup.value,
                        title: "Launch on Startup",
                        subtitle: "Automatically open the desktop app on startup.",
                        backgroundColor: tileColor,
                      )),
                  if (Platform.isLinux)
                    Obx(
                      () => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.useCustomTitleBar.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.useCustomTitleBar.value,
                        title: "Use Custom TitleBar",
                        subtitle:
                            "Enable the custom titlebar. This is necessary on non-GNOME systems, and will not look good on GNOME systems. This is also necessary for 'Close to Tray' and 'Minimize to Tray' to work correctly.",
                        backgroundColor: tileColor,
                      ),
                    ),
                  Obx(() {
                    if (SettingsManager().settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsManager().settings.minimizeToTray.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.minimizeToTray.value,
                          title: "Minimize to Tray",
                          subtitle:
                              "When enabled, clicking the minimize button will minimize the app to the system tray",
                          backgroundColor: tileColor,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsManager().settings.closeToTray.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.closeToTray.value,
                          title: "Close to Tray",
                          subtitle: "When enabled, clicking the close button will minimize the app to the system tray",
                          backgroundColor: tileColor,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
