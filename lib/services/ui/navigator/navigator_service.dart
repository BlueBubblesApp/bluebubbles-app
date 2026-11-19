import 'package:bluebubbles/app/layouts/findmy/findmy_page.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: non_constant_identifier_names
NavigatorService get NavigationSvc =>
    Get.isRegistered<NavigatorService>() ? Get.find<NavigatorService>() : Get.put(NavigatorService());

enum AppSection { settings, findMy }

/// The chat list's split is nested navigators 1 (left) and 2 (right). Settings and Find My open over it full-window
/// with splits of their own, Settings' right pane being navigator 3. The phone layout keeps each split's navigators,
/// stacking the right pane over the left while it has a page.
class NavigatorService {
  NavigatorService() {
    ever(settingsPaneOpen, (bool open) {
      if (!open) activeSettingsPage.value = null;
    });
  }

  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  final Rxn listener = Rxn();

  /// In the phone layout the right pane covers the left only while this is true
  final RxBool chatPaneOpen = false.obs;
  late final PaneObserver chatPaneObserver = PaneObserver(chatPaneOpen);

  final RxBool settingsPaneOpen = false.obs;

  /// Dialogs and see-through popups, like a message's, don't count as covering
  final RouteObserver<ModalRoute> paneRouteObserver = _OpaqueRouteObserver();

  late final SectionObserver sectionObserver = SectionObserver(openSection);

  final Rxn<AppSection> openSection = Rxn<AppSection>();

  NavigatorState? get _root => key.currentState;
  NavigatorState? get _left => Get.keys[1]?.currentState;
  NavigatorState? get _right => Get.keys[2]?.currentState;
  NavigatorState? get _settings => Get.keys[3]?.currentState;

  /// Runtime type of the settings page open in the split view's right pane —
  /// settings list tiles highlight themselves when it matches their destination.
  final Rxn<Type> activeSettingsPage = Rxn<Type>();

  /// width of left side of split screen view
  double? _widthChatListLeft;

  /// width of right side of split screen view
  double? _widthChatListRight;

  /// width of settings right side split screen
  double? _widthSettings;

  set maxWidthLeft(double w) => _widthChatListLeft = w;
  set maxWidthRight(double w) => _widthChatListRight = w;
  set maxWidthSettings(double w) => _widthSettings = w;

  /// Returns widthChatListLeft if in tablet mode, and 0 otherwise
  double widthChatListLeft(BuildContext context) => isTabletMode(context) ? _widthChatListLeft ?? 0 : 0;

  bool isTabletMode(BuildContext context) =>
      (!context.isPhone || context.width / context.height > 0.8) &&
      SettingsSvc.settings.tabletMode.value &&
      context.width > 600;

  bool get _tabletLayout {
    final context = _root?.context ?? Get.context;
    return context != null && isTabletMode(context);
  }

  /// grab the available screen width, returning the split screen width if applicable
  /// this should *always* be used in place of context.width or similar
  double width(BuildContext context) {
    final key = Navigator.maybeOf(context)?.widget.key;
    if (key != null && key == Get.keys[1]) return _widthChatListLeft ?? context.width;
    if (key != null && key == Get.keys[2]) return _widthChatListRight ?? context.width;
    if (key != null && key == Get.keys[3]) return _widthSettings ?? context.width;
    return context.width;
  }

  double ratio(BuildContext context) => (_widthChatListLeft ?? context.width) / context.width;

  bool isAvatarOnly(BuildContext context) =>
      (kIsDesktop || kIsWeb) && isTabletMode(context) && (_widthChatListLeft ?? context.width) < 300;

  static PageRoute _instantRoute(Widget widget) => PageRouteBuilder(
        pageBuilder: (_, _, _) => widget,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );

  /// Into Settings' right pane while Settings is on top, the chat list's otherwise
  Future<T?> push<T>(BuildContext context, Widget widget) {
    final pane = openSection.value == AppSection.settings ? _settings : _right;
    if (pane == null) {
      return Navigator.of(context).push<T>(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
    return pane.push<T>(ThemeSwitcher.buildPageRoute(builder: (BuildContext context) => widget));
  }

  Future<void> pushLeft(BuildContext context, Widget widget) async {
    final left = _left;
    // The phone layout hides the left pane behind an open chat
    if (left != null && !_tabletLayout && chatPaneOpen.value) {
      await push(context, widget);
      return;
    }
    if (left == null) {
      await Navigator.of(context).push(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
      return;
    }
    await left.push(ThemeSwitcher.buildPageRoute(builder: (BuildContext context) => widget));
  }

  void _openSection(AppSection section, Widget page) {
    closeSections();
    _root?.push(ThemeSwitcher.buildPageRoute(settings: RouteSettings(name: section.name), builder: (_) => page));
  }

  /// Already in Settings, this just switches to [initialPage]
  void openSettings({Widget? initialPage}) {
    if (openSection.value == AppSection.settings) {
      if (initialPage != null) pushAndRemoveSettingsUntil(Get.context!, initialPage, (_) => false);
      return;
    }
    _openSection(AppSection.settings, SettingsPage(initialPage: initialPage));
  }

  void openFindMy() {
    if (openSection.value == AppSection.findMy) return;
    _openSection(AppSection.findMy, const FindMyPage());
  }

  void closeSections() {
    final root = _root;
    if (root == null) return;
    for (final route in sectionObserver.routes.toList()) {
      root.removeRoute(route);
    }
  }

  Future<dynamic> pushSettings(BuildContext context, Widget widget, {Bindings? binding}) async {
    binding?.dependencies();
    return push(context, widget);
  }

  /// [predicate] is ignored: a section replaces everything over the placeholder
  void pushAndRemoveSettingsUntil(BuildContext context, Widget widget, bool Function(Route) predicate,
      {Bindings? binding}) {
    final settings = _settings;
    if (settings == null) {
      openSettings(initialPage: widget);
      return;
    }
    binding?.dependencies();
    if (_tabletLayout) {
      activeSettingsPage.value = widget.runtimeType;
      settings.pushAndRemoveUntil(_instantRoute(widget), (route) => route.isFirst);
    } else {
      settings.push(ThemeSwitcher.buildPageRoute(builder: (BuildContext context) => widget));
    }
  }

  /// Closes Settings and Find My first, so what it opens is in view
  Future<void> pushAndRemoveUntil(BuildContext context, Widget widget, bool Function(Route) predicate,
      {bool closeActiveChat = true, PageRoute? customRoute}) async {
    final right = _right;
    if (right == null) {
      await Navigator.of(context).pushAndRemoveUntil(
          customRoute ??
              ThemeSwitcher.buildPageRoute(
                builder: (BuildContext context) => TitleBarWrapper(child: widget),
              ),
          predicate);
      return;
    }
    closeSections();
    if (_tabletLayout) {
      if (closeActiveChat && ChatsSvc.activeChat != null) {
        Logger.debug("Closing active chat: ${ChatsSvc.activeChat!.chat.guid}", tag: "NavigatorService");
        cvc(ChatsSvc.activeChat!.chat).close();
      }
      await right.pushAndRemoveUntil(_instantRoute(widget), predicate);
    } else {
      await right.pushAndRemoveUntil(
          customRoute != null
              ? PageRouteBuilder(pageBuilder: (_, _, _) => widget, transitionDuration: Duration.zero)
              : ThemeSwitcher.buildPageRoute(builder: (BuildContext context) => widget),
          predicate);
    }
  }

  /// Returns false when there was nothing to go back from
  bool back() {
    final root = _root;
    Route? top;
    root?.popUntil((route) {
      top = route;
      return true;
    });
    if (top != null && !top!.isFirst && SectionObserver._section(top) == null) {
      // Like a message's popup on the iOS skin
      root!.maybePop();
      return true;
    }
    switch (openSection.value) {
      case AppSection.settings:
        final settings = _settings;
        if (settings != null && settings.canPop()) {
          settings.maybePop();
        } else {
          // pop, not maybePop: Settings' PopScope sends back here, so maybePop would loop
          _root?.pop();
        }
        return true;
      case AppSection.findMy:
        _root?.maybePop();
        return true;
      case null:
        break;
    }
    final left = _left, right = _right;
    if (left == null || right == null) {
      Get.back();
      return true;
    }
    if (right.canPop()) {
      // maybePop, so an open chat closes its pickers before closing itself
      right.maybePop();
      return true;
    }
    if (left.canPop()) {
      left.maybePop();
      return true;
    }
    return false;
  }

  void backConversationView(BuildContext context) => back();

  void pop(BuildContext context, [Object? result]) => Navigator.of(context).pop(result);

  /// Remember to call `await ChatsSvc.setAllInactive()` after calling this function
  void closeAllConversationView(BuildContext context) => _right?.popUntil((route) => route.isFirst);
}

class _OpaqueRouteObserver extends RouteObserver<ModalRoute> {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is! TransitionRoute || route.opaque) super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is! TransitionRoute || route.opaque) super.didPop(route, previousRoute);
  }
}

class PaneObserver extends NavigatorObserver {
  PaneObserver(this.open);

  final RxBool open;

  final List<Route> routes = [];

  /// For a navigator that went away without popping its pages, like a chat list Reset replaced
  void reset() {
    routes.clear();
    if (open.value) WidgetsBinding.instance.addPostFrameCallback((_) => open.value = routes.isNotEmpty);
  }

  bool _tracked(Route? route) => route != null && route.settings is! Page;

  // Navigator callbacks run mid-transition, often during a build
  void _update() => WidgetsBinding.instance.addPostFrameCallback((_) => open.value = routes.isNotEmpty);

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_tracked(route)) routes.add(route);
    _update();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index != -1) routes.removeAt(index);
    if (_tracked(newRoute)) routes.insert(index == -1 ? routes.length : index, newRoute!);
    _update();
  }
}

class SectionObserver extends NavigatorObserver {
  SectionObserver(this.open);

  final Rxn<AppSection> open;

  final List<Route> routes = [];

  static AppSection? _section(Route? route) =>
      AppSection.values.firstWhereOrNull((section) => section.name == route?.settings.name);

  // Updated right away, so a chat opened in the same frame sees the section gone
  void _update() => open.value = _section(routes.lastOrNull);

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_section(route) != null) routes.add(route);
    _update();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    routes.remove(route);
    _update();
  }
}
