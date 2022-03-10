import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/avatar_crop.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class CustomAvatarPanelBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomAvatarPanelController>(() => CustomAvatarPanelController());
  }
}

class CustomAvatarPanelController extends GetxController {
  late Settings _settingsCopy;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
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
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return SettingsScaffold(
      title: "Custom Avatars",
      initialHeader: null,
      iosSubtitle: null,
      materialSubtitle: null,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        Obx(() {
          if (!ChatBloc().loadedChatBatch.value) {
            return SliverToBoxAdapter(
              child: Center(
                child: Container(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Loading chats...",
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                      ),
                      buildProgressIndicator(context, size: 15),
                    ],
                  ),
                ),
              ),
            );
          }
          if (ChatBloc().loadedChatBatch.value && ChatBloc().chats.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Container(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text(
                    "You have no chats :(",
                    style: Theme.of(context).textTheme.subtitle1,
                  ),
                ),
              ),
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return ConversationTile(
                  key: Key(
                      ChatBloc().chats[index].guid.toString()),
                  chat: ChatBloc().chats[index],
                  inSelectMode: true,
                  onSelect: (_) {
                    if (ChatBloc().chats[index].customAvatarPath != null) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              title: Text("Custom Avatar",
                                  style:
                                  TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "You have already set a custom avatar for this chat. What would you like to do?",
                                      style: Theme.of(context).textTheme.bodyText1),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                    child: Text("Cancel",
                                        style: Theme.of(context)
                                            .textTheme
                                            .subtitle1!
                                            .apply(color: Theme.of(context).primaryColor)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    }),
                                TextButton(
                                    child: Text("Reset",
                                        style: Theme.of(context)
                                            .textTheme
                                            .subtitle1!
                                            .apply(color: Theme.of(context).primaryColor)),
                                    onPressed: () {
                                      File file = File(ChatBloc().chats[index].customAvatarPath!);
                                      file.delete();
                                      ChatBloc().chats[index].customAvatarPath = null;
                                      ChatBloc().chats[index].save(updateCustomAvatarPath: true);
                                      Get.back();
                                    }),
                                TextButton(
                                    child: Text("Set New",
                                        style: Theme.of(context)
                                            .textTheme
                                            .subtitle1!
                                            .apply(color: Theme.of(context).primaryColor)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      CustomNavigator.pushSettings(
                                        context,
                                        AvatarCrop(index: index),
                                      );
                                    }),
                              ]);
                        },
                      );
                    } else {
                      CustomNavigator.pushSettings(
                        context,
                        AvatarCrop(index: index),
                      );
                    }
                  },
                );
              },
              childCount: ChatBloc().chats.length,
            ),
          );
        }),
      ]
    );
  }
}
