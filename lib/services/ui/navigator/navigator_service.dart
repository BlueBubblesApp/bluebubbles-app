import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

NavigatorService ns = Get.isRegistered<NavigatorService>() ? Get.find<NavigatorService>() : Get.put(NavigatorService());

/// Handles navigation for the app
class NavigatorService extends GetxService {
  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  final Rxn listener = Rxn();
  /// width of left side of split screen view
  double? _widthChatListLeft;
  /// width of right side of split screen view
  double? _widthChatListRight;
  /// width of settings right side split screen
  double? _widthSettings;

  set maxWidthLeft(double w) => _widthChatListLeft = w;
  set maxWidthRight(double w) => _widthChatListRight = w;
  set maxWidthSettings(double w) => _widthSettings = w;

  bool isTabletMode(BuildContext context) => (!context.isPhone || context.width / context.height > 0.8) &&
      ss.settings.tabletMode.value && context.width > 600;

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

  double ratio(BuildContext context) => (_widthChatListLeft ?? context.width) / context.width;
  
  bool isAvatarOnly(BuildContext context) => ratio(context) < 0.2;

  /// Push a new route onto the chat list right side navigator
  void push(BuildContext context, Widget widget) {
    if (Get.keys.containsKey(2) && isTabletMode(context)) {
      Get.to(() => widget, transition: Transition.rightToLeft, id: 2);
    } else {
      Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
  }

  /// Push a new route onto the chat list left side navigator
  Future<void> pushLeft(BuildContext context, Widget widget) async {
    if (Get.keys.containsKey(1) && isTabletMode(context)) {
      await Get.to(() => widget, transition: Transition.leftToRight, id: 1);
    } else {
      await Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
  }

  /// Push a new route onto the settings navigator
  Future<dynamic> pushSettings(BuildContext context, Widget widget, {Bindings? binding}) async {
    if (Get.keys.containsKey(3) && isTabletMode(context)) {
      return await Get.to(() => widget, transition: Transition.rightToLeft, id: 3, binding: binding);
    } else {
      binding?.dependencies();
      return await Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
  }

  /// Push a new route, popping all previous routes, on the chat list right side navigator
  Future<void> pushAndRemoveUntil(BuildContext context, Widget widget, bool Function(Route) predicate,
      {bool closeActiveChat = true, PageRoute? customRoute}) async {
    if (Get.keys.containsKey(2) && isTabletMode(context)) {
      if (closeActiveChat && cm.activeChat != null) {
        cvc(cm.activeChat!.chat).close();
      }
      await Get.offUntil(
          GetPageRoute(
            page: () => widget,
            transition: Transition.noTransition,
            transitionDuration: Duration.zero,
          ),
          predicate,
          id: 2);
    } else {
      await Navigator.of(context).pushAndRemoveUntil(customRoute ?? ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ), predicate);
    }
  }

  /// Push a new route, popping all previous routes, on the settings navigator
  void pushAndRemoveSettingsUntil(BuildContext context, Widget widget, bool Function(Route) predicate,
      {Bindings? binding}) {
    if (Get.keys.containsKey(3) && isTabletMode(context)) {
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
        isTabletMode(context)) {
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
        isTabletMode(context)) {
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
            if (cm.activeChat != null) {
              cvc(cm.activeChat!.chat).close();
            }
            eventDispatcher.emit('update-highlight', null);
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

  void closeAllConversationView(BuildContext context) {
    if (Get.keys.containsKey(2) && Get.keys[2]?.currentContext != null && ns.isTabletMode(context)) {
      Get.until((route) {
        return route.settings.name == "initial";
      }, id: 2);
    }
    eventDispatcher.emit("update-highlight", null);
  }

  void backSettings(BuildContext context, {dynamic result, bool closeOverlays = false}) {
    if (Get.keys.containsKey(3) && isTabletMode(context)) {
      Get.back(result: result, closeOverlays: closeOverlays, id: 3);
    } else {
      Get.back(result: result, closeOverlays: closeOverlays);
    }
  }
}
