import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/window_effects.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_color_panel.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_cached_fonts/dynamic_cached_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart' hide Response;
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:universal_io/io.dart';

class ThemePanelController extends GetxController {
  late Settings _settingsCopy;
  final RxList<DisplayMode> modes = <DisplayMode>[].obs;
  final RxList<int> refreshRates = <int>[].obs;
  final RxInt currentMode = 0.obs;
  final RxnBool gettingIcons = RxnBool();

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

class ThemePanel extends StatelessWidget {
  final controller = Get.put(ThemePanelController());

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => SettingsManager().settings.skin.value != Skins.Material ? Icon(
      SettingsManager().settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: SettingsManager().settings.skin.value == Skins.iOS ? 18 : 24,
    ) : SizedBox.shrink());

    /// for some reason we need a [GetBuilder] here otherwise the theme switching refuses to work right
    return GetBuilder<ThemePanelController>(builder: (_) {
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

      // These Rx variables are only needed in widgets not contained in settings_widgets.dart
      final Rx<Color> _headerColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent).obs;
      final Rx<Color> _tileColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? tileColor : Colors.transparent).obs;

      if (kIsDesktop) {
        SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
          _headerColor.value = effect != WindowEffect.disabled ? Colors.transparent : headerColor;
          _tileColor.value = effect != WindowEffect.disabled ? Colors.transparent : tileColor;
        });
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
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                      ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    Obx(() => Container(
                      decoration: BoxDecoration(
                        color: _tileColor.value,
                      ),
                      padding: EdgeInsets.only(left: 15, top: 10),
                      child: Text("Avatar Scale Factor", style: context.theme.textTheme.bodyLarge),
                    )),
                    Obx(() => SettingsSlider(
                        startingVal: SettingsManager().settings.avatarScale.value.toDouble(),
                        update: (double val) {
                          SettingsManager().settings.avatarScale.value = val;
                        },
                        onChangeEnd: (double val) {
                          saveSettings();
                        },
                        formatValue: ((double val) => val.toPrecision(2).toString()),
                        backgroundColor: tileColor,
                        min: 0.8,
                        max: 1.2,
                        divisions: 4
                    )),
                  ],
                ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Skin${kIsDesktop ? "" : " and Layout"}"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsOptions<Skins>(
                      initial: controller._settingsCopy.skin.value,
                      onChanged: (val) {
                        if (val == null) return;
                        controller._settingsCopy.skin.value = val;
                        ChatBloc().refreshChats();
                        saveSettings();
                        controller.update();
                        EventDispatcher().emit('theme-update', null);
                      },
                      options: Skins.values,
                      textProcessing: (val) {
                        var output = val.toString().split(".").last;
                        return output == 'Samsung' ? 'Samsung (β)' : output;
                      },
                      capitalize: false,
                      title: "App Skin",
                      backgroundColor: tileColor,
                      secondaryColor: headerColor,
                    )),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    if (!kIsDesktop)
                      Obx(() => SettingsSwitch(
                        onChanged: (bool val) {
                          controller._settingsCopy.tabletMode.value = val;
                          saveSettings();
                        },
                        initialVal: controller._settingsCopy.tabletMode.value,
                        title: "Tablet Mode",
                        backgroundColor: tileColor,
                        subtitle: "Enables tablet mode (split view) depending on screen width",
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
                          controller._settingsCopy.immersiveMode.value = val;
                          saveSettings();
                          if (val) {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                          } else {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
                          }
                          EventDispatcher().emit('theme-update', null);
                        },
                        initialVal: controller._settingsCopy.immersiveMode.value,
                        title: "Immersive Mode",
                        backgroundColor: tileColor,
                        subtitle: "Makes the bottom navigation bar transparent. This option is best used with gesture navigation.",
                        isThreeLine: true,
                      )),
                    if (!kIsWeb && !kIsDesktop)
                      SettingsSubtitle(
                        subtitle: "Note: This option may cause slight choppiness in some animations due to an Android limitation.",
                      ),
                  ],
                ),
                if (kIsDesktop && Platform.isWindows)
                  SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Window Effect",
                  ),
                if (kIsDesktop && Platform.isWindows)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() => SettingsOptions<WindowEffect>(
                          initial: SettingsManager().settings.windowEffect.value,
                          options: WindowEffects.effects,
                          textProcessing: (WindowEffect effect) => effect.toString().substring("WindowEffect.".length),
                          onChanged: (WindowEffect? effect) async {
                            bool defaultOpacityLight = SettingsManager().settings.windowEffectCustomOpacityLight.value == WindowEffects.defaultOpacity(dark: false);
                            bool defaultOpacityDark = SettingsManager().settings.windowEffectCustomOpacityDark.value == WindowEffects.defaultOpacity(dark: true);
                            effect ??= WindowEffect.disabled;
                            SettingsManager().settings.windowEffect.value = effect;
                            if (defaultOpacityLight) {
                              SettingsManager().settings.windowEffectCustomOpacityLight.value = WindowEffects.defaultOpacity(dark: false);
                            }
                            if (defaultOpacityDark) {
                              SettingsManager().settings.windowEffectCustomOpacityDark.value = WindowEffects.defaultOpacity(dark: true);
                            }
                            prefs.setString('window-effect', effect.toString());
                            await WindowEffects.setEffect(color: context.theme.backgroundColor);
                            saveSettings();
                          },
                          title: "Window Effect",
                          subtitle: "${WindowEffects.descriptions[SettingsManager().settings.windowEffect.value]}\n\nOperating System Version: ${Platform.operatingSystemVersion}\nBuild number: ${parsedWindowsVersion()}",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                          capitalize: true,
                        ),
                      ),
                      if (SettingsManager().settings.skin.value == Skins.iOS)
                        Obx(() => SettingsSubtitle(
                              unlimitedSpace: true,
                              subtitle:
                                  "${WindowEffects.descriptions[SettingsManager().settings.windowEffect.value]}\n\nOperating System Version: ${Platform.operatingSystemVersion}\nBuild number: ${parsedWindowsVersion()}",
                            )),
                      Obx(() {
                        if (WindowEffects.dependsOnColor() && !WindowEffects.isDark(color: context.theme.backgroundColor)) {
                          return SettingsTile(
                            title: "Background Opacity (Light)",
                            trailing: SettingsManager().settings.windowEffectCustomOpacityLight.value != WindowEffects.defaultOpacity(dark: false) ? ElevatedButton(
                              onPressed: () {
                                SettingsManager().settings.windowEffectCustomOpacityLight.value = WindowEffects.defaultOpacity(dark: false);
                                saveSettings();
                              },
                              child: Text("Reset to Default"),
                            ) : null,
                          );
                        }
                        return SizedBox.shrink();
                      }),
                      Obx(() {
                        if (WindowEffects.dependsOnColor() && !WindowEffects.isDark(color: context.theme.backgroundColor)) {
                          return SettingsSlider(
                            startingVal: SettingsManager().settings.windowEffectCustomOpacityLight.value,
                            max: 1,
                            min: 0,
                            divisions: 100,
                            formatValue: (value) => value.toStringAsFixed(2),
                            update: (value) => SettingsManager().settings.windowEffectCustomOpacityLight.value = value,
                            onChangeEnd: (value) {
                              saveSettings();
                            },
                          );
                        }
                        return SizedBox.shrink();
                      }),
                      Obx(() {
                        if (WindowEffects.dependsOnColor() && WindowEffects.isDark(color: context.theme.backgroundColor)) {
                          return SettingsTile(
                            title: "Background Opacity (Dark)",
                            trailing: SettingsManager().settings.windowEffectCustomOpacityDark.value != WindowEffects.defaultOpacity(dark: true) ? ElevatedButton(
                              onPressed: () {
                                SettingsManager().settings.windowEffectCustomOpacityDark.value = WindowEffects.defaultOpacity(dark: true);
                                saveSettings();
                              },
                              child: Text("Reset to Default"),
                            ) : null,
                          );
                        }
                        return SizedBox.shrink();
                      }),
                      Obx(() {
                        if (WindowEffects.dependsOnColor() && WindowEffects.isDark(color: context.theme.backgroundColor)) {
                          return SettingsSlider(
                            startingVal: SettingsManager().settings.windowEffectCustomOpacityDark.value,
                            max: 1,
                            min: 0,
                            divisions: 100,
                            formatValue: (value) => value.toStringAsFixed(2),
                            update: (value) => SettingsManager().settings.windowEffectCustomOpacityDark.value = value,
                            onChangeEnd: (value) {
                              saveSettings();
                            },
                          );
                        }
                        return SizedBox.shrink();
                      }),
                    ]
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
                    if (kIsDesktop && Platform.isWindows)
                      Obx(() => SettingsSwitch(
                        initialVal: SettingsManager().settings.useWindowsAccent.value,
                        backgroundColor: tileColor,
                        title: "Use Windows Accent Color",
                        subtitle: "Apply the Windows accent color to your theme",
                        onChanged: (value) async {
                          if (value) {
                            windowsAccentColor = await DynamicColorPlugin.getAccentColor();
                          }
                          SettingsManager().settings.useWindowsAccent.value = value;
                          saveSettings();
                          loadTheme(context);
                        },
                      )),
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      Obx(() {
                        if (SettingsManager().settings.skin.value == Skins.iOS) {
                          return SettingsTile(
                            title: "Material You",
                            subtitle:
                            "Use Android 12's Monet engine to provide wallpaper-based coloring to your theme. Tap for more info.",
                            onTap: () {
                              showMonetDialog(context);
                            },
                            isThreeLine: true,
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      }),
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      GestureDetector(
                        onTap: () {
                          showMonetDialog(context);
                        },
                        child: SettingsOptions<Monet>(
                          initial: controller._settingsCopy.monetTheming.value,
                          onChanged: (val) {
                            // disable colors from music
                            final currentTheme = ThemeStruct.getLightTheme();
                            if (currentTheme.name == "Music Theme ☀" ||
                                currentTheme.name == "Music Theme 🌙") {
                              SettingsManager().settings.colorsFromMedia.value = false;
                              SettingsManager().saveSettings(SettingsManager().settings);
                              ThemeStruct previousDark = revertToPreviousDarkTheme();
                              ThemeStruct previousLight = revertToPreviousLightTheme();
                              SettingsManager().saveSelectedTheme(context,
                                  selectedLightTheme: previousLight, selectedDarkTheme: previousDark);
                            }
                            controller._settingsCopy.monetTheming.value = val ?? Monet.none;
                            saveSettings();
                            loadTheme(context);
                          },
                          options: Monet.values,
                          textProcessing: (val) => val.toString().split(".").last,
                          title: "Material You",
                          subtitle:
                          "Use Android 12's Monet engine to provide wallpaper-based coloring to your theme. Tap for more info.",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop && monetPalette != null)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Obx(
                            () => SettingsSwitch(
                          onChanged: (bool val) async {
                            await MethodChannelInterface().invokeMethod("request-notif-permission");
                            if (val) {
                              try {
                                await MethodChannelInterface().invokeMethod("start-notif-listener");
                                // disable monet theming if music theme enabled
                                controller._settingsCopy.monetTheming.value = Monet.none;
                                saveSettings();
                                var allThemes = ThemeStruct.getThemes();
                                var currentLight = ThemeStruct.getLightTheme();
                                var currentDark = ThemeStruct.getDarkTheme();
                                prefs.setString("previous-light", currentLight.name);
                                prefs.setString("previous-dark", currentDark.name);
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme ☀"),
                                    selectedDarkTheme:
                                    allThemes.firstWhere((element) => element.name == "Music Theme 🌙"));
                                controller._settingsCopy.colorsFromMedia.value = val;
                                saveSettings();
                              } catch (e) {
                                showSnackbar(
                                    "Error", "Something went wrong, please ensure you granted the permission correctly!");
                              }
                            } else {
                              var allThemes = ThemeStruct.getThemes();
                              final lightName = prefs.getString("previous-light");
                              final darkName = prefs.getString("previous-dark");
                              var previousLight = allThemes.firstWhere((e) => e.name == lightName);
                              var previousDark = allThemes.firstWhere((e) => e.name == darkName);
                              prefs.remove("previous-light");
                              prefs.remove("previous-dark");
                              SettingsManager().saveSelectedTheme(context,
                                  selectedLightTheme: previousLight, selectedDarkTheme: previousDark);
                              controller._settingsCopy.colorsFromMedia.value = val;
                              saveSettings();
                            }
                          },
                          initialVal: controller._settingsCopy.colorsFromMedia.value,
                          title: "Colors from Media",
                          backgroundColor: tileColor,
                          subtitle:
                          "Pull app colors from currently playing media",
                        ),
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      SettingsSubtitle(
                        subtitle: "Note: Requires full notification access. Enabling this option will set a custom Music Theme as the selected theme.",
                      ),
                    if (!kIsWeb && !kIsDesktop)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                          );
                        },
                        subtitle: "Customize the color for different avatars",
                      ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
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
                          );
                        },
                        subtitle: "Customize the avatar for different chats",
                      ),
                    if (!kIsWeb)
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    if (!kIsWeb)
                      SettingsTile(
                        title: "Sync Group Chat Icons",
                        trailing: Obx(() => controller.gettingIcons.value == null
                            ? SizedBox.shrink()
                            : controller.gettingIcons.value == true ? Container(
                            constraints: BoxConstraints(
                              maxHeight: 20,
                              maxWidth: 20,
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                            )) : Icon(Icons.check, color: context.theme.colorScheme.outline)
                        ),
                        onTap: () async {
                          controller.gettingIcons.value = true;
                          for (Chat c in ChatBloc().chats.where((c) => c.isGroup())) {
                            final response = await api.getChatIcon(c.guid).catchError((err) async {
                              Logger.error("Failed to get chat icon for chat ${c.getTitle()}");
                              return Response(statusCode: 500, requestOptions: RequestOptions(path: ""));
                            });
                            if (response.statusCode != 200 || isNullOrEmpty(response.data)!) continue;
                            Logger.debug("Got chat icon for chat ${c.getTitle()}");
                            File file = File(c.customAvatarPath ?? "${SettingsManager().appDocDir.path}/avatars/${c.guid.characters.where((char) => char.isAlphabetOnly || char.isNumericOnly).join()}/avatar.jpg");
                            if (c.customAvatarPath == null) {
                              await file.create(recursive: true);
                            }
                            await file.writeAsBytes(response.data);
                            c.customAvatarPath = file.path;
                            c.save(updateCustomAvatarPath: true);
                          }
                          controller.gettingIcons.value = false;
                        },
                        subtitle: "Get iMessage group chat icons from the server",
                      ),
                    if (!kIsWeb)
                      SettingsSubtitle(
                        subtitle: "Note: Overrides any custom avatars set for group chats.",
                      ),
                  ],
                ),
                if (!kIsWeb && !kIsDesktop && controller.refreshRates.length > 2)
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
                if (!kIsWeb && !kIsDesktop && controller.refreshRates.length > 2)
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      Obx(() {
                        return SettingsOptions<int>(
                          initial: controller.currentMode.value,
                          onChanged: (val) async {
                            if (val == null) return;
                            controller.currentMode.value = val;
                            controller._settingsCopy.refreshRate.value = controller.currentMode.value;
                            saveSettings();
                          },
                          options: controller.refreshRates,
                          textProcessing: (val) => val == 0 ? "Auto" : "$val Hz",
                          title: "Display",
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        );
                      }),
                    ],
                  ),
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Text and Font"),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() {
                      if (!fontExistsOnDisk.value) {
                        return SettingsTile(
                          onTap: () async {
                            if (kIsWeb) {
                              final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["ttf"]);
                              if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                              final txn = db.transaction("BBStore", idbModeReadWrite);
                              final store = txn.objectStore("BBStore");
                              await store.put(res.files.first.bytes!, "iosFont");
                              await txn.completed;

                              final fontLoader = FontLoader("Apple Color Emoji");
                              final cachedFontBytes = ByteData.view(res.files.first.bytes!.buffer);
                              fontLoader.addFont(
                                Future<ByteData>.value(cachedFontBytes),
                              );
                              await fontLoader.load();
                              fontExistsOnDisk.value = true;
                              return showSnackbar("Notice", "Font loaded");
                            }

                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                title: Text("Downloading font file...", style: context.theme.textTheme.titleLarge),
                                content: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Obx(
                                            () => Text(
                                            '${progress.value != null && totalSize.value != null ? getSizeString(progress.value! * totalSize.value! / 1000) : ""} / ${getSizeString((totalSize.value ?? 0).toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)',
                                              style: context.theme.textTheme.bodyLarge),
                                      ),
                                      SizedBox(height: 10.0),
                                      Obx(
                                            () => ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: LinearProgressIndicator(
                                            backgroundColor: context.theme.colorScheme.outline,
                                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                            value: progress.value,
                                            minHeight: 5,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 15.0,
                                      ),
                                      Obx(() => Text(
                                        progress.value == 1 ? "Download Complete!" : "You can close this dialog. The font will continue to download in the background.",
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: context.theme.textTheme.bodyLarge,
                                      )),
                                ]),
                                actions: [
                                  Obx(() => downloadingFont.value
                                      ? Container(height: 0, width: 0)
                                      : TextButton(
                                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      if (Get.isSnackbarOpen ?? false) {
                                        Get.close(1);
                                      }
                                      Navigator.of(context).pop();
                                      Future.delayed(Duration(milliseconds: 400), ()
                                      {
                                        progress.value = null;
                                        totalSize.value = null;
                                      });
                                    },
                                  ),
                                  ),
                                ],
                              ),
                            );
                            final DynamicCachedFonts dynamicCachedFont = DynamicCachedFonts(
                              fontFamily: "Apple Color Emoji",
                              url:
                              "https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf",
                            );
                            dynamicCachedFont.load().listen((data) {
                              if (data is FileInfo) {
                                fontExistsOnDisk.value = true;
                                showSnackbar("Notice", "Font loaded");
                              } else if (data is DownloadProgress) {
                                downloadingFont.value = true;
                                progress.value = data.progress;
                                totalSize.value = data.totalSize;
                                if (progress.value == 1.0) {
                                  downloadingFont.value = false;
                                }
                              }
                            });
                          },
                          title:
                          kIsWeb ? "Upload Font File" : "Download${downloadingFont.value ? "ing" : ""} iOS Emoji Font${downloadingFont.value ? " (${progress.value != null && totalSize.value != null ? getSizeString(progress.value! * totalSize.value! / 1000) : ""} / ${getSizeString((totalSize.value ?? 0).toDouble() / 1000)}) (${((progress.value ?? 0) * 100).floor()}%)" : ""}",
                          subtitle: "Upload your ttf emoji file into BlueBubbles",
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                    Obx(() {
                      if (fontExistsOnDisk.value) {
                        return SettingsTile(
                          onTap: () async {
                            if (kIsWeb) {
                              IdbFactory? idbFactory = getIdbFactory();
                              final db = await idbFactory?.open("BlueBubbles", version: 1, onUpgradeNeeded: (VersionChangeEvent event) {});
                              final txn = db?.transaction("BlueBubbles", "readwrite");
                              final store = txn?.objectStore("BlueBubbles");
                              await store?.delete("iosFont");
                              await txn?.completed;
                            } else {
                              await DynamicCachedFonts.removeCachedFont("https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf");
                            }
                            fontExistsOnDisk.value = false;
                            showSnackbar("Notice", "Font removed, restart the app for changes to take effect");
                          },
                          title: "Delete iOS Emoji Font",
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    }),
                  ],
                ),
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

  void showMonetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Monet Theming Info", style: context.theme.textTheme.titleLarge),
        backgroundColor: context.theme.colorScheme.properSurface,
        content: Text(
            "Harmonize - Overwrites primary color, and blends background & accent color with the current theme colors\r\n"
                "Full - Overwrites primary, background, and accent colors, along with other minor colors.\r\n",
          style: context.theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      )
    );
  }
}
