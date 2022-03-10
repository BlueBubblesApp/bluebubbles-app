import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
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

  final Rx listener = Rxn();

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
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
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
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
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
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
  }

  /// Push a new route, popping all previous routes, on the chat list right side navigator
  Future<void> pushAndRemoveUntil(BuildContext context, Widget widget, bool Function(Route) predicate) async {
    if (Get.keys.containsKey(2) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      await Get.offUntil(
          GetPageRoute(
            page: () => widget,
            transition: Transition.noTransition,
            transitionDuration: Duration.zero,
          ),
          predicate,
          id: 2);
    } else {
      await Navigator.of(context).pushAndRemoveUntil(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
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
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
  }

  void backConversationView(BuildContext context) {
    if (Get.keys.containsKey(3) &&
        Get.keys[3]?.currentContext != null &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.until((route) {
        if (route.settings.name == "initial") {
          Get.back();
        } else {
          Get.back(id: 3);
        }
        return true;
      }, id: 3);
    } else if (Get.keys.containsKey(2) &&
        Get.keys[2]?.currentContext != null &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      if (Get.currentRoute.isEmpty) {
        Get.back();
        return;
      }
      Get.until((route) {
        bool id2result = false;
        // check if we should pop the left side first
        Get.until((route) {
          if (route.settings.name != "initial") {
            Get.back(id: 2);
            id2result = true;
          }
          if (!(Get.global(2).currentState?.canPop() ?? true)) {
            EventDispatcher().emit('update-highlight', null);
          }
          return true;
        }, id: 2);
        if (!id2result) {
          if (route.settings.name != "initial") {
            Get.back(id: 1);
          }
        }
        return true;
      }, id: 1);
    }
  }

  void backSettings(BuildContext context, {bool closeOverlays = false}) {
    if (Get.keys.containsKey(3) &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value)) {
      Get.back(closeOverlays: closeOverlays, id: 3);
    } else {
      Get.back(closeOverlays: closeOverlays);
    }
  }
}
