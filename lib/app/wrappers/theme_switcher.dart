import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_page_transition.dart';
import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class ThemeSwitcher extends StatefulWidget {
  const ThemeSwitcher({super.key, required this.iOSSkin, required this.materialSkin, this.samsungSkin});
  final Widget iOSSkin;
  final Widget materialSkin;
  final Widget? samsungSkin;

  static PageRoute<T> buildPageRoute<T>(
      {required Widget Function(BuildContext context) builder, RouteSettings? settings}) {
    // A page moving over another would show it through the see-through window
    if (kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled) {
      return _CoveringRoute<T>(builder: builder, settings: settings);
    }
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

// Opacity 0 skips painting, so hiding costs nothing, unlike a fade
Widget _hideWhenCovered(Animation<double> secondaryAnimation, Widget? child) =>
    FadeTransition(opacity: _ShownAnimation(secondaryAnimation), child: child);

/// 0 while a page covers or is coming over this one, 1 once it starts leaving, so a pop reveals this page right away
class _ShownAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _ShownAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.status == AnimationStatus.forward || parent.status == AnimationStatus.completed ? 0 : 1;
}

/// The skin's transition, with the page below hidden while it's covered
class _CoveringRoute<T> extends PageRouteBuilder<T> {
  _CoveringRoute({required WidgetBuilder builder, super.settings})
      : super(pageBuilder: (context, _, _) => builder(context));

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final skinned = SettingsSvc.settings.skin.value == Skins.iOS
        ? CustomCupertinoPageTransition(primaryRouteAnimation: animation, linearTransition: false, child: child)
        : Theme.of(context).pageTransitionsTheme.buildTransitions(this, context, animation, secondaryAnimation, child);
    return _hideWhenCovered(secondaryAnimation, skinned);
  }

  // Stays in view under see-through popups
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is PageRoute && nextRoute.opaque;

  /// Hides the page below too, even one that isn't a covering route
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegated;

  static Widget? _delegated(BuildContext _, Animation<double> _, Animation<double> secondaryAnimation, bool _,
          Widget? child) =>
      _hideWhenCovered(secondaryAnimation, child);
}
