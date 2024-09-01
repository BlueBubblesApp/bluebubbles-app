import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/services/ui/navigator/navigator_service.dart';
import 'package:bluebubbles/services/ui/theme/themes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart';

class MessageOptionsOrderPanel extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MessageOptionsOrderPanelState();
}

class _MessageOptionsOrderPanelState extends OptimizedState<MessageOptionsOrderPanel> {
  final RxList<DetailsMenuAction> actionList = RxList();

  @override
  void initState() {
    super.initState();

    actionList.value = ss.settings.detailsMenuActions.platformSupportedActions;
  }

  @override
  Widget build(BuildContext context) {
    final Rx<Color> _backgroundColor = (kIsDesktop && ss.settings.windowEffect.value == WindowEffect.disabled
            ? Colors.transparent
            : context.theme.colorScheme.background)
        .obs;

    final Color tileColor =
        (ts.inDarkMode(context) ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background)
            .withAlpha(ss.settings.windowEffect.value != WindowEffect.disabled ? 100 : 255);

    if (kIsDesktop) {
      ss.settings.windowEffect.listen((WindowEffect effect) => _backgroundColor.value =
          effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(
        () => Scaffold(
          backgroundColor: _backgroundColor.value,
          appBar: PreferredSize(
            preferredSize: Size(ns.width(context), 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  systemOverlayStyle:
                      ThemeData.estimateBrightnessForColor(context.theme.colorScheme.background) == Brightness.dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark,
                  toolbarHeight: kIsDesktop ? 80 : 50,
                  elevation: 0,
                  scrolledUnderElevation: 3,
                  surfaceTintColor: context.theme.colorScheme.primary,
                  leading: buildBackButton(context),
                  backgroundColor: _backgroundColor.value,
                  centerTitle: ss.settings.skin.value == Skins.iOS,
                  title: Text(
                    "Message Options Order",
                    style: context.theme.textTheme.titleLarge,
                  ),
                  actions: [
                    TextButton(
                      child: Text("Reset",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                      onPressed: () {
                        actionList.value = DetailsMenuAction.values.platformSupportedActions;
                        ss.settings.resetDetailsMenuActions();
                      },
                    ),
                  ],
                ),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Obx(
                () => ReorderableListView.builder(
                  shrinkWrap: true,
                  onReorder: (start, end) {
                    actionList.insert(end, actionList.elementAt(start));
                    actionList.removeAt(start + (end < start ? 1 : 0));
                    ss.settings.setDetailsMenuActions(actionList.toList());
                  },
                  itemBuilder: (context, index) {
                    DetailsMenuAction action = actionList[index];
                    return ReorderableDragStartListener(
                      key: Key(action.toString()),
                      index: index,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: AbsorbPointer(
                          child: DetailsMenuActionWidget(
                            action: action,
                          ),
                        ),
                      ),
                    );
                  },
                  itemCount: actionList.length,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
