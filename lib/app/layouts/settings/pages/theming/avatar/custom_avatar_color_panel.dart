import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAvatarColorPanelController extends StatefulController {
  final RxList<Widget> handleWidgets = <Widget>[].obs;

  @override
  void onReady() {
    super.onReady();
    updateObx(() {
      getCustomHandles();
    });
  }

  Future<void> getCustomHandles({force = false}) async {
    List<Handle> handles = Handle.find();
    if (isNullOrEmpty(handles)) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (Handle item in handles) {
      items.add(SettingsTile(
        title: item.displayName,
        subtitle: "Tap avatar to change color",
        trailing: ContactAvatarWidget(handle: item),
      ));
    }

    handleWidgets.value = items;
  }
}

class CustomAvatarColorPanel extends CustomStateful<CustomAvatarColorPanelController> {
  CustomAvatarColorPanel() : super(parentController: Get.put(CustomAvatarColorPanelController()));

  @override
  State<StatefulWidget> createState() => _CustomAvatarColorPanelState();
}

class _CustomAvatarColorPanelState extends CustomState<CustomAvatarColorPanel, void, CustomAvatarColorPanelController> {

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 5),
              if (controller.handleWidgets.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      "No avatars have been customized! To get started, turn on colorful avatars and tap an avatar in the conversation details page.",
                      style: context.theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    )),
              for (Widget handleWidget in controller.handleWidgets) handleWidget,
            ],
          ),
        )),
      ]
    );
  }
}
