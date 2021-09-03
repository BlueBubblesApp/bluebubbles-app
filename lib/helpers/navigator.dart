import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: non_constant_identifier_names
BaseNavigator CustomNavigator = Get.isRegistered<BaseNavigator>() ? Get.find<BaseNavigator>() : Get.put(BaseNavigator());

class BaseNavigator extends GetxService {
  double? _widthChatListLeft;
  double? _widthChatListRight;
  double? _widthSettings;

  set maxWidthLeft(double w) => _widthChatListLeft = w;
  set maxWidthRight(double w) => _widthChatListRight = w;
  set maxWidthSettings(double w) => _widthSettings = w;

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

  void push(BuildContext context, Widget widget) {
    if (Get.keys.containsKey(2) && (!context.isPhone || context.isLandscape)) {
      Get.to(() => widget, transition: Transition.rightToLeft, id: 2);
    } else {
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  void pushLeft(BuildContext context, Widget widget) {
    if (Get.keys.containsKey(1) && (!context.isPhone || context.isLandscape)) {
      Get.to(() => widget, transition: Transition.leftToRight, id: 1);
    } else {
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ));
    }
  }

  void pushSettings(BuildContext context, Widget widget, {Bindings? binding}) {
    if (Get.keys.containsKey(3) && (!context.isPhone || context.isLandscape)) {
      Get.to(() => widget, transition: Transition.rightToLeft, id: 3, binding: binding);
    } else {
      Get.to(() => widget, binding: binding);
    }
  }

  void pushAndRemoveUntil(BuildContext context, Widget widget, bool Function(Route) predicate) {
    if (Get.keys.containsKey(2) && (!context.isPhone || context.isLandscape)) {
      Get.offUntil(GetPageRoute(
        page: () => widget,
        transition: Transition.rightToLeft
      ), predicate, id: 2);
    } else {
      Navigator.of(context).pushAndRemoveUntil(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => widget,
      ), predicate);
    }
  }

  void pushAndRemoveSettingsUntil(BuildContext context, Widget widget, bool Function(Route) predicate, {Bindings? binding}) {
    print(Get.keys[3]?.currentContext?.size?.width);
    print((Navigator.of(context).widget.key as GlobalKey?)?.currentContext?.size?.width);
    if (Get.keys.containsKey(3) && (!context.isPhone || context.isLandscape)) {
      // we only want to offUntil when in landscape, otherwise when the user presses back, the previous page will be the chat list
      Get.offUntil(GetPageRoute(
          page: () => widget,
          binding: binding,
          transition: Transition.rightToLeft
      ), predicate, id: 3);
    } else {
      Get.to(() => widget, binding: binding);
    }
  }
}
