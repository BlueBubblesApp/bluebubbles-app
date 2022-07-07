import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/settings/widgets/content/advanced_theming_tile.dart';
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

class AdvancedThemingContent extends StatefulWidget {
  AdvancedThemingContent({Key? key, required this.isDarkMode, required this.controller}) : super(key: key);
  final bool isDarkMode;
  final StreamController controller;

  @override
  State<AdvancedThemingContent> createState() => _AdvancedThemingContentState();
}

class _AdvancedThemingContentState extends State<AdvancedThemingContent> {
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
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }
    final length = currentTheme.colors(widget.isDarkMode, returnMaterialYou: false).keys.where((e) => e != "outline").length ~/ 2 + 1;
    return CustomScrollView(
      physics: ThemeSwitcher.getScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: SettingsOptions<ThemeStruct>(
            title: "Selected Theme",
            initial: currentTheme,
            options: allThemes
                .where((a) => !a.name.contains("🌙") && !a.name.contains("☀")).toList()
              ..add(ThemeStruct(name: "Divider1"))
              ..addAll(allThemes.where((a) => widget.isDarkMode ? a.name.contains("🌙") : a.name.contains("☀")))
              ..add(ThemeStruct(name: "Divider2"))
              ..addAll(allThemes.where((a) => !widget.isDarkMode ? a.name.contains("🌙") : a.name.contains("☀"))),
            backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : headerColor,
            secondaryColor: SettingsManager().settings.skin.value == Skins.Material ? headerColor : tileColor,
            textProcessing: (struct) => struct.name.toUpperCase(),
            useCupertino: false,
            materialCustomWidgets: (struct) => struct.name.contains("Divider") ? Divider(color: context.theme.colorScheme.outline, thickness: 2, height: 2) : Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: struct.data.colorScheme.primary,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: struct.data.colorScheme.secondary,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: struct.data.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: struct.data.colorScheme.tertiary,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    struct.name,
                    style: context.theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            onChanged: (value) async {
              if (value == null || value.name.contains("Divider")) return;
              value.save();

              if (value.name == "Music Theme ☀" || value.name == "Music Theme 🌙") {
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

              if (value.name == "Music Theme ☀" || value.name == "Music Theme 🌙") {
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
              } else if (currentTheme.name == "Music Theme ☀" ||
                  currentTheme.name == "Music Theme 🌙") {
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
            subtitle: "Tap to edit the base color\nLong press to edit the color for elements displayed on top of the base color\nDouble tap to learn how the colors are used",
            unlimitedSpace: true,
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
        SliverPadding(
          padding: EdgeInsets.only(top: 20, bottom: 10, left: 15),
          sliver: SliverToBoxAdapter(
            child: Text("COLORS", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
          ),
        ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return AdvancedThemingTile(
                currentTheme: currentTheme,
                tuple: Tuple2(currentTheme.colors(widget.isDarkMode).entries.toList()[index < length - 1
                    ? index * 2 : currentTheme.colors(widget.isDarkMode).entries.length - (length - index)],
                    index < length - 1 ? currentTheme.colors(widget.isDarkMode).entries.toList()[index * 2 + 1] : null),
                editable: editable,
              );
            },
            childCount: length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kIsDesktop ? (CustomNavigator.width(context) / 150).floor() : 2,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(top: 20, bottom: 10, left: 15),
          sliver: SliverToBoxAdapter(
            child: Text("FONT SIZE SCALING", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return SettingsSlider(
                leading: Text(currentTheme.textSizes.keys.toList()[index]),
                startingVal: currentTheme.textSizes.values.toList()[index] / ThemeStruct.defaultTextSizes.values.toList()[index],
                update: (double val) {
                  final map = currentTheme.toMap();
                  map["data"]["textTheme"][currentTheme.textSizes.keys.toList()[index]]['fontSize'] = ThemeStruct.defaultTextSizes.values.toList()[index] * val;
                  currentTheme.data = ThemeStruct.fromMap(map).data;
                  setState(() {});
                },
                onChangeEnd: (double val) {
                  final map = currentTheme.toMap();
                  map["data"]["textTheme"][currentTheme.textSizes.keys.toList()[index]]['fontSize'] = ThemeStruct.defaultTextSizes.values.toList()[index] * val;
                  currentTheme.data = ThemeStruct.fromMap(map).data;
                  currentTheme.save();
                  if (currentTheme.name == prefs.getString("selected-dark")) {
                    SettingsManager().saveSelectedTheme(context, selectedDarkTheme: currentTheme);
                  } else if (currentTheme.name == prefs.getString("selected-light")) {
                    SettingsManager().saveSelectedTheme(context, selectedLightTheme: currentTheme);
                  }
                },
                backgroundColor: tileColor,
                min: 0.5,
                max: 3,
                divisions: 10,
                text: '',
                formatValue: ((double val) => val.toStringAsFixed(2)),
              );
            },
            childCount: currentTheme.textSizes.length,
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
