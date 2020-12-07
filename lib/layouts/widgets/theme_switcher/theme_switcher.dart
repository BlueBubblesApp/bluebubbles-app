import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';

class ThemeSwitcher extends StatefulWidget {
  ThemeSwitcher(
      {Key key, @required this.cupertinoWidget, @required this.materialWidget})
      : super(key: key);
  final Widget cupertinoWidget;
  final Widget materialWidget;

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
    if (skin == Skins.IOS) {
      return widget.cupertinoWidget;
    } else {
      return widget.materialWidget;
    }
  }
}
