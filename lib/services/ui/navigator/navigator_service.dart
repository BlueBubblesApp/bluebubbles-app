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

/// Handles navigation for the app.
///
/// The chat list has a split: the left pane (nested navigator 1) holds the chat list and what replaces it (archived,
/// unknown senders), the right pane (nested navigator 2) every page opened from those. Settings and Find My open over
/// it as full-window pages with splits of their own; Settings' right pane is nested navigator 3. In the phone layout
/// each split keeps its navigators, with the right pane stacked over the left while it has a page open.
class NavigatorService {
  NavigatorService() {
    ever(settingsPaneOpen, (bool open) {
      if (!open) activeSettingsPage.value = null;
    });
  }

  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  final Rxn listener = Rxn();

  /// Whether the chat list's right pane has a page open over its empty first page. In the phone layout the right pane
  /// covers the left only while this is true.
  final RxBool chatPaneOpen = false.obs;
  late final PaneObserver chatPaneObserver = PaneObserver(chatPaneOpen);

  /// Whether Settings' right pane has a page open over its placeholder.
  final RxBool settingsPaneOpen = false.obs;

  /// Tells a chat list right pane page when a full page covers it and uncovers it again. Dialogs and see-through
  /// popups, like a message's, don't count.
  final RouteObserver<ModalRoute> paneRouteObserver = _OpaqueRouteObserver();

  /// Tracks Settings and Find My on the root navigator.
  late final SectionObserver sectionObserver = SectionObserver(openSection);

  /// The top full-window section, if one is open. The chat list and its open chat are out of view while it is.
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

  /// Opens [widget] in the right pane of the split in view: Settings' while Settings is on top, the chat list's
  /// otherwise.
  Future<T?> push<T>(BuildContext context, Widget widget) {
    final pane = openSection.value == AppSection.settings ? _settings : _right;
    if (pane == null) {
      return Navigator.of(context).push<T>(ThemeSwitcher.buildPageRoute(
        builder: (BuildContext context) => TitleBarWrapper(child: widget),
      ));
    }
    return pane.push<T>(ThemeSwitcher.buildPageRoute(builder: (BuildContext context) => widget));
  }

  /// Replaces the chat list in the left pane with [widget], like the archived chats.
  Future<void> pushLeft(BuildContext context, Widget widget) async {
    final left = _left;
    // The phone layout hides the left pane behind an open chat, so open over the chat instead, like a shortcut does
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

  /// Opens Settings over the chat list, with [initialPage] in its right pane (in the tablet layout, Server Management
  /// when none is given). Already in Settings, it just switches to [initialPage].
  void openSettings({Widget? initialPage}) {
    if (openSection.value == AppSection.settings) {
      if (initialPage != null) pushAndRemoveSettingsUntil(Get.context!, initialPage, (_) => false);
      return;
    }
    _openSection(AppSection.settings, SettingsPage(initialPage: initialPage));
  }

  /// Opens Find My over the chat list.
  void openFindMy() {
    if (openSection.value == AppSection.findMy) return;
    _openSection(AppSection.findMy, const FindMyPage());
  }

  /// Closes Settings and Find My, uncovering the chat list.
  void closeSections() {
    final root = _root;
    if (root == null) return;
    for (final route in sectionObserver.routes.toList()) {
      root.removeRoute(route);
    }
  }

  /// Opens a page nested inside the current Settings page.
  Future<dynamic> pushSettings(BuildContext context, Widget widget, {Bindings? binding}) async {
    binding?.dependencies();
    return push(context, widget);
  }

  /// Switches the Settings section shown in its right pane to [widget]. [predicate] is ignored: in the tablet layout
  /// a section replaces everything over the placeholder, in the phone layout it opens over the list.
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

  /// Opens [widget] in the chat list's right pane in place of the routes [predicate] rejects, closing Settings and
  /// Find My first. Opening a chat goes through here.
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

  /// Goes back one step: a popup over the window first, then in the split in view its right pane, then its left, then
  /// the split itself for Settings and Find My. Returns false when there was nothing to go back from.
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

  /// Pops the page [context] is on.
  void pop(BuildContext context, [Object? result]) => Navigator.of(context).pop(result);

  /// Closes the chat and what's open over it in the chat list's right pane.
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

/// Tracks the pages pushed over a pane's empty first page.
class PaneObserver extends NavigatorObserver {
  PaneObserver(this.open);

  final RxBool open;

  /// Pages over the first page, bottom to top.
  final List<Route> routes = [];

  /// Forgets the pages of a navigator that went away without popping them, like a chat list that Reset replaced.
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

/// Tracks the full-window sections on the root navigator.
class SectionObserver extends NavigatorObserver {
  SectionObserver(this.open);

  final Rxn<AppSection> open;

  /// Open sections, bottom to top.
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
