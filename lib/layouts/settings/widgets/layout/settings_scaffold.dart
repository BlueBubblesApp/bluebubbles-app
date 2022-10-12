import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
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

  SettingsScaffold(
      {required this.title,
        required this.initialHeader,
        required this.iosSubtitle,
        required this.materialSubtitle,
        required this.headerColor,
        required this.tileColor,
        required this.bodySlivers,
        this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: settings.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: settings.settings.skin.value == Skins.Material ? tileColor : headerColor,
        appBar: settings.settings.skin.value == Skins.Samsung
            ? null
            : PreferredSize(
          preferredSize: Size(navigatorService.width(context), 50),
          child: AppBar(
            systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            toolbarHeight: 50,
            elevation: 0,
            scrolledUnderElevation: 3,
            surfaceTintColor: context.theme.colorScheme.primary,
            leading: buildBackButton(context),
            backgroundColor: headerColor,
            centerTitle: settings.settings.skin.value == Skins.iOS,
            title: Text(
              title,
              style: context.theme.textTheme.titleLarge,
            ),
          ),
        ),
        body: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            if (settings.settings.skin.value != Skins.Samsung) return false;
            final scrollDistance = context.height / 3 - 57;
            if (controller.offset > 0 &&
                controller.offset < scrollDistance &&
                controller.offset != controller.position.maxScrollExtent) {
              final double snapOffset = controller.offset / scrollDistance > 0.5 ? scrollDistance : 0;

              Future.microtask(
                      () => controller.animateTo(snapOffset, duration: Duration(milliseconds: 200), curve: Curves.linear));
            }
            return false;
          },
          child: ScrollbarWrapper(
            showScrollbar: false,
            controller: controller,
            child: Obx(
                  () => CustomScrollView(
                controller: controller,
                shrinkWrap: true,
                physics: (settings.settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                    ? NeverScrollableScrollPhysics()
                    : ThemeSwitcher.getScrollPhysics(),
                slivers: <Widget>[
                  if (settings.settings.skin.value == Skins.Samsung)
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
                                  curve: Interval(0.3, 1.0, curve: Curves.easeIn),
                                )),
                                child: Center(child: Text(title, style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground), textAlign: TextAlign.center)),
                              ),
                              FadeTransition(
                                opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                                )),
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Container(
                                    padding: EdgeInsets.only(left: 50),
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
                  if (settings.settings.skin.value != Skins.Samsung && initialHeader != null)
                    SliverToBoxAdapter(
                      child: Container(
                          height: 50,
                          alignment: Alignment.bottomLeft,
                          color: settings.settings.skin.value == Skins.iOS ? headerColor : tileColor,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8.0, left: settings.settings.skin.value == Skins.iOS ? 30 : 15),
                            child: Text(initialHeader!.psCapitalize,
                                style: settings.settings.skin.value == Skins.iOS
                                    ? iosSubtitle
                                    : materialSubtitle),
                          )),
                    ),
                  if (settings.settings.skin.value != Skins.Samsung)
                    ...bodySlivers,
                  if (settings.settings.skin.value == Skins.Samsung)
                    SliverToBoxAdapter(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: context.height - 50 - context.mediaQueryPadding.top - context.mediaQueryViewPadding.top),
                        child: CustomScrollView(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          slivers: bodySlivers,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Container(
                      height: 30,
                      color: settings.settings.skin.value != Skins.Material ? headerColor : tileColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}