import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key? key}) : super(key: key);

  @override
  State<ThemingPanel> createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel> with SingleTickerProviderStateMixin {
  int index = ThemeManager().inDarkMode(Get.context!) ? 1 : 0;
  StreamController streamController = StreamController.broadcast();
  late final TabController controller;
  late final List<ThemeObject> oldThemes;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this, initialIndex: index);
    oldThemes = ThemeObject.getThemes().where((e) => !e.isPreset).toList();
  }

  @override
  void dispose() {
    streamController.close();
    super.dispose();
  }

  void clearOld() {
    oldThemes.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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

    final Rx<Color> _headerColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent).obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _headerColor.value = effect != WindowEffect.disabled ? Colors.transparent : headerColor;
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => Scaffold(
        backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : _headerColor.value,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 50),
          child: Obx(() => AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            toolbarHeight: 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: _headerColor.value,
            centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
            title: Text(
              "Advanced Theming",
              style: context.theme.textTheme.titleLarge,
            ),
            actions: [
              if (oldThemes.isNotEmpty)
                TextButton(
                  child: Text("View Old", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Old Themes", style: context.theme.textTheme.titleLarge),
                          backgroundColor: context.theme.colorScheme.properSurface,
                          content: SingleChildScrollView(
                            child: Container(
                              width: double.maxFinite,
                              child: StatefulBuilder(builder: (context, setState) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child:
                                      Text("Tap an old theme to view its colors"),
                                    ),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: context.mediaQuery.size.height * 0.4,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: oldThemes.length,
                                        itemBuilder: (context, index) {
                                          return ListTile(
                                            title: Text(
                                              oldThemes[index].name ?? "Unknown Theme",
                                              style: context.theme.textTheme.bodyLarge),
                                            onTap: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text("${oldThemes[index].name ?? "Unknown Theme"} Colors", style: context.theme.textTheme.titleLarge),
                                                    backgroundColor: context.theme.colorScheme.properSurface,
                                                    content: SingleChildScrollView(
                                                      child: Container(
                                                        width: double.maxFinite,
                                                        child: StatefulBuilder(builder: (context, setState) {
                                                          return ConstrainedBox(
                                                            constraints: BoxConstraints(
                                                              maxHeight: context.mediaQuery.size.height * 0.4,
                                                            ),
                                                            child: ListView.builder(
                                                              shrinkWrap: true,
                                                              itemCount: 4,
                                                              itemBuilder: (context, index2) {
                                                                final hex = oldThemes[index].entries.firstWhere((element) => element.name == ThemeColors.Colors.reversed.toList()[index2]).color!.hex;
                                                                return ListTile(
                                                                  title: Text(
                                                                    ThemeColors.Colors.reversed.toList()[index2],
                                                                    style: context.theme.textTheme.bodyLarge),
                                                                  subtitle: Text(
                                                                    hex,
                                                                  ),
                                                                  leading: Container(
                                                                    decoration: BoxDecoration(
                                                                      shape: BoxShape.circle,
                                                                      color: oldThemes[index].entries.firstWhere((element) => element.name == ThemeColors.Colors.reversed.toList()[index2]).color!
                                                                    ),
                                                                    height: 30,
                                                                    width: 30,
                                                                  ),
                                                                  onTap: () {
                                                                    Clipboard.setData(ClipboardData(text: hex));
                                                                    showSnackbar('Copied', 'Hex code copied to clipboard');
                                                                  }
                                                                );
                                                              },
                                                            ),
                                                          );
                                                        }),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                          child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                          onPressed: () {
                                                            Navigator.of(context).pop();
                                                          }
                                                      ),
                                                    ],
                                                  )
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                          actions: [
                            TextButton(
                                child: Text("Delete Old", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () {
                                  themeObjectBox.removeAll();
                                  themeEntryBox.removeAll();
                                  clearOld();
                                  Navigator.of(context).pop();
                                }
                            ),
                            TextButton(
                                child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                }
                            ),
                          ],
                        )
                    );
                  },
                ),
            ]
          )),
        ),
        body: TabBarView(
          controller: controller,
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            ThemingColorOptionsList(
              isDarkMode: false,
              controller: streamController,
            ),
            ThemingColorOptionsList(
              isDarkMode: true,
              controller: streamController,
            )
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: .0),
          child: FloatingActionButton.extended(
            backgroundColor: context.theme.colorScheme.primary,
            onPressed: () {
              streamController.sink.add(null);
            },
            label: Text("Create New", style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.onPrimary)),
            icon: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.edit,
              color: context.theme.colorScheme.onPrimary,
            )
          ),
        ),
        bottomNavigationBar: Obx(() => NavigationBar(
          selectedIndex: index,
          backgroundColor: _headerColor.value,
          destinations: [
            NavigationDestination(
              icon: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.sun_max : Icons.brightness_high),
              label: "LIGHT THEME",
            ),
            NavigationDestination(
              icon: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.moon : Icons.brightness_3,
              ),
              label: "DARK THEME",
            ),
          ],
          onDestinationSelected: (page) {
            setState(() {
              index = page;
            });
            controller.animateTo(page);
          },
        )),
      )),
    );
  }
}
