import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class CustomAvatarPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _CustomAvatarPanelState();
}

class _CustomAvatarPanelState extends OptimizedState<CustomAvatarPanel> {

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Custom Avatars",
      initialHeader: null,
      iosSubtitle: null,
      materialSubtitle: null,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        Obx(() {
          if (!chats.loadedChatBatch.value) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Loading chats...",
                          style: context.theme.textTheme.labelLarge,
                        ),
                      ),
                      buildProgressIndicator(context, size: 15),
                    ],
                  ),
                ),
              ),
            );
          }
          if (chats.loadedChatBatch.value && chats.chats.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Text(
                    "You have no chats :(",
                    style: context.theme.textTheme.labelLarge,
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
                      chats.chats[index].guid.toString()),
                  chat: chats.chats[index],
                  controller: Get.put(
                    ConversationListController(showUnknownSenders: true, showArchivedChats: true),
                    tag: "custom-avatar-panel"
                  ),
                  inSelectMode: true,
                  onSelect: (_) {
                    if (chats.chats[index].customAvatarPath != null) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              title: Text("Custom Avatar",
                                  style: context.theme.textTheme.titleLarge),
                              content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "You have already set a custom avatar for this chat. What would you like to do?",
                                      style: context.theme.textTheme.bodyLarge),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                    child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    }),
                                TextButton(
                                    child: Text("Reset", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      File file = File(chats.chats[index].customAvatarPath!);
                                      file.delete();
                                      chats.chats[index].customAvatarPath = null;
                                      chats.chats[index].save(updateCustomAvatarPath: true);
                                      Get.back();
                                    }),
                                TextButton(
                                    child: Text("Set New", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      ns.pushSettings(
                                        context,
                                        AvatarCrop(index: index),
                                      );
                                    }),
                              ]);
                        },
                      );
                    } else {
                      ns.pushSettings(
                        context,
                        AvatarCrop(index: index),
                      );
                    }
                  },
                );
              },
              childCount: chats.chats.length,
            ),
          );
        }),
      ]
    );
  }
}
