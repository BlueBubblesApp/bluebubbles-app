import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/theming/theming_color_selector.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';

class ThemingColorOptionsList extends StatefulWidget {
  ThemingColorOptionsList({Key? key, required this.isDarkMode, required this.controller}) : super(key: key);
  final bool isDarkMode;
  final StreamController controller;

  @override
  _ThemingColorOptionsListState createState() => _ThemingColorOptionsListState();
}

class _ThemingColorOptionsListState extends State<ThemingColorOptionsList> {
  ThemeObject? currentTheme;
  List<ThemeObject> allThemes = [];
  bool editable = false;

  @override
  void initState() {
    super.initState();
    if (widget.isDarkMode) {
      currentTheme = ThemeObject.getDarkTheme();
    } else {
      currentTheme = ThemeObject.getLightTheme();
    }
    currentTheme!.fetchData();

    allThemes = ThemeObject.getThemes();
    for (ThemeObject theme in allThemes) {
      theme.fetchData();
    }

    widget.controller.stream.listen((event) {
      if (!currentTheme!.isPreset) {
        showSnackbar('Customization', "Click on an item to customize");
        return;
      }

      BuildContext _context = context;
      showDialog(
        context: context,
        builder: (context) => NewThemeCreateAlert(
          onCreate: (String name) async {
            Navigator.of(context).pop();
            ThemeObject newTheme = ThemeObject(data: currentTheme!.themeData, name: name);
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
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    editable = currentTheme != null && !currentTheme!.isPreset;
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).colorScheme.secondary.computeLuminance() <
            Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }
    return currentTheme != null
        ? CustomScrollView(
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Container(
                    child: Text(
                      widget.isDarkMode ? "Dark Theme" : "Light Theme",
                      style: Theme.of(context).textTheme.headline1,
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
                          child: DropdownButton<ThemeObject>(
                            dropdownColor: tileColor,
                            items: allThemes
                                .map(
                                  (e) => DropdownMenuItem(
                                    child: Text(
                                      e.name!.toUpperCase().replaceAll("_", " "),
                                      style: Theme.of(context).textTheme.bodyText1,
                                    ),
                                    value: e,
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              value!.data = value.themeData;
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
                                var allThemes = ThemeObject.getThemes();
                                var currentLight = ThemeObject.getLightTheme();
                                var currentDark = ThemeObject.getDarkTheme();
                                currentLight.previousLightTheme = true;
                                currentDark.previousDarkTheme = true;
                                currentLight.save();
                                currentDark.save();
                                SettingsManager().saveSelectedTheme(context,
                                    selectedLightTheme:
                                        allThemes.firstWhere((element) => element.name == "Music Theme (Light)"),
                                    selectedDarkTheme:
                                        allThemes.firstWhere((element) => element.name == "Music Theme (Dark)"));
                              } else if (currentTheme!.name == "Music Theme (Light)" ||
                                  currentTheme!.name == "Music Theme (Dark)") {
                                if (!widget.isDarkMode) {
                                  ThemeObject previousDark = revertToPreviousDarkTheme();
                                  SettingsManager().saveSelectedTheme(context,
                                      selectedLightTheme: value, selectedDarkTheme: previousDark);
                                } else {
                                  ThemeObject previousLight = revertToPreviousLightTheme();
                                  SettingsManager().saveSelectedTheme(context,
                                      selectedLightTheme: previousLight, selectedDarkTheme: value);
                                }
                              } else if (widget.isDarkMode) {
                                SettingsManager().saveSelectedTheme(context, selectedDarkTheme: value);
                              } else {
                                SettingsManager().saveSelectedTheme(context, selectedLightTheme: value);
                              }
                              currentTheme = value;
                              editable = currentTheme != null && !currentTheme!.isPreset;
                              setState(() {});

                              EventDispatcher().emit('theme-update', null);
                            },
                            value: currentTheme,
                            hint: Text(
                              "Preset",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!currentTheme!.isPreset)
                SliverToBoxAdapter(
                    child: SettingsSwitch(
                  onChanged: (bool val) async {
                    currentTheme!.gradientBg = val;
                    currentTheme!.save();
                    if (widget.isDarkMode) {
                      SettingsManager().saveSelectedTheme(context, selectedDarkTheme: currentTheme);
                    } else {
                      SettingsManager().saveSelectedTheme(context, selectedLightTheme: currentTheme);
                    }
                  },
                  initialVal: currentTheme!.gradientBg,
                  title: "Gradient Message View Background",
                  backgroundColor: tileColor,
                  subtitle:
                      "Make the background of the messages view an animated gradient based on the background color and the primary color",
                )),
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ThemingColorSelector(
                      currentTheme: currentTheme!,
                      entry: currentTheme!.entries[index],
                      editable: editable,
                    );
                  },
                  childCount: ThemeColors.Colors.length, // ThemeColors.values.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: kIsDesktop ? (CustomNavigator.width(context) / 150).floor() : 2,
                ),
              ),
              if (!currentTheme!.isPreset)
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
                      currentTheme!.delete();
                      currentTheme =
                        widget.isDarkMode ? revertToPreviousDarkTheme() : revertToPreviousLightTheme();
                      allThemes = ThemeObject.getThemes();
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
          )
        : Center(
            child: LinearProgressIndicator(
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
  }
}

class NewThemeCreateAlert extends StatefulWidget {
  NewThemeCreateAlert({Key? key, required this.onCreate, required this.onCancel}) : super(key: key);
  final Function(String name) onCreate;
  final Function() onCancel;

  @override
  _NewThemeCreateAlertState createState() => _NewThemeCreateAlertState();
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
            if (ThemeObject.findOne(controller.text) != null || controller.text.isEmpty) {
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
