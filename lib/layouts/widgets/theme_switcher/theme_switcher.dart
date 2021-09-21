import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeSwitcher extends StatefulWidget {
  ThemeSwitcher({Key? key, required this.iOSSkin, required this.materialSkin, required this.samsungSkin})
      : super(key: key);
  final Widget iOSSkin;
  final Widget materialSkin;
  final Widget samsungSkin;

  static PageRoute buildPageRoute({required Widget Function(BuildContext context) builder}) {
    switch (SettingsManager().settings.skin.value) {
      case Skins.iOS:
        return CupertinoPageRoute(builder: builder);
      case Skins.Material:
        return MaterialPageRoute(builder: builder);
      case Skins.Samsung:
        return MaterialPageRoute(builder: builder);
      default:
        return CupertinoPageRoute(builder: builder);
    }
  }

  static ScrollPhysics getScrollPhysics() {
    switch (SettingsManager().settings.skin.value) {
      case Skins.iOS:
        return AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        );
      case Skins.Material:
        return AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        );
      case Skins.Samsung:
        return AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        );
      default:
        return AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        );
    }
  }

  @override
  _ThemeSwitcherState createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (SettingsManager().settings.skin.value) {
        case Skins.iOS:
          return widget.iOSSkin;
        case Skins.Material:
          return widget.materialSkin;
        case Skins.Samsung:
          return widget.samsungSkin;
        default:
          return widget.iOSSkin;
      }
    });
  }
}
