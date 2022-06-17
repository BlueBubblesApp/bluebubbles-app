import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  Future<void> getCustomHandles({force = false}) async {
    // If we are already fetching or have results,
    if (!false && (isFetching || !isNullOrEmpty(handleWidgets)!)) return;
    List<Handle> handles = Handle.find();
    if (isNullOrEmpty(handles)!) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (var item in handles) {
      items.add(SettingsTile(
        title: ContactManager().getContact(item.address)?.displayName ?? await formatPhoneNumber(item),
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

class CustomAvatarColorPanel extends StatelessWidget {
  final controller = Get.put(CustomAvatarColorPanelController());

  @override
  Widget build(BuildContext context) {
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
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
              if (controller.handleWidgets.isEmpty)
                Container(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      "No avatars have been customized! To get started, turn on colorful avatars and tap an avatar in the conversation details page.",
                      style: context.theme.textTheme.bodyLarge,
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
