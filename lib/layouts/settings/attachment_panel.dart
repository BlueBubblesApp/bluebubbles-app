import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttachmentPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

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
                            SettingsManager().settings.autoDownload.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.autoDownload.value,
                          title: "Auto-download Attachments",
                          subtitle:
                              "Automatically downloads new attachments from the server and caches them internally",
                          backgroundColor: tileColor,
                          isThreeLine: true,
                        )),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) {
                            SettingsManager().settings.onlyWifiDownload.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.onlyWifiDownload.value,
                          title: "Only Auto-download Attachments on WiFi",
                          backgroundColor: tileColor,
                        )),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              SettingsManager().settings.autoSave.value = val;
                              saveSettings();
                            },
                            initialVal: SettingsManager().settings.autoSave.value,
                            title: "Auto-save Attachments",
                            subtitle: "Automatically saves all attachments to gallery or downloads folder",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              SettingsManager().settings.askWhereToSave.value = val;
                              saveSettings();
                            },
                            initialVal: SettingsManager().settings.askWhereToSave.value,
                            title: "Ask Where to Save Attachments",
                            subtitle: "Ask where to save attachments when manually downloading",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          )),
                  ],
                ),
                if (!kIsDesktop)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Video Mute Behavior"),
                if (!kIsDesktop)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              SettingsManager().settings.startVideosMuted.value = val;
                              saveSettings();
                            },
                            initialVal: SettingsManager().settings.startVideosMuted.value,
                            title: "Mute Videos by Default in Attachment Preview",
                            backgroundColor: tileColor,
                          )),
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              SettingsManager().settings.startVideosMutedFullscreen.value = val;
                              saveSettings();
                            },
                            initialVal: SettingsManager().settings.startVideosMutedFullscreen.value,
                            title: "Mute Videos by Default in Fullscreen Player",
                            backgroundColor: tileColor,
                          )),
                    ],
                  ),
                if (!kIsWeb)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Attachment Preview Quality"),
                if (!kIsWeb)
                  SettingsSection(backgroundColor: tileColor, children: [
                    if (!kIsWeb)
                      Obx(() => SettingsSlider(
                          startingVal: SettingsManager().settings.previewCompressionQuality.value.toDouble(),
                          update: (double val) {
                            SettingsManager().settings.previewCompressionQuality.value = val.toInt();
                          },
                          onChangeEnd: (double val) {
                            saveSettings();
                          },
                          formatValue: ((double val) => "${val.toInt()}%"),
                          backgroundColor: tileColor,
                          leading: Obx(() => Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: (1 - SettingsManager().settings.previewCompressionQuality.value / 100),
                                        sigmaY: (1 - SettingsManager().settings.previewCompressionQuality.value / 100),
                                      ),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: SettingsManager().settings.skin.value == Skins.iOS
                                              ? Colors.grey
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                            SettingsManager().settings.skin.value == Skins.iOS
                                                ? CupertinoIcons.sparkles
                                                : Icons.auto_awesome,
                                            color: SettingsManager().settings.skin.value == Skins.iOS
                                                ? Colors.white
                                                : Colors.grey,
                                            size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                          min: 10,
                          max: 100,
                          divisions: 18)),
                    if (!kIsWeb)
                      SettingsSubtitle(
                        subtitle: "Controls the resolution of attachment previews in the message screen. A higher value will make attachments show in better quality at the cost of longer load times.",
                        unlimitedSpace: true,
                      ),
                  ]),
                if (!kIsWeb)
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Attachment Viewer"),
                if (!kIsWeb)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        if (SettingsManager().settings.skin.value == Skins.iOS) {
                          return SettingsTile(
                            title: kIsDesktop ? "Arrow key direction" : "Swipe direction",
                            subtitle:
                                "Set the ${kIsDesktop ? "arrow key" : "swipe direction"} to go to previous media items",
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                      Obx(() => SettingsOptions<SwipeDirection>(
                            initial: SettingsManager().settings.fullscreenViewerSwipeDir.value,
                            onChanged: (val) {
                              if (val == null) return;
                              SettingsManager().settings.fullscreenViewerSwipeDir.value = val;
                              saveSettings();
                            },
                            options: SwipeDirection.values,
                            textProcessing: (val) => val.toString().split(".").last,
                            capitalize: false,
                            title: "Swipe Direction",
                            subtitle: "Set the swipe direction to go to previous media items",
                            backgroundColor: tileColor,
                            secondaryColor: headerColor,
                          )),
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
                    if (!kIsWeb)
                      Obx(() => SettingsSwitch(
                            onChanged: (bool val) {
                              SettingsManager().settings.preCachePreviewImages.value = val;
                              saveSettings();
                            },
                            initialVal: SettingsManager().settings.preCachePreviewImages.value,
                            title: "Cache Preview Images",
                            subtitle: "Caches URL preview images for faster load times",
                            backgroundColor: tileColor,
                          )),
                  ],
                ),
              ],
            ),
          ),
        ]);
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
