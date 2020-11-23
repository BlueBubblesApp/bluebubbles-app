import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:flutter/material.dart';

class EditController {
  StreamController controller = StreamController.broadcast();
  Stream get stream => controller.stream;
}

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key key}) : super(key: key);

  @override
  _ThemingPanelState createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel>
    with TickerProviderStateMixin {
  TabController controller;
  EditController editController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AdaptiveTheme.of(context).mode.isDark) {
      controller = TabController(vsync: this, initialIndex: 1, length: 2);
    } else {
      controller = TabController(vsync: this, initialIndex: 0, length: 2);
    }

    if (editController == null) {
      editController = new EditController();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 80),
        child: ClipRRect(
          child: BackdropFilter(
            child: AppBar(
              toolbarHeight: 100.0,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: whiteLightTheme.primaryColor),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
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
        physics: AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        ),
        controller: controller,
        children: <Widget>[
          ThemingColorOptionsList(
            isDarkMode: false,
            controller: editController,
          ),
          ThemingColorOptionsList(
            isDarkMode: true,
            controller: editController,
          )
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: .0),
        child: FloatingActionButton(
          backgroundColor: Colors.blue,
          onPressed: () {
            editController.controller.sink.add(null);
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
              color: whiteLightTheme.textTheme.bodyText1.color,
            ),
          ),
          Tab(
            icon: Icon(
              Icons.brightness_3,
              color: whiteLightTheme.textTheme.bodyText1.color,
            ),
          ),
        ],
        controller: controller,
      ),
    );
  }
}
