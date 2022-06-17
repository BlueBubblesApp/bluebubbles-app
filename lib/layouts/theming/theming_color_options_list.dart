import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/theming/theming_color_selector.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class ThemingColorOptionsList extends StatefulWidget {
  ThemingColorOptionsList({Key? key, required this.isDarkMode, required this.controller}) : super(key: key);
  final bool isDarkMode;
  final StreamController controller;

  @override
  State<ThemingColorOptionsList> createState() => _ThemingColorOptionsListState();
}

class _ThemingColorOptionsListState extends State<ThemingColorOptionsList> {
  late ThemeStruct currentTheme;
  List<ThemeStruct> allThemes = [];
  bool editable = false;

  @override
  void initState() {
    super.initState();
    if (widget.isDarkMode) {
      currentTheme = ThemeStruct.getDarkTheme();
    } else {
      currentTheme = ThemeStruct.getLightTheme();
    }
    allThemes = ThemeStruct.getThemes();

    widget.controller.stream.listen((event) {
      BuildContext _context = context;
      final TextEditingController controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.theme.colorScheme.properSurface,
          actions: [
            TextButton(
              child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () {
                if (ThemeStruct.findOne(controller.text) != null || controller.text.isEmpty) {
                  showSnackbar("Error", "Please use a unique name for your new theme");
                } else {
                  Navigator.of(_context).pop();
                  final tuple = applyMonet(currentTheme.data, currentTheme.data);
                  ThemeData finalData = currentTheme.data;
                  if (widget.isDarkMode) {
                    finalData = tuple.item2;
                  } else {
                    finalData = tuple.item1;
                  }
                  ThemeStruct newTheme = ThemeStruct(themeData: finalData, name: controller.text);
                  allThemes.add(newTheme);
                  currentTheme = newTheme;
                  if (widget.isDarkMode) {
                    SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: currentTheme);
                  } else {
                    SettingsManager().saveSelectedTheme(_context, selectedLightTheme: currentTheme);
                  }
                }
              },
            ),
          ],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      SettingsManager().settings.skin.value == Skins.iOS
                          ? CupertinoIcons.info
                          : Icons.info_outline,
                      size: 20,
                      color: context.theme.colorScheme.primary,
                    ),
                    SizedBox(width: 20),
                    Expanded(
                        child: Text(
                          "Your new theme will copy the colors currently displayed in the advanced theming menu",
                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                        )
                    ),
                  ],
                ),
              ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Theme Name",
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.theme.colorScheme.outline,
                      )),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.theme.colorScheme.primary,
                      )),
                ),
              ),
            ],
          ),
          title: Text("Create a New Theme", style: context.theme.textTheme.titleLarge),
        )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    editable = !currentTheme.isPreset && SettingsManager().settings.monetTheming.value == Monet.none;
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }
    final length = currentTheme.colors(widget.isDarkMode, returnMaterialYou: false).keys.where((e) => e != "outline" && e != "shadow" && e != "inversePrimary").length ~/ 2 + 3;
    return CustomScrollView(
      physics: ThemeSwitcher.getScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: SettingsOptions<ThemeStruct>(
            title: "Selected Theme",
            initial: currentTheme,
            options: allThemes,
            backgroundColor: headerColor,
            secondaryColor: tileColor,
            textProcessing: (struct) => struct.name.toUpperCase(),
            useCupertino: false,
            onChanged: (value) async {
              if (value == null) return;
              value.save();

              if (value.name == "Music Theme (Light)" || value.name == "Music Theme (Dark)") {
                // disable monet theming if music theme enabled
                SettingsManager().settings.monetTheming.value = Monet.none;
                SettingsManager().saveSettings(SettingsManager().settings);
                await MethodChannelInterface().invokeMethod("request-notif-permission");
                try {
                  await MethodChannelInterface().invokeMethod("start-notif-listener");
                  SettingsManager().settings.colorsFromMedia.value = true;
                  SettingsManager().saveSettings(SettingsManager().settings);
                } catch (e) {
                  showSnackbar("Error",
                      "Something went wrong, please ensure you granted the permission correctly!");
                  return;
                }
              } else {
                SettingsManager().settings.colorsFromMedia.value = false;
                SettingsManager().saveSettings(SettingsManager().settings);
              }

              if (value.name == "Music Theme (Light)" || value.name == "Music Theme (Dark)") {
                var allThemes = ThemeStruct.getThemes();
                var currentLight = ThemeStruct.getLightTheme();
                var currentDark = ThemeStruct.getDarkTheme();
                prefs.setString("previous-light", currentLight.name);
                prefs.setString("previous-dark", currentDark.name);
                SettingsManager().saveSelectedTheme(context,
                    selectedLightTheme:
                    allThemes.firstWhere((element) => element.name == "Music Theme (Light)"),
                    selectedDarkTheme:
                    allThemes.firstWhere((element) => element.name == "Music Theme (Dark)"));
              } else if (currentTheme.name == "Music Theme (Light)" ||
                  currentTheme.name == "Music Theme (Dark)") {
                if (!widget.isDarkMode) {
                  ThemeStruct previousDark = revertToPreviousDarkTheme();
                  SettingsManager().saveSelectedTheme(context,
                      selectedLightTheme: value, selectedDarkTheme: previousDark);
                } else {
                  ThemeStruct previousLight = revertToPreviousLightTheme();
                  SettingsManager().saveSelectedTheme(context,
                      selectedLightTheme: previousLight, selectedDarkTheme: value);
                }
              } else if (widget.isDarkMode) {
                SettingsManager().saveSelectedTheme(context, selectedDarkTheme: value);
              } else {
                SettingsManager().saveSelectedTheme(context, selectedLightTheme: value);
              }
              currentTheme = value;
              editable = !currentTheme.isPreset;
              setState(() {});

              EventDispatcher().emit('theme-update', null);
            },
          ),
        ),
        if (!currentTheme.isPreset)
          SliverToBoxAdapter(
              child: SettingsSwitch(
            onChanged: (bool val) async {
              currentTheme.gradientBg = val;
              currentTheme.save();
              if (widget.isDarkMode) {
                SettingsManager().saveSelectedTheme(context, selectedDarkTheme: currentTheme);
              } else {
                SettingsManager().saveSelectedTheme(context, selectedLightTheme: currentTheme);
              }
            },
            initialVal: currentTheme.gradientBg,
            title: "Gradient Message View Background",
            backgroundColor: tileColor,
            subtitle:
                "Make the background of the messages view an animated gradient based on the background and primary colors",
            isThreeLine: true,
          )),
        SliverToBoxAdapter(
          child: SettingsSubtitle(
            subtitle: "Tap to edit the base color, and long press to edit the color for elements displayed on top of the base color",
          )
        ),
        if (SettingsManager().settings.monetTheming.value != Monet.none)
          SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      SettingsManager().settings.skin.value == Skins.iOS
                          ? CupertinoIcons.info
                          : Icons.info_outline,
                      size: 20,
                      color: context.theme.colorScheme.primary,
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Text(
                          "You have Material You theming enabled, so some or all of these colors may be generated by Monet. Disable Material You to view the original theme colors.",
                        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                      )
                    ),
                  ],
                ),
              )
          ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return ThemingColorSelector(
                currentTheme: currentTheme,
                tuple: Tuple2(currentTheme.colors(widget.isDarkMode).entries.toList()[index < length - 3
                    ? index * 2 : currentTheme.colors(widget.isDarkMode).entries.length - (length - index)],
                    index < length - 3 ? currentTheme.colors(widget.isDarkMode).entries.toList()[index * 2 + 1] : null),
                editable: editable,
              );
            },
            childCount: length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kIsDesktop ? (CustomNavigator.width(context) / 150).floor() : 2,
          ),
        ),
        if (!currentTheme.isPreset)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: context.theme.colorScheme.errorContainer,
                ),
                child: Text(
                  "Delete",
                  style: TextStyle(color: context.theme.colorScheme.onErrorContainer),
                ),
                onPressed: () async {
                  allThemes.removeWhere((element) => element == currentTheme);
                  currentTheme.delete();
                  currentTheme =
                    widget.isDarkMode ? revertToPreviousDarkTheme() : revertToPreviousLightTheme();
                  allThemes = ThemeStruct.getThemes();
                  if (widget.isDarkMode) {
                    SettingsManager().saveSelectedTheme(context, selectedDarkTheme: currentTheme);
                  } else {
                    SettingsManager().saveSelectedTheme(context, selectedLightTheme: currentTheme);
                  }
                  setState(() {});
                },
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.all(25),
        ),
      ],
    );
  }
}
