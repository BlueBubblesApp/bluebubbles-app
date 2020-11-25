import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';

class ThemeSwitcher extends StatefulWidget {
  ThemeSwitcher({Key key, @required this.iOSSkin, @required this.materialSkin})
      : super(key: key);
  final Widget iOSSkin;
  final Widget materialSkin;

  @override
  _ThemeSwitcherState createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {
  Skins skin;

  @override
  void initState() {
    super.initState();
    skin = SettingsManager().settings.skin;

    SettingsManager().stream.listen((event) {
      if (!this.mounted) return;

      if (event.skin != skin) {
        skin = event.skin;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (skin) {
      case Skins.IOS:
        return widget.iOSSkin;
      case Skins.Material:
        return widget.materialSkin;
    }
    return Container();
  }
}
