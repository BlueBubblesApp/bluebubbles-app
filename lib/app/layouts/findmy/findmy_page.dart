import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_controller.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_devices_tab_view.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_friends_tab_view.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_items_tab_view.dart';
import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_map_widget.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sliding_up_panel2/sliding_up_panel2.dart';

class FindMyPage extends StatefulWidget {
  const FindMyPage({super.key});

  @override
  State<StatefulWidget> createState() => _FindMyPageState();
}

class _FindMyPageState extends State<FindMyPage> with SingleTickerProviderStateMixin {
  late final FindMyController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(FindMyController());
    controller.tabController = TabController(vsync: this, length: 3);
  }

  @override
  void dispose() {
    Get.delete<FindMyController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (context.isPhone) {
          return _buildNormalLayout(context);
        }
        return _buildTabletLayout(context);
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Obx(
      () => BBScaffold(
        backgroundColor: context.theme.colorScheme.surface.themeOpacity(context),
        safeAreaLeft: false,
        safeAreaRight: false,
        body: Stack(
          children: [
            Row(
              children: [
                ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, NavigationSvc.width(context) / 3))),
                  child: Container(
                    width: 500,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      FindMyMapWidget(controller: controller),
                      if (!controller.canRefresh.value) _buildUpdatingIndicator(context),
                      if (!context.samsung && controller.canRefresh.value) _buildRefreshButton(context, isTablet: true),
                      if (kIsDesktop) _buildDesktopTitleBar(context),
                    ],
                  ),
                ),
              ],
            ),
            ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: 300, maxWidth: max(300, min(500, NavigationSvc.width(context) / 3))),
              child: Column(
                children: [
                  if (!context.samsung)
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildBackButton(context),
                        ),
                        Expanded(child: Text("Find My", style: context.theme.textTheme.titleLarge)),
                      ],
                    ),
                  if (!context.samsung) _buildDesktopTabBar(),
                  Expanded(
                    child: SizedBox(
                      width: 500,
                      child: TabBarView(
                        controller: controller.tabController,
                        children: [
                          _buildFriendsTab(context, true),
                          _buildDevicesTab(context, true),
                          _buildItemsTab(context, true),
                        ],
                      ),
                    ),
                  ),
                  if (context.samsung) _buildDesktopTabBar()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, bool isTablet) {
    return ScrollbarWrapper(
      controller: controller.friendsController,
      child: Obx(
        () => CustomScrollView(
          controller: controller.friendsController,
          physics: kIsWeb ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
          slivers: [
            if (context.samsung) _buildSamsungAppBar(context, "FindMy Friends"),
            if (!context.samsung) FindMyFriendsTabView(controller: controller),
            if (context.samsung)
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                  child: CustomScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    slivers: [FindMyFriendsTabView(controller: controller)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesTab(BuildContext context, bool isTablet) {
    return ScrollbarWrapper(
      controller: controller.devicesController,
      child: Obx(
        () => CustomScrollView(
          controller: controller.devicesController,
          physics: kIsWeb ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
          slivers: [
            if (context.samsung) _buildSamsungAppBar(context, "FindMy Devices"),
            if (!context.samsung) FindMyDevicesTabView(controller: controller),
            if (context.samsung)
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                  child: CustomScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    slivers: [FindMyDevicesTabView(controller: controller)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTab(BuildContext context, bool isTablet) {
    return ScrollbarWrapper(
      controller: controller.itemsController,
      child: Obx(
        () => CustomScrollView(
          controller: controller.itemsController,
          physics: kIsWeb ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics(),
          slivers: [
            if (context.samsung) _buildSamsungAppBar(context, "FindMy Items"),
            if (!context.samsung) FindMyItemsTabView(controller: controller),
            if (context.samsung)
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                  child: CustomScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    slivers: [FindMyItemsTabView(controller: controller)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTabBar() {
    return TabBar(
      controller: controller.tabController,
      dividerColor: context.theme.dividerColor.withValues(alpha: 0.2),
      tabs: [
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(context.iOS ? CupertinoIcons.person_2 : Icons.person),
              const Text("Friends"),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(context.iOS ? CupertinoIcons.device_desktop : Icons.devices),
              const Text("Devices"),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(context.iOS ? CupertinoIcons.device_phone_portrait : Icons.devices),
              const Text("Items"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalLayout(BuildContext context) {
    return Obx(
      () => BBScaffold(
        backgroundColor: context.material ? context.tileColor : context.headerColor,
        safeAreaLeft: false,
        safeAreaRight: false,
        extendBodyBehindBottomPill: false,
        body: Stack(
          children: [
            SlidingUpPanel(
              controller: controller.panelController,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25.0),
                topRight: Radius.circular(25.0),
              ),
              minHeight: 50,
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              disableDraggableOnScrolling: true,
              backdropEnabled: true,
              parallaxEnabled: true,
              // Snap to collapsed or fully open. The panel lays its content out at
              // maxHeight regardless of how far open it is, so a half-open panel
              // leaves the end of the list outside the visible area, unreachable by
              // scrolling. Snapping keeps the panel out of that state.
              panelSnapping: true,
              header: ForceDraggableWidget(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              panelBuilder: () => TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: controller.tabController,
                children: <Widget>[
                  _buildScrollNotificationWrapper(
                    controller.friendsController,
                    _buildFriendsTab(context, false),
                  ),
                  _buildScrollNotificationWrapper(
                    controller.devicesController,
                    _buildDevicesTab(context, false),
                  ),
                  _buildScrollNotificationWrapper(
                    controller.itemsController,
                    _buildItemsTab(context, false),
                  ),
                ],
              ),
              body: FindMyMapWidget(controller: controller),
            ),
            if (!context.samsung)
              Positioned(
                top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
                left: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  ),
                  child: buildBackButton(context, padding: const EdgeInsets.only(right: 2)),
                ),
              ),
            if (!controller.canRefresh.value) _buildUpdatingIndicator(context),
            if (!context.samsung && controller.canRefresh.value) _buildRefreshButton(context, isTablet: false),
            if (kIsDesktop) _buildDesktopTitleBar(context),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildScrollNotificationWrapper(ScrollController scrollController, Widget child) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        if (SettingsSvc.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
        final scrollDistance = context.height / 3 - 57;

        if (scrollController.hasClients && scrollController.offset > 0 && scrollController.offset < scrollDistance) {
          final double snapOffset = scrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

          Future.microtask(() => scrollController.animateTo(snapOffset,
              duration: const Duration(milliseconds: 200), curve: Curves.linear));
        }
        return false;
      },
      child: child,
    );
  }

  Widget _buildBottomNavBar() {
    return Obx(
      () => NavigationBar(
        selectedIndex: controller.tabIndex.value,
        backgroundColor: context.headerColor,
        destinations: [
          NavigationDestination(
            icon: Icon(context.iOS ? CupertinoIcons.person_2 : Icons.person),
            label: "FRIENDS",
          ),
          NavigationDestination(
            icon: Icon(context.iOS ? CupertinoIcons.device_desktop : Icons.devices),
            label: "DEVICES",
          ),
          NavigationDestination(
            icon: Icon(context.iOS ? CupertinoIcons.headphones : Icons.earbuds),
            label: "ITEMS",
          ),
        ],
        onDestinationSelected: (page) {
          bool wasOpen = controller.panelController.isPanelOpen;
          int oldIndex = controller.tabIndex.value;
          controller.tabIndex.value = page;
          controller.tabController!.animateTo(page);

          if (oldIndex == page && !controller.panelController.isPanelOpen) {
            controller.panelController.open();
          } else if (oldIndex == page) {
            controller.panelController.close();
          } else if (!controller.panelController.isPanelOpen) {
            controller.panelController.open();
          } else if (!wasOpen && controller.panelController.isPanelOpen) {
            controller.panelController.close();
          }
        },
      ),
    );
  }

  Widget _buildUpdatingIndicator(BuildContext context) {
    return Positioned(
      top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
      right: 20,
      child: Semantics(
        liveRegion: true,
        label: "Updating locations",
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildProgressIndicator(context, size: 18),
              const SizedBox(width: 8),
              Text("Updating locations…", style: context.theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, {required bool isTablet}) {
    return Positioned(
      top: 10 + (kIsDesktop ? appWindow.titleBarHeight : MediaQuery.of(context).padding.top),
      right: 20,
      child: Obx(
        () => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          ),
          child: SizedBox(
            width: 48,
            child: controller.refreshing.value || controller.refreshing2.value
                ? buildProgressIndicator(context)
                : IconButton(
                    iconSize: 22,
                    icon: Icon(context.iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                        color: context.theme.colorScheme.onSurface, size: 22),
                    onPressed: () {
                      controller.refreshing.value = true;
                      controller.refreshing2.value = true;
                      controller.getLocations(refreshDevices: !isTablet);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTitleBar(BuildContext context) {
    return SizedBox(
      height: appWindow.titleBarHeight,
      child: AbsorbPointer(
        child: Row(children: [
          Expanded(child: Container()),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaY: 2, sigmaX: 2),
              child: Container(
                  height: appWindow.titleBarHeight,
                  width: appWindow.titleBarButtonSize.width * 3,
                  color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSamsungAppBar(BuildContext context, String title) {
    return Obx(
      () => SliverAppBar(
        backgroundColor: context.headerColor,
        pinned: true,
        stretch: true,
        expandedHeight: context.height / 3,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: LayoutBuilder(
          builder: (context, constraints) {
            var expandRatio = (constraints.maxHeight - 50) / (context.height / 3 - 50);

            if (expandRatio > 1.0) expandRatio = 1.0;
            if (expandRatio < 0.0) expandRatio = 0.0;
            final animation = AlwaysStoppedAnimation<double>(expandRatio);

            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                  )),
                  child: Center(
                      child: Text(title,
                          style: context.theme.textTheme.displaySmall!
                              .copyWith(color: context.theme.colorScheme.onSurface),
                          textAlign: TextAlign.center)),
                ),
                FadeTransition(
                  opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                  )),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.only(left: 40),
                      height: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: context.theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      height: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: buildBackButton(context),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    height: 50,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.canRefresh.value)
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: Container(
                                width: 48,
                                margin: const EdgeInsets.only(right: 8),
                                child: controller.refreshing.value || controller.refreshing2.value
                                    ? buildProgressIndicator(context)
                                    : IconButton(
                                        iconSize: 22,
                                        icon: Icon(context.iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh,
                                            color: context.theme.colorScheme.onSurface, size: 22),
                                        onPressed: () {
                                          controller.refreshing.value = true;
                                          controller.refreshing2.value = true;
                                          controller.getLocations(refreshDevices: true);
                                        },
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
