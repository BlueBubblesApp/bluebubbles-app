import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';

class CustomAvatarColorPanelBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomAvatarColorPanelController>(() => CustomAvatarColorPanelController());
  }
}

class CustomAvatarColorPanelController extends GetxController {
  late Settings _settingsCopy;
  bool isFetching = false;
  final RxList<Widget> handleWidgets = <Widget>[].obs;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    getCustomHandles();
  }

  Future<void> getCustomHandles({bool force = false}) async {
    // If we are already fetching or have results,
    if (!false && (isFetching || !isNullOrEmpty(handleWidgets)!)) return;
    List<Handle> handles = Handle.find();
    if (isNullOrEmpty(handles)!) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (var item in handles) {
      items.add(SettingsTile(
        title: ContactManager().getCachedContact(address: item.address)?.displayName ?? await formatPhoneNumber(item),
        subtitle: "Tap avatar to change color",
        trailing: ContactAvatarWidget(handle: item),
      ));
    }

    if (!isNullOrEmpty(items)!) {
      handleWidgets.value = items;
    }
  }

  @override
  void dispose() {
    SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class CustomAvatarColorPanel extends GetView<CustomAvatarColorPanelController> {
  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                title: Text(
                  "Custom Avatar Colors",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: ImprovedScrolling(
          enableMMBScrolling: true,
          enableKeyboardScrolling: true,
          mmbScrollConfig: MMBScrollConfig(
            customScrollCursor: DefaultCustomScrollCursor(
              cursorColor: context.textTheme.subtitle1!.color!,
              backgroundColor: Colors.white,
              borderColor: context.textTheme.headline1!.color!,
            ),
          ),
          scrollController: scrollController,
          child: CustomScrollView(
            controller: scrollController,
            physics: AlwaysScrollableScrollPhysics(
              parent: CustomBouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              Obx(() => SliverList(
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        Container(padding: EdgeInsets.only(top: 5.0)),
                        if (controller.handleWidgets.isEmpty)
                          Container(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                "No avatars have been customized! To get started, turn on colorful avatars and tap an avatar in the conversation details page.",
                                style: Theme.of(context).textTheme.subtitle1?.copyWith(height: 1.5),
                                textAlign: TextAlign.center,
                              )),
                        for (Widget handleWidget in controller.handleWidgets) handleWidget
                      ],
                    ),
                  )),
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
