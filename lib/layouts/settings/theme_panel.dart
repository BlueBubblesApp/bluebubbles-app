import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_color_panel.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

class ThemePanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ThemePanelController>(() => ThemePanelController());
  }
}

class ThemePanelController extends GetxController {
  late Settings _settingsCopy;
  final RxList<DisplayMode> modes = <DisplayMode>[].obs;
  final RxList<int> refreshRates = <int>[].obs;
  final RxInt currentMode = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  void onReady() async {
    if (!kIsWeb && !kIsDesktop) {
      modes.value = await FlutterDisplayMode.supported;
      refreshRates.value = modes.map((e) => e.refreshRate.round()).toSet().toList();
      currentMode.value = (await _settingsCopy.getDisplayMode()).refreshRate.round();
    }
    super.onReady();
  }

  @override
  void dispose() async {
    await SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class ThemePanel extends GetView<ThemePanelController> {
  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => Icon(
          SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
          color: Colors.grey,
        ));

    /// for some reason we need a [GetBuilder] here otherwise the theme switching refuses to work right
    return GetBuilder<ThemePanelController>(builder: (_) {
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
        title: "Theming & Styles",
        initialHeader: "Appearance",
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
                    SettingsOptions<AdaptiveThemeMode>(
                      initial: AdaptiveTheme.of(context).mode,
                      onChanged: (val) {
                        if (val == null) return;
                        AdaptiveTheme.of(context).setThemeMode(val);
                        controller.update();
                        EventDispatcher().emit('theme-update', null);
                      },
                      options: AdaptiveThemeMode.values,
                      textProcessing: (val) => val.toString().split(".").last,
                      title: "App Theme",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
                    ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Theming",
                        subtitle: "Edit existing themes and create custom themes",
                        trailing: nextIcon,
                        onTap: () async {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => ThemingPanel(),
                            ),
                          );
                        },
                        backgroundColor: tileColor,
                      ),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Skin and Layout"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsOptions<Skins>(
                      initial: controller._settingsCopy.skin.value,
                      onChanged: (val) {
                        if (val == null) return;
                        controller._settingsCopy.skin.value = val;
                        if (val == Skins.Material) {
                          controller._settingsCopy.hideDividers.value = true;
                        } else if (val == Skins.Samsung) {
                          controller._settingsCopy.hideDividers.value = true;
                        } else {
                          controller._settingsCopy.hideDividers.value = false;
                        }
                        ChatBloc().refreshChats();
                        saveSettings();
                        controller.update();
                      },
                      options: Skins.values.toList(),
                      textProcessing: (val) => val.toString().split(".").last,
                      capitalize: false,
                      title: "App Skin",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
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
                        controller._settingsCopy.tabletMode.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.tabletMode.value,
                      title: "Tablet Mode",
                      backgroundColor: tileColor,
                      subtitle: "Enables tablet mode (split view) depending on screen width",
                    )),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Colors"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    if (!kIsWeb && !kIsDesktop)
                      Obx(
                            () => SettingsSwitch(
                          onChanged: (bool val) async {
                            await MethodChannelInterface().invokeMethod("request-notif-permission");
                            try {
                              await MethodChannelInterface().invokeMethod("start-notif-listener");
                              if (val) {
                                var allThemes = await ThemeObject.getThemes();
                                var currentLight = await ThemeObject.getLightTheme();
                                var currentDark = await ThemeObject.getDarkTheme();
                                currentLight.previousLightTheme = true;
                                currentDark.previousDarkTheme = true;
                                await currentLight.save();
                                await currentDark.save();
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme (Light)"),
                                    selectedDarkTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme (Dark)"));
                              } else {
                                var allThemes = await ThemeObject.getThemes();
                                var previousLight = allThemes.firstWhere((e) => e.previousLightTheme);
                                var previousDark = allThemes.firstWhere((e) => e.previousDarkTheme);
                                previousLight.previousLightTheme = false;
                                previousDark.previousDarkTheme = false;
                                await previousLight.save();
                                await previousDark.save();
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme: previousLight, selectedDarkTheme: previousDark);
                              }
                              controller._settingsCopy.colorsFromMedia.value = val;
                              saveSettings();
                            } catch (e) {
                              showSnackbar(
                                  "Error", "Something went wrong, please ensure you granted the permission correctly!");
                            }
                          },
                          initialVal: controller._settingsCopy.colorsFromMedia.value,
                          title: "Colors from Media",
                          backgroundColor: tileColor,
                          subtitle:
                          "Pull app colors from currently playing media. Note: Requires full notification access & a custom theme to be set",
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.colorfulAvatars.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.colorfulAvatars.value,
                      title: "Colorful Avatars",
                      backgroundColor: tileColor,
                      subtitle: "Gives letter avatars a splash of color",
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
                        controller._settingsCopy.colorfulBubbles.value = val;
                        saveSettings();
                      },
                      initialVal: controller._settingsCopy.colorfulBubbles.value,
                      title: "Colorful Bubbles",
                      backgroundColor: tileColor,
                      subtitle: "Gives received message bubbles a splash of color",
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
                      SettingsTile(
                        title: "Custom Avatar Colors",
                        trailing: nextIcon,
                        onTap: () async {
                          CustomNavigator.pushSettings(
                            context,
                            CustomAvatarColorPanel(),
                            binding: CustomAvatarColorPanelBinding(),
                          );
                        },
                        backgroundColor: tileColor,
                        subtitle: "Customize the color for different avatars",
                      ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Custom Avatars",
                        trailing: nextIcon,
                        onTap: () async {
                          CustomNavigator.pushSettings(
                            context,
                            CustomAvatarPanel(),
                            binding: CustomAvatarPanelBinding(),
                          );
                        },
                        backgroundColor: tileColor,
                        subtitle: "Customize the avatar for different chats",
                      ),
                  ],
                ),
                if (!kIsWeb && !kIsDesktop)
                  Obx(() {
                    if (controller.refreshRates.length > 2) {
                      return SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Refresh Rate");
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                if (!kIsWeb && !kIsDesktop)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        if (controller.refreshRates.length > 2) {
                          return SettingsOptions<int>(
                            initial: controller.currentMode.value,
                            onChanged: (val) async {
                              if (val == null) return;
                              controller.currentMode.value = val;
                              controller._settingsCopy.refreshRate.value = controller.currentMode.value;
                              saveSettings();
                            },
                            options: controller.refreshRates,
                            textProcessing: (val) => val == 0 ? "Auto" : val.toString() + " Hz",
                            title: "Display",
                            backgroundColor: tileColor,
                            secondaryColor: headerColor,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                // SettingsOptions<String>(
                //   initial: controller._settingsCopy.emojiFontFamily == null
                //       ? "System"
                //       : fontFamilyToString[controller._settingsCopy.emojiFontFamily],
                //   onChanged: (val) {
                //     controller._settingsCopy.emojiFontFamily = stringToFontFamily[val];
                //   },
                //   options: stringToFontFamily.keys.toList(),
                //   textProcessing: (dynamic val) => val,
                //   title: "Emoji Style",
                //   showDivider: false,
                // ),
              ],
            ),
          ),
        ]
      );
    });
  }

  void saveSettings() {
    SettingsManager().saveSettings(controller._settingsCopy);
  }
}
