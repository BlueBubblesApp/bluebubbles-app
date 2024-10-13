import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttachmentPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends OptimizedState<AttachmentPanel> {
  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Attachments & Media",
        initialHeader: "Download & Save",
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
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.autoDownload.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.autoDownload.value,
                          title: "Auto-download Attachments",
                          subtitle: "Automatically downloads new attachments from the server and caches them internally",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.onlyWifiDownload.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.onlyWifiDownload.value,
                          title: "Only Auto-download Attachments on WiFi",
                          backgroundColor: tileColor,
                        )),
                    if (!kIsWeb && !kIsDesktop)
                      const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.autoSave.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.autoSave.value,
                            title: "Auto-save Attachments",
                            subtitle: "Automatically saves all attachments to folders selected below",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                    if (!kIsWeb && !kIsDesktop)
                      const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsTile(
                        title: "Save Media Location",
                        subtitle: "Saving images and videos to ${ss.settings.autoSavePicsLocation.value}",
                        backgroundColor: tileColor,
                        onTap: () async {
                          final TextEditingController pathController = TextEditingController();
                          await showDialog(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                actions: [
                                  TextButton(
                                    child: Text("Cancel",
                                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () => Get.back(),
                                  ),
                                  TextButton(
                                    child: Text("OK",
                                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      if (pathController.text.isEmpty) {
                                        Get.back();
                                        ss.settings.autoSavePicsLocation.value = "Pictures";
                                      } else {
                                        final regex = RegExp(r"^[a-zA-Z0-9-_]+");
                                        if (!regex.hasMatch(pathController.text) || pathController.text.endsWith("/")) {
                                          showSnackbar("Error", "Enter a valid path!");
                                          return;
                                        }
                                        Get.back();
                                        ss.settings.autoSavePicsLocation.value = "Pictures/${pathController.text}";
                                      }
                                      saveSettings();
                                    },
                                  ),
                                ],
                                content: Row(
                                  children: [
                                    Text("Pictures/", style: context.theme.textTheme.titleMedium),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: pathController,
                                        decoration: const InputDecoration(
                                          labelText: "Relative Path",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text("Enter Relative Path", style: context.theme.textTheme.titleLarge),
                                backgroundColor: context.theme.colorScheme.properSurface,
                              );
                            }
                          );
                        },
                      )),
                    if (!kIsWeb && !kIsDesktop)
                      const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsTile(
                        title: "Save Documents Location",
                        subtitle: "Saving documents and videos to ${ss.settings.autoSaveDocsLocation.value.replaceAll("/storage/emulated/0/", "")}",
                        backgroundColor: tileColor,
                        onTap: () async {
                          final savePath = await FilePicker.platform.getDirectoryPath(
                            initialDirectory: ss.settings.autoSaveDocsLocation.value,
                            dialogTitle: 'Choose a location to auto-save documents',
                            lockParentWindow: true,
                          );
                          if (savePath != null) {
                            ss.settings.autoSaveDocsLocation.value = savePath;
                            saveSettings();
                          }
                        },
                      )),
                    if (!kIsWeb && !kIsDesktop)
                      const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.askWhereToSave.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.askWhereToSave.value,
                            title: "Ask Where to Save Attachments",
                            subtitle: "Ask where to save attachments when manually downloading",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
                SettingsHeader(
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Video Mute Behavior"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    const SettingsSubtitle(
                      subtitle: "Set where videos start playing muted",
                      bottomPadding: false,
                    ),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.startVideosMuted.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.startVideosMuted.value,
                          title: "Mute in Attachment Preview",
                          backgroundColor: tileColor,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.startVideosMutedFullscreen.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.startVideosMutedFullscreen.value,
                          title: "Mute in Fullscreen Player",
                          backgroundColor: tileColor,
                        )),
                  ],
                ),
                if (!kIsWeb)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Attachment Viewer"),
                if (!kIsWeb)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        if (iOS) {
                          return SettingsTile(
                            title: kIsDesktop ? "Arrow key direction" : "Swipe direction",
                            subtitle: "Set the ${kIsDesktop ? "arrow key" : "swipe direction"} to go to previous media items",
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                      Obx(() => SettingsOptions<SwipeDirection>(
                            initial: ss.settings.fullscreenViewerSwipeDir.value,
                            onChanged: (val) {
                              if (val == null) return;
                              ss.settings.fullscreenViewerSwipeDir.value = val;
                              saveSettings();
                            },
                            options: SwipeDirection.values,
                            textProcessing: (val) => val.toString().split(".").last,
                            capitalize: false,
                            title: "Swipe Direction",
                            subtitle: "Set the swipe direction to go to previous media items",
                            secondaryColor: headerColor,
                          )),
                    ],
                  ),
              ],
            ),
          ),
        ]);
  }

  void saveSettings() {
    ss.saveSettings();
  }
}
