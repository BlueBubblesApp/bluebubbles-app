import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttachmentPanel extends StatefulWidget {
  const AttachmentPanel({super.key});

  @override
  State<StatefulWidget> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> with ThemeHelpers {
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
                          onChanged: (bool val) async {
                            SettingsSvc.settings.autoDownload.value = val;
                            await SettingsSvc.settings.saveOneAsync('autoDownload');
                          },
                          initialVal: SettingsSvc.settings.autoDownload.value,
                          title: "Auto-download Attachments",
                          subtitle:
                              "Automatically downloads new attachments from the server and caches them internally",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.onlyWifiDownload.value = val;
                            await SettingsSvc.settings.saveOneAsync('onlyWifiDownload');
                          },
                          initialVal: SettingsSvc.settings.onlyWifiDownload.value,
                          title: "Only Auto-download Attachments on WiFi",
                          backgroundColor: tileColor,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => SettingsTile(
                              title: "Max Concurrent Downloads",
                              subtitle:
                                  "Maximum number of attachments to download simultaneously (${SettingsSvc.settings.maxConcurrentDownloads.value})",
                              backgroundColor: tileColor,
                            )),
                        Obx(() => SettingsSlider(
                              startingVal: SettingsSvc.settings.maxConcurrentDownloads.value.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              formatValue: (val) => "${val.toInt()}",
                              update: (val) => SettingsSvc.settings.maxConcurrentDownloads.value = val.toInt(),
                              onChangeEnd: (val) async {
                                await SettingsSvc.settings.saveOneAsync('maxConcurrentDownloads');
                              },
                            )),
                      ],
                    ),
                    if (!kIsWeb && !kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.autoSave.value = val;
                              await SettingsSvc.settings.saveOneAsync('autoSave');
                            },
                            initialVal: SettingsSvc.settings.autoSave.value,
                            title: "Auto-save Attachments",
                            subtitle: "Automatically saves all attachments to folders selected below",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => SettingsTile(
                              title: "Image Preview Quality",
                              subtitle:
                                  "Adjust quality for image previews (${(SettingsSvc.settings.previewImageQuality.value * 100).toInt()}%)",
                              backgroundColor: tileColor,
                            )),
                        Obx(() => SettingsSlider(
                              startingVal: SettingsSvc.settings.previewImageQuality.value,
                              min: 0.25,
                              max: 1.0,
                              divisions: 15,
                              formatValue: (val) => "${(val * 100).toInt()}%",
                              update: (val) => SettingsSvc.settings.previewImageQuality.value = val,
                              onChangeEnd: (val) async {
                                await SettingsSvc.settings.saveOneAsync('imageQuality');
                              },
                            )),
                      ],
                    ),
                    if (!kIsWeb && !kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsTile(
                            title: "Save Media Location",
                            subtitle: "Saving images and videos to ${SettingsSvc.settings.autoSavePicsLocation.value}",
                            backgroundColor: tileColor,
                            onTap: () async {
                              final TextEditingController pathController = TextEditingController();
                              await showBBDialog(
                                context: context,
                                title: "Enter Relative Path",
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
                                actions: [
                                  BBDialogAction(
                                    text: "Cancel",
                                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                                  ),
                                  BBDialogAction(
                                    text: "OK",
                                    isDefault: true,
                                    onPressed: () async {
                                      if (pathController.text.isEmpty) {
                                        Navigator.of(context, rootNavigator: true).pop();
                                        SettingsSvc.settings.autoSavePicsLocation.value = "Pictures";
                                      } else {
                                        final regex = RegExp(r"^[a-zA-Z0-9-_]+");
                                        if (!regex.hasMatch(pathController.text) || pathController.text.endsWith("/")) {
                                          showSnackbar("Error", "Enter a valid path!");
                                          return;
                                        }
                                        Navigator.of(context, rootNavigator: true).pop();
                                        SettingsSvc.settings.autoSavePicsLocation.value =
                                            "Pictures/${pathController.text}";
                                      }
                                      await SettingsSvc.settings.saveOneAsync('autoSavePicsLocation');
                                    },
                                  ),
                                ],
                              );
                            },
                          )),
                    if (!kIsWeb && !kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsTile(
                            title: "Save Documents Location",
                            subtitle:
                                "Saving documents and videos to ${FilesystemSvc.toDisplayPath(SettingsSvc.settings.autoSaveDocsLocation.value)}",
                            backgroundColor: tileColor,
                            onTap: () async {
                              final savePath = await FilePicker.getDirectoryPath(
                                initialDirectory: SettingsSvc.settings.autoSaveDocsLocation.value,
                                dialogTitle: 'Choose a location to auto-save documents',
                                lockParentWindow: true,
                              );
                              if (savePath != null) {
                                SettingsSvc.settings.autoSaveDocsLocation.value = savePath;
                                await SettingsSvc.settings.saveOneAsync('autoSaveDocsLocation');
                              }
                            },
                          )),
                    if (!kIsWeb && !kIsDesktop) const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) async {
                              SettingsSvc.settings.askWhereToSave.value = val;
                              await SettingsSvc.settings.saveOneAsync('askWhereToSave');
                            },
                            initialVal: SettingsSvc.settings.askWhereToSave.value,
                            title: "Ask Where to Save Attachments",
                            subtitle: "Ask where to save attachments when manually downloading",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
                SettingsHeader(
                    iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Multi-Attachment Layout"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: SettingsSubtitle(
                        subtitle: "Choose how multiple images and videos are arranged in conversations",
                      ),
                    ),
                    if (iOS)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text("2–3 Items", style: context.theme.textTheme.bodyLarge),
                      ),
                    Obx(() => SettingsOptions<MediaCollectionLayout>(
                          initial: SettingsSvc.settings.mediaCollectionLayoutSmall.value,
                          onChanged: (val) async {
                            if (val == null) return;
                            SettingsSvc.settings.mediaCollectionLayoutSmall.value = val;
                            await SettingsSvc.settings.saveOneAsync('mediaCollectionLayoutSmall');
                          },
                          options: MediaCollectionLayout.values,
                          textProcessing: (val) => switch (val) {
                            MediaCollectionLayout.skinDefault => "Default",
                            MediaCollectionLayout.collage => "Collage",
                            MediaCollectionLayout.stack => "Stack",
                            MediaCollectionLayout.grid => "Grid",
                          },
                          capitalize: false,
                          title: "2–3 Items",
                          secondaryColor: headerColor,
                        )),
                    const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                    if (iOS)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text("4+ Items", style: context.theme.textTheme.bodyLarge),
                      ),
                    Obx(() => SettingsOptions<MediaCollectionLayout>(
                          initial: SettingsSvc.settings.mediaCollectionLayoutLarge.value,
                          onChanged: (val) async {
                            if (val == null) return;
                            SettingsSvc.settings.mediaCollectionLayoutLarge.value = val;
                            await SettingsSvc.settings.saveOneAsync('mediaCollectionLayoutLarge');
                          },
                          options: MediaCollectionLayout.values,
                          textProcessing: (val) => switch (val) {
                            MediaCollectionLayout.skinDefault => "Default",
                            MediaCollectionLayout.collage => "Collage",
                            MediaCollectionLayout.stack => "Stack",
                            MediaCollectionLayout.grid => "Grid",
                          },
                          capitalize: false,
                          title: "4+ Items",
                          secondaryColor: headerColor,
                        )),
                  ],
                ),
                SettingsHeader(
                    iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Video Mute Behavior"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => SettingsSwitch(
                              onChanged: (bool val) async {
                                SettingsSvc.settings.startVideosMuted.value = val;
                                await SettingsSvc.settings.saveOneAsync('startVideosMuted');
                              },
                              initialVal: SettingsSvc.settings.startVideosMuted.value,
                              title: "Mute in Attachment Preview",
                              subtitle: "Videos start muted in the message view",
                              backgroundColor: tileColor,
                            )),
                        const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                        Obx(() => SettingsSwitch(
                              onChanged: (bool val) async {
                                SettingsSvc.settings.startVideosMutedFullscreen.value = val;
                                await SettingsSvc.settings.saveOneAsync('startVideosMutedFullscreen');
                              },
                              initialVal: SettingsSvc.settings.startVideosMutedFullscreen.value,
                              title: "Mute in Fullscreen Player",
                              subtitle: "Videos start muted in the fullscreen viewer",
                              backgroundColor: tileColor,
                            )),
                      ],
                    ),
                  ],
                ),
                if (!kIsWeb)
                  SettingsHeader(
                      iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Attachment Viewer"),
                if (!kIsWeb)
                  Obx(() => SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      if (iOS)
                        SettingsTile(
                          title: kIsDesktop ? "Arrow key direction" : "Swipe direction",
                          subtitle:
                              "Set the ${kIsDesktop ? "arrow key" : "swipe direction"} to go to previous media items",
                        ),
                      SettingsOptions<SwipeDirection>(
                        initial: SettingsSvc.settings.fullscreenViewerSwipeDir.value,
                        onChanged: (val) async {
                          if (val == null) return;
                          SettingsSvc.settings.fullscreenViewerSwipeDir.value = val;
                          await SettingsSvc.settings.saveOneAsync('fullscreenViewerSwipeDir');
                        },
                        options: SwipeDirection.values,
                        textProcessing: (val) => val.toString().split(".").last,
                        capitalize: false,
                        title: "Swipe Direction",
                        subtitle: "Set the swipe direction to go to previous media items",
                        secondaryColor: headerColor,
                        useModernMenu: true,
                      ),
                    ],
                  )),
              ],
            ),
          ),
        ]);
  }
}
