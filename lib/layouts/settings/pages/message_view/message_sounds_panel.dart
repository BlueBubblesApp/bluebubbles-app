import 'dart:io';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class MessageSoundsPanelController extends GetxController {
  late Settings _settingsCopy;
  bool isFetching = false;
  final RxList<Widget> handleWidgets = <Widget>[].obs;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  void dispose() {
    SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class MessageSoundsPanel extends StatelessWidget {
  final controller = Get.put(MessageSoundsPanelController());

  @override
  Widget build(BuildContext context) {
    final iosSubtitle = context.theme.textTheme.labelLarge?.copyWith(
        color: ThemeManager().inDarkMode(context)
            ? context.theme.colorScheme.onBackground
            : context.theme.colorScheme.properOnSurface,
        fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme.textTheme.labelLarge?.copyWith(
        color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background
        : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface
        : context.theme.colorScheme.background;

    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material &&
        ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return SettingsScaffold(
        title: "Sounds",
        initialHeader: null,
        iosSubtitle: null,
        materialSubtitle: null,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          Obx(() => SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Send Sound"),
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.playSendSound.value = val;
                        SettingsManager().saveSettings();
                      },
                      initialVal:
                          SettingsManager().settings.playSendSound.value,
                      title: "Play Send Sound",
                      backgroundColor: tileColor,
                    ),
                    if (SettingsManager().settings.playSendSound.value)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(
                              color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (SettingsManager().settings.playSendSound.value)
                      if (SettingsManager().settings.sendSoundPath.value ==
                          null)
                        SettingsTile(
                          title: "Custom Send Sound",
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(type: FileType.audio);
                            if (result != null) {
                              PlatformFile platformFile = result.files.first;

                              // save file to internal documents directory
                              // no web support
                              Directory documentsDirectory =
                                  (await getApplicationDocumentsDirectory());
                              String path =
                                  "${documentsDirectory.path}/${"send-"}${platformFile.name}";
                              await File(platformFile.path!).copy(path);
                              SettingsManager().settings.sendSoundPath.value =
                                  path;
                              SettingsManager().saveSettings();
                            }
                          },
                        ),
                    if (SettingsManager().settings.playSendSound.value)
                      if (SettingsManager().settings.sendSoundPath.value !=
                          null)
                        SettingsTile(
                          title: "Delete Send Sound",
                          onTap: () async {
                            File file = File(SettingsManager()
                                .settings
                                .sendSoundPath
                                .value!);
                            if (await file.exists()) {
                              await file.delete();
                            }
                            SettingsManager().settings.sendSoundPath.value =
                                null;
                            SettingsManager().saveSettings();
                          },
                        ),
                  ]),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Receive Sound"),
                  SettingsSection(backgroundColor: tileColor, children: [
                    SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.playReceiveSound.value = val;
                        SettingsManager().saveSettings();
                      },
                      initialVal:
                          SettingsManager().settings.playReceiveSound.value,
                      title: "Play Receive Sound",
                      backgroundColor: tileColor,
                    ),
                    if (SettingsManager().settings.playReceiveSound.value)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(
                              color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (SettingsManager().settings.playReceiveSound.value)
                      if (SettingsManager().settings.receiveSoundPath.value ==
                          null)
                        SettingsTile(
                          title: "Custom Receive Sound",
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(type: FileType.audio);
                            if (result != null) {
                              PlatformFile platformFile = result.files.first;

                              // save file to internal documents directory
                              Directory documentsDirectory =
                                  (await getApplicationDocumentsDirectory());
                              String path =
                                  "${documentsDirectory.path}/${"receive-"}${platformFile.name}";
                              await File(platformFile.path!).copy(path);
                              SettingsManager()
                                  .settings
                                  .receiveSoundPath
                                  .value = path;
                              SettingsManager().saveSettings();
                            }
                          },
                        ),
                    if (SettingsManager().settings.playReceiveSound.value)
                      if (SettingsManager().settings.receiveSoundPath.value !=
                          null)
                        SettingsTile(
                          title: "Delete Receive Sound",
                          onTap: () async {
                            File file = File(SettingsManager()
                                .settings
                                .receiveSoundPath
                                .value!);
                            if (await file.exists()) {
                              await file.delete();
                            }
                            SettingsManager().settings.receiveSoundPath.value =
                                null;
                            SettingsManager().saveSettings();
                          },
                        ),
                  ]),
                ]),
              )),
        ]);
  }
}
