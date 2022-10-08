import 'dart:async';

import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
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
    if (isNullOrEmpty(handles)!) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (Handle item in handles) {
      items.add(SettingsTile(
        title: ContactManager().getContact(item.address)?.displayName ?? await formatPhoneNumber(item),
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

class _CustomAvatarColorPanelState extends CustomState<CustomAvatarColorPanel, void, CustomAvatarColorPanelController> with ThemeHelpers {

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
