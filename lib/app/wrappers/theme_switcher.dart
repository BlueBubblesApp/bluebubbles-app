import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_page_transition.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeSwitcher extends StatefulWidget {
  const ThemeSwitcher({super.key, required this.iOSSkin, required this.materialSkin, this.samsungSkin});
  final Widget iOSSkin;
  final Widget materialSkin;
  final Widget? samsungSkin;

  static PageRoute<T> buildPageRoute<T>(
      {required Widget Function(BuildContext context) builder, RouteSettings? settings}) {
    switch (SettingsSvc.settings.skin.value) {
      case Skins.iOS:
        return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) => builder.call(context),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return CustomCupertinoPageTransition(
                  primaryRouteAnimation: animation, linearTransition: false, child: child);
            });
      case Skins.Material:
        return MaterialPageRoute<T>(builder: builder, settings: settings);
      case Skins.Samsung:
        return MaterialPageRoute<T>(builder: builder, settings: settings);
    }
  }

  static ScrollPhysics getScrollPhysics() {
    switch (SettingsSvc.settings.skin.value) {
      case Skins.iOS:
        return const AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        );
      case Skins.Material:
        return const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        );
      case Skins.Samsung:
        return const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        );
    }
  }

  @override
  State<ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (SettingsSvc.settings.skin.value) {
        case Skins.iOS:
          return widget.iOSSkin;
        case Skins.Material:
          return widget.materialSkin;
        case Skins.Samsung:
          return widget.samsungSkin ?? widget.materialSkin;
      }
    });
  }
}
