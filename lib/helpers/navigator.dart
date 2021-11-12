import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: non_constant_identifier_names
BaseNavigator CustomNavigator = Get.isRegistered<BaseNavigator>() ? Get.find<BaseNavigator>() : Get.put(BaseNavigator());

/// Handles navigation for the app
class BaseNavigator extends GetxService {
  /// width of left side of split screen view
  double? _widthChatListLeft;
  /// width of right side of split screen view
  double? _widthChatListRight;
  /// width of settings right side split screen
  double? _widthSettings;

  set maxWidthLeft(double w) => _widthChatListLeft = w;
  set maxWidthRight(double w) => _widthChatListRight = w;
  set maxWidthSettings(double w) => _widthSettings = w;

  /// grab the available screen width, returning the split screen width if applicable
  /// this should *always* be used in place of context.width or similar
  double width(BuildContext context) {
    if (Navigator.of(context).widget.key?.toString().contains("Getx nested key: 1") ?? false) {
      return _widthChatListLeft ?? context.width;
    } else if (Navigator.of(context).widget.key?.toString().contains("Getx nested key: 2") ?? false) {
      return _widthChatListRight ?? context.width;
    } else if (Navigator.of(context).widget.key?.toString().contains("Getx nested key: 3") ?? false) {
      return _widthSettings ?? context.width;
    }
    return context.width;
  }

  /// Push a new route onto the chat list right side navigator
  void push(BuildContext context, Widget widget) {
    if (Get.keys.containsKey(2) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.to(() => widget, transition: Transition.rightToLeft, id: 2);
    } else {
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  /// Push a new route onto the chat list left side navigator
  void pushLeft(BuildContext context, Widget widget) {
    if (Get.keys.containsKey(1) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.to(() => widget, transition: Transition.leftToRight, id: 1);
    } else {
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  /// Push a new route onto the settings navigator
  void pushSettings(BuildContext context, Widget widget, {Bindings? binding}) {
    if (Get.keys.containsKey(3) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.to(() => widget, transition: Transition.rightToLeft, id: 3, binding: binding);
    } else {
      binding?.dependencies();
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  /// Push a new route, popping all previous routes, on the chat list right side navigator
  void pushAndRemoveUntil(BuildContext context, Widget widget, bool Function(Route) predicate) {
    if (Get.keys.containsKey(2) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.offUntil(
          GetPageRoute(
            page: () => widget,
            transition: Transition.noTransition,
            transitionDuration: Duration.zero,
          ),
          predicate,
          id: 2);
    } else {
      Navigator.of(context).pushAndRemoveUntil(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ), predicate);
    }
  }

  /// Push a new route, popping all previous routes, on the settings navigator
  void pushAndRemoveSettingsUntil(BuildContext context, Widget widget, bool Function(Route) predicate,
      {Bindings? binding}) {
    if (Get.keys.containsKey(3) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      // we only want to offUntil when in landscape, otherwise when the user presses back, the previous page will be the chat list
      Get.offUntil(GetPageRoute(
          page: () => widget,
          binding: binding,
          transition: Transition.noTransition,
          transitionDuration: Duration.zero,
      ), predicate, id: 3);
    } else {
      binding?.dependencies();
      // only push here because we don't want to remove underlying routes when in portrait
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  void backSettingsCloseOverlays(BuildContext context) {
    if (Get.keys.containsKey(3) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.back(closeOverlays: true, id: 3);
    } else {
      Get.back(closeOverlays: true);
    }
  }
}
