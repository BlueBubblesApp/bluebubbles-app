import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key? key}) : super(key: key);

  @override
  _ThemingPanelState createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel> with TickerProviderStateMixin {
  TabController? controller;
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: Brightness.light,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: whiteLightTheme.accentColor.withOpacity(0.5),
                title: Text(
                  "Theming",
                  style: whiteLightTheme.textTheme.headline1,
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
              Icons.edit,
              color: Colors.white,
            ),
          ),
        ),
        bottomSheet: TabBar(
          indicatorColor: whiteLightTheme.primaryColor,
          indicator: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.blue,
                width: 3.0,
              ),
            ),
          ),
          tabs: [
            Tab(
              icon: Icon(
                Icons.brightness_high,
                color: whiteLightTheme.textTheme.bodyText1!.color,
              ),
            ),
            Tab(
              icon: Icon(
                Icons.brightness_3,
                color: whiteLightTheme.textTheme.bodyText1!.color,
              ),
            ),
          ],
          controller: controller,
        ),
      ),
    );
  }
}
