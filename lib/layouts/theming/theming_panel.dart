import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/layouts/theming/theming_color_options_list.dart';
import 'package:flutter/material.dart';

class ThemingPanel extends StatefulWidget {
  ThemingPanel({Key key}) : super(key: key);

  @override
  _ThemingPanelState createState() => _ThemingPanelState();
}

class _ThemingPanelState extends State<ThemingPanel> {
  PageController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AdaptiveTheme.of(context).mode.isDark) {
      controller = PageController(initialPage: 1);
    } else {
      controller = PageController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 80),
        child: ClipRRect(
          child: BackdropFilter(
            child: AppBar(
              toolbarHeight: 100.0,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).primaryColor),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
              title: Text(
                "Theming",
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          ),
        ),
      ),
      body: PageView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        controller: controller,
        children: <Widget>[
          ThemingColorOptionsList(
            isDarkMode: false,
          ),
          ThemingColorOptionsList(
            isDarkMode: true,
          )
        ],
      ),
    );
  }
}
