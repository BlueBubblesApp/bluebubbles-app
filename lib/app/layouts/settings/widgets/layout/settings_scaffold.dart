import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SettingsScaffold extends StatelessWidget {
  final ScrollController controller = ScrollController();
  final String title;
  final String? initialHeader;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final Color headerColor;
  final Color tileColor;
  final List<Widget> bodySlivers;
  final List<Widget> actions;
  final Widget? stickyPrefix;
  final Widget? stickySuffix;
  final Widget? fab;

  SettingsScaffold({
    required this.title,
    required this.initialHeader,
    required this.iosSubtitle,
    required this.materialSubtitle,
    required this.headerColor,
    required this.tileColor,
    required this.bodySlivers,
    this.actions = const [],
    this.stickyPrefix,
    this.stickySuffix,
    this.fab,
  });

  bool get extend => actions.isNotEmpty && kIsDesktop;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: ss.settings.skin.value == Skins.Material ? tileColor : headerColor,
        appBar: ss.settings.skin.value == Skins.Samsung
            ? null
            : PreferredSize(
          preferredSize: Size(ns.width(context), extend ? 80 : 50),
          child: AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            toolbarHeight: extend ? 80 : 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: headerColor,
            centerTitle: ss.settings.skin.value == Skins.iOS,
            title: Text(
              title,
              style: context.theme.textTheme.titleLarge,
            ),
            actions: actions,
          ),
        ),
        floatingActionButton: fab,
        body: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            if (ss.settings.skin.value != Skins.Samsung || kIsWeb || kIsDesktop) return false;
            final scrollDistance = context.height / 3 - 57;
            if (controller.offset > 0 &&
                controller.offset < scrollDistance &&
                controller.offset != controller.position.maxScrollExtent) {
              final double snapOffset = controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

              Future.microtask(
                      () => controller.animateTo(snapOffset, duration: const Duration(milliseconds: 200), curve: Curves.linear));
            }
            return false;
          },
          child: ScrollbarWrapper(
            showScrollbar: false,
            controller: controller,
            child: Column(
              children: [
                stickyPrefix ?? const SizedBox.shrink(),
                Expanded(
                  child: Obx(() => CustomScrollView(
                      controller: controller,
                      shrinkWrap: true,
                      physics: ThemeSwitcher.getScrollPhysics(),
                      slivers: <Widget>[
                        if (ss.settings.skin.value == Skins.Samsung)
                          SliverAppBar(
                            backgroundColor: headerColor,
                            pinned: true,
                            stretch: true,
                            expandedHeight: context.height / 3,
                            elevation: 0,
                            automaticallyImplyLeading: false,
                            flexibleSpace: LayoutBuilder(
                              builder: (context, _) {
                                var expandRatio = 1 - (controller.offset) / (context.height / 3 - 50);
                                if (expandRatio > 1.0) expandRatio = 1.0;
                                if (expandRatio < 0.1) expandRatio = 0.0;
                                final animation = AlwaysStoppedAnimation<double>(expandRatio);

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    FadeTransition(
                                      opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
                                      )),
                                      child: Center(child: Text(title, style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
                                    ),
                                    FadeTransition(
                                      opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                                      )),
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Container(
                                          padding: const EdgeInsets.only(left: 50),
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
                                        child: Container(
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
                                      child: Container(
                                        height: 50,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: actions,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        if (ss.settings.skin.value != Skins.Samsung && initialHeader != null)
                          SliverToBoxAdapter(
                            child: Container(
                                height: 50,
                                alignment: Alignment.bottomLeft,
                                color: ss.settings.skin.value == Skins.iOS ? headerColor : tileColor,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 8.0, left: ss.settings.skin.value == Skins.iOS ? 30 : 15),
                                  child: Text(initialHeader!.psCapitalize,
                                      style: ss.settings.skin.value == Skins.iOS
                                          ? iosSubtitle
                                          : materialSubtitle),
                                )),
                          ),
                        if (ss.settings.skin.value != Skins.Samsung)
                          ...bodySlivers,
                        if (ss.settings.skin.value == Skins.Samsung)
                          SliverToBoxAdapter(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                              child: CustomScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                slivers: bodySlivers,
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Container(
                            height: 30,
                            color: ss.settings.skin.value != Skins.Material ? headerColor : tileColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                stickySuffix ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}