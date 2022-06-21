import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this, initialIndex: index);
  }

  @override
  void dispose() {
    streamController.close();
    super.dispose();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value == Skins.Material ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 50),
          child: AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            toolbarHeight: 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: headerColor,
            centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
            title: Text(
              "Advanced Theming",
              style: context.theme.textTheme.titleLarge,
            ),
          ),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: headerColor,
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
        ),
      ),
    );
  }
}
