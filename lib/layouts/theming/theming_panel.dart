import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key? key}) : super(key: key);

  @override
  _ThemingPanelState createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel> {
  int index = ThemeObject.inDarkMode(Get.context!) ? 1 : 0;
  StreamController streamController = StreamController.broadcast();

  @override
  void dispose() {
    streamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: DefaultTabController(
        length: 2,
        initialIndex: index,
        child: Scaffold(
          backgroundColor: tileColor,
          appBar: PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  systemOverlayStyle: ThemeData.estimateBrightnessForColor(headerColor) == Brightness.dark
                      ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.copy,
                    color: Colors.white,
                  ),
                  PositionedDirectional(
                    start: 7.5,
                    top: 8,
                    child: Icon(
                      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.edit,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ]
              )
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
              onTap: (val) {
                index = val;
              },
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
            ),
          ),
        ),
      ),
    );
  }
}
