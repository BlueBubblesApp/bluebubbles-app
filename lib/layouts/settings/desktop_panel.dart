import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../repository/models/models.dart';

class DesktopPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final RxnBool useCustomPath = RxnBool(prefs.getBool("use-custom-path"));
    final RxnString customPath = RxnString(prefs.getString("custom-path"));
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
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Advanced"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      onChanged: (bool val) async {
                        useCustomPath.value = val;
                        if ((!val && prefs.getString("custom-path") != customPath.value) || prefs.getBool("use-custom-path") == true) {
                          await showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Are you sure?",
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                                content: Text(
                                    "All of your data and settings will be deleted, and you will have to set the app up again from scratch."),
                                backgroundColor: context.theme.colorScheme.secondary,
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Yes"),
                                    onPressed: () async {
                                      prefs.setBool("use-custom-path", val);
                                      await DBProvider.deleteDB();
                                      await SettingsManager().resetConnection();
                                      SettingsManager().settings.finishedSetup.value = false;
                                      SettingsManager().settings = Settings();
                                      SettingsManager().settings.save();
                                      SettingsManager().fcmData = null;
                                      FCMData.deleteFcmData();
                                      appWindow.close();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Cancel"),
                                    onPressed: () {
                                      useCustomPath.value = true;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      title: 'Use Custom Database Path',
                      subtitle:
                          'You will have to set the app up again from scratch',
                      initialVal: useCustomPath.value ?? false,
                    ),
                  ),
                  Obx(
                    () => useCustomPath.value == true ? SettingsTile(
                      title: "Set Custom Path",
                      subtitle: "Custom Path: ${prefs.getBool('use-custom-path') == true ? customPath.value ?? "": ""}" ,
                      trailing: TextButton(
                        onPressed: () async {
                          String? path = await FilePicker.platform
                              .getDirectoryPath(dialogTitle: 'Select a Folder', lockParentWindow: true);
                          if (path == null) {
                            showSnackbar("Notice", "You did not select a folder!");
                            return;
                          }
                          if (prefs.getBool("use-custom-path") == true && path == customPath.value) {
                            return;
                          }
                          await showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Are you sure?",
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                                content: Text(
                                    "The database will now be stored at $path\n\nAll of your data and settings will be deleted, and you will have to set the app up again from scratch."),
                                backgroundColor: context.theme.colorScheme.secondary,
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Yes"),
                                    onPressed: () async {
                                      customPath.value = path;
                                      await DBProvider.deleteDB();
                                      await SettingsManager().resetConnection();
                                      SettingsManager().settings.finishedSetup.value = false;
                                      SettingsManager().settings = Settings();
                                      SettingsManager().settings.save();
                                      SettingsManager().fcmData = null;
                                      FCMData.deleteFcmData();
                                      prefs.setBool("use-custom-path", true);
                                      prefs.setString("custom-path", path);
                                      appWindow.close();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Cancel"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Text(
                          "Click here to select a folder",
                        ),
                      ),
                    ) : SizedBox.shrink(),
                  ),
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
