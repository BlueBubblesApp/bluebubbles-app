import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
        title: ContactManager().getCachedContactSync(item.address)?.displayName ?? await formatPhoneNumber(item),
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

class CustomAvatarColorPanel extends GetView<CustomAvatarColorPanelController> {
  @override
  Widget build(BuildContext context) {
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return SettingsScaffold(
      title: "Custom Avatar Colors",
      initialHeader: null,
      iosSubtitle: null,
      materialSubtitle: null,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
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
      ]
    );
  }
}
