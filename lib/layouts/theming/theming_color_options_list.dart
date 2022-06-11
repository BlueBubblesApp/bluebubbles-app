import 'dart:async';

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
import 'package:bluebubbles/repository/models/models.dart';
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
      if (!currentTheme.isPreset) {
        showSnackbar('Customization', "Click on an item to customize");
        return;
      }

      BuildContext _context = context;
      showDialog(
        context: context,
        builder: (context) => NewThemeCreateAlert(
          onCreate: (String name) async {
            Navigator.of(context).pop();
            ThemeStruct newTheme = ThemeStruct(themeData: currentTheme.data, name: name);
            allThemes.add(newTheme);
            currentTheme = newTheme;
            if (widget.isDarkMode) {
              SettingsManager().saveSelectedTheme(_context, selectedDarkTheme: currentTheme);
            } else {
              SettingsManager().saveSelectedTheme(_context, selectedLightTheme: currentTheme);
            }
            setState(() {});
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    editable = !currentTheme.isPreset;
    Color headerColor = context.theme.headerColor;
    Color tileColor = context.theme.tileColor;
    final length = currentTheme.colors.keys.where((e) => e != "outline" && e != "shadow" && e != "inversePrimary").length ~/ 2 + 3;
    return CustomScrollView(
      physics: ThemeSwitcher.getScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: Container(
              child: Text(
                widget.isDarkMode ? "Dark Theme" : "Light Theme",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: CustomNavigator.width(context) - 16,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                    color: headerColor,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeStruct>(
                      dropdownColor: tileColor,
                      items: allThemes
                          .map(
                            (e) => DropdownMenuItem(
                              child: Text(
                                e.name.toUpperCase().replaceAll("_", " "),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              value: e,
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        value.save();

                        if (value.name == "Music Theme (Light)" || value.name == "Music Theme (Dark)") {
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
                      value: currentTheme,
                      hint: Text(
                        "Preset",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                "Make the background of the messages view an animated gradient based on the background color and the primary color",
          )),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: Container(
              child: Text(
                "Tap to edit the base color, and long press to edit the color for elements displayed on top of the base color",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return ThemingColorSelector(
                currentTheme: currentTheme,
                tuple: Tuple2(currentTheme.colors.entries.toList()[index < length - 3
                    ? index * 2 : currentTheme.colors.entries.length - (length - index)],
                    index < length - 3 ? currentTheme.colors.entries.toList()[index * 2 + 1] : null),
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
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
              child: Text(
                "Delete",
                style: TextStyle(color: Colors.red),
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
        SliverPadding(
          padding: EdgeInsets.all(25),
        ),
      ],
    );
  }
}

class NewThemeCreateAlert extends StatefulWidget {
  NewThemeCreateAlert({Key? key, required this.onCreate, required this.onCancel}) : super(key: key);
  final Function(String name) onCreate;
  final Function() onCancel;

  @override
  State<NewThemeCreateAlert> createState() => _NewThemeCreateAlertState();
}

class _NewThemeCreateAlertState extends State<NewThemeCreateAlert> {
  TextEditingController controller = TextEditingController();
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed: () {
            if (ThemeStruct.findOne(controller.text) != null || controller.text.isEmpty) {
              setState(() {
                showError = true;
              });
            } else {
              widget.onCreate(controller.text);
            }
          },
        ),
        TextButton(
          child: Text("Cancel"),
          onPressed: widget.onCancel,
        )
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Theme Name",
              border: OutlineInputBorder(),
            ),
          ),
          if (showError)
            Text(
              "Please select a name of a theme that has not already been used",
              style: TextStyle(color: Colors.red, fontSize: 14),
            )
        ],
      ),
      title: Text("Create a New Theme"),
    );
  }
}
