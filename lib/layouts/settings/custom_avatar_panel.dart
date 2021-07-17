import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAvatarPanelBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomAvatarPanelController>(() => CustomAvatarPanelController());
  }
}

class CustomAvatarPanelController extends GetxController {
  late Settings _settingsCopy;
  bool isFetching = false;
  RxList<Widget> handleWidgets = <Widget>[].obs;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    getCustomHandles();
  }

  Future<void> getCustomHandles({force: false}) async {
    // If we are already fetching or have results,
    if (!false && (isFetching || !isNullOrEmpty(this.handleWidgets)!)) return;
    List<Handle> handles = await Handle.find();
    if (isNullOrEmpty(handles)!) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (var item in handles) {
      items.add(SettingsTile(
        title: ContactManager().getCachedContactSync(item.address ?? "")?.displayName ?? await formatPhoneNumber(item),
        subtitle: "Tap avatar to change color",
        trailing: ContactAvatarWidget(handle: item),
      ));
    }

    if (!isNullOrEmpty(items)!) {
      this.handleWidgets.value = items;
    }
  }

  @override
  void dispose() {
    SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class CustomAvatarPanel extends GetView<CustomAvatarPanelController> {

  @override
  Widget build(BuildContext context) {
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
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Custom Avatar Colors",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(
            parent: CustomBouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            Obx(() => SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  if (controller.handleWidgets.length == 0)
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
    );
  }
}
