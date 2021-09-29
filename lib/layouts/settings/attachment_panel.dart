import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AttachmentPanel extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Media Settings",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(
                      height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                      alignment: Alignment.bottomLeft,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Auto-download".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.autoDownload.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.autoDownload.value,
                    title: "Auto-download Attachments",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
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
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Video Mute Behavior"
                  ),
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
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
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
                  if (!kIsWeb)
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Attachment Preview Quality"
                    ),
                  if (!kIsWeb)
                    Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                          child: Text(
                            "Controls the resolution of attachment previews in the message screen. A higher value will make attachments show in better quality at the cost of longer load times."
                          ),
                        )
                    ),
                  if (!kIsWeb)
                    Obx(() => SettingsSlider(
                        text: "Attachment Preview Quality",
                        startingVal: SettingsManager().settings.previewCompressionQuality.value.toDouble(),
                        update: (double val) {
                          SettingsManager().settings.previewCompressionQuality.value = val.toInt();
                          saveSettings();
                        },
                        formatValue: ((double val) => val.toInt().toString() + "%"),
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
                                    color: SettingsManager().settings.skin.value == Skins.iOS ?
                                    Colors.grey : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(SettingsManager().settings.skin.value == Skins.iOS
                                      ? CupertinoIcons.sparkles : Icons.auto_awesome,
                                      color: SettingsManager().settings.skin.value == Skins.iOS ?
                                      Colors.white : Colors.grey,
                                      size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )),
                        min: 10,
                        max: 100,
                        divisions: 18
                    )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Attachment Viewer"
                  ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return SettingsTile(
                        backgroundColor: tileColor,
                        title: "Swipe direction",
                        subtitle: "Set the swipe direction to go to previous media items",
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
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Advanced"
                  ),
                  SettingsTile(
                    title: "Attachment Chunk Size",
                    subtitle: "Controls the amount of data the app gets from the server on each network request",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  ),
                  Obx(() => SettingsSlider(
                      text: "Attachment Chunk Size",
                      startingVal: SettingsManager().settings.chunkSize.value.toDouble(),
                      update: (double val) {
                        SettingsManager().settings.chunkSize.value = val.floor();
                        saveSettings();
                      },
                      formatValue: ((double val) => getSizeString(val)),
                      backgroundColor: tileColor,
                      leading: Obx(() => SettingsLeadingIcon(
                        iosIcon: SettingsManager().settings.chunkSize.value < 1000
                            ? CupertinoIcons.square_grid_3x2 : SettingsManager().settings.chunkSize.value < 2000
                            ? CupertinoIcons.square_grid_2x2 : CupertinoIcons.square,
                        materialIcon: SettingsManager().settings.chunkSize.value < 1000
                            ? Icons.photo_size_select_small : SettingsManager().settings.chunkSize.value < 2000
                            ? Icons.photo_size_select_large : Icons.photo_size_select_actual,
                      )),
                      min: 100,
                      max: 3000,
                      divisions: 29
                  )),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
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
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                      color: headerColor,
                      border: Border(
                          top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                      ),
                    ) : null,
                  ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
