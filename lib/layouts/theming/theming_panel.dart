import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key? key}) : super(key: key);

  @override
  _ThemingPanelState createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel> with TickerProviderStateMixin {
  late TabController controller;
  StreamController streamController = StreamController.broadcast();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark) {
      controller = TabController(vsync: this, initialIndex: 1, length: 2);
    } else {
      controller = TabController(vsync: this, initialIndex: 0, length: 2);
    }
  }

  @override
  void dispose() {
    streamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: tileColor,
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
                  "Theming",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: TabBarView(
          physics: ThemeSwitcher.getScrollPhysics(),
          controller: controller,
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
          child: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              streamController.sink.add(null);
            },
            child: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.edit,
              color: Colors.white,
            ),
          ),
        ),
        bottomSheet: Container(
          color: tileColor,
          child: TabBar(
            indicatorColor: Theme.of(context).primaryColor,
            indicator: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.blue,
                  width: 3.0,
                ),
              ),
            ),
            tabs: [
              Container(
                child: Tab(
                  icon: Icon(
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.sun_max : Icons.brightness_high,
                    color: Theme.of(context).textTheme.bodyText1!.color,
                  ),
                ),
              ),
              Tab(
                icon: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.moon : Icons.brightness_3,
                  color: Theme.of(context).textTheme.bodyText1!.color,
                ),
              ),
            ],
            controller: controller,
          ),
        ),
      ),
    );
  }
}
